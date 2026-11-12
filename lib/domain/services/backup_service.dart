import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as c;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/security/crypto_utils.dart';

class BackupManifest {
  final String appVersion;
  final int schemaVersion;
  final String organizationId;
  final String saltBase64;
  final String databaseSha256;
  final String backupDate;

  const BackupManifest({
    required this.appVersion,
    required this.schemaVersion,
    required this.organizationId,
    required this.saltBase64,
    required this.databaseSha256,
    required this.backupDate,
  });

  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'organizationId': organizationId,
        'saltBase64': saltBase64,
        'databaseSha256': databaseSha256,
        'backupDate': backupDate,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        appVersion: json['appVersion'] as String,
        schemaVersion: json['schemaVersion'] as int,
        organizationId: json['organizationId'] as String,
        saltBase64: json['saltBase64'] as String,
        databaseSha256: json['databaseSha256'] as String,
        backupDate: json['backupDate'] as String,
      );
}

class BackupService {
  final AppDatabase _db;
  static const uuid = Uuid();

  BackupService({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// Derives a 256-bit encryption key from the admin password and salt
  static Future<Uint8List> deriveKeyFromPassword(String password, Uint8List salt) async {
    final pbkdf2 = c.Pbkdf2(
      macAlgorithm: c.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = c.SecretKey(utf8.encode(password));
    final derived = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    final keyBytes = await derived.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Creates an encrypted zip backup of the active database
  Future<File> createBackup({required String adminPassword}) async {
    final dbPath = await _db.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('Database file does not exist to backup');
    }

    final dbBytes = await dbFile.readAsBytes();
    final dbSha256 = sha256.convert(dbBytes).toString();

    // 1. Generate salt and derive encryption key
    final salt = CryptoUtils.generateRandomBytes(16);
    final key256 = await deriveKeyFromPassword(adminPassword, salt);

    // 2. Encrypt database bytes using AES-256-GCM
    final encryptedDbBytes = await CryptoUtils.encryptAesGcm(dbBytes, key256);

    // 3. Create manifest
    final now = DateTime.now();
    final manifest = BackupManifest(
      appVersion: '1.0.0',
      schemaVersion: 1,
      organizationId: 'sangh_primary',
      saltBase64: base64.encode(salt),
      databaseSha256: dbSha256,
      backupDate: now.toIso8601String(),
    );

    // 4. Archive into zip
    final archive = Archive();
    final manifestJson = jsonEncode(manifest.toJson());
    archive.addFile(ArchiveFile('manifest.json', manifestJson.length, utf8.encode(manifestJson)));
    archive.addFile(ArchiveFile('database.enc', encryptedDbBytes.length, encryptedDbBytes));

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) throw StateError('Failed to encode zip archive');

    final backupDir = await getApplicationDocumentsDirectory();
    final timestamp = now.toIso8601String().replaceAll(':', '').replaceAll('-', '').substring(0, 15);
    final backupFile = File(p.join(backupDir.path, 'SanghLedger_Backup_$timestamp.zip'));
    await backupFile.writeAsBytes(zipData);

    // Record into backup history
    final db = await _db.database;
    await db.insert('backup_history', {
      'id': uuid.v4(),
      'backup_path': backupFile.path,
      'backup_date': now.toIso8601String(),
      'checksum_sha256': sha256.convert(zipData).toString(),
      'is_auto': 0,
      'status': 'SUCCESS',
      'created_at': now.toIso8601String(),
    });

    return backupFile;
  }

  /// Restores an encrypted zip backup into a staging directory before atomic replacement
  Future<void> restoreBackup({
    required File backupZipFile,
    required String adminPassword,
  }) async {
    if (!await backupZipFile.exists()) {
      throw ArgumentError('Backup file does not exist');
    }

    final zipBytes = await backupZipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifestFile = archive.findFile('manifest.json');
    final dbEncFile = archive.findFile('database.enc');

    if (manifestFile == null || dbEncFile == null) {
      throw FormatException('Invalid backup archive structure: missing manifest or database.enc');
    }

    // 1. Parse manifest
    final manifestContent = utf8.decode(manifestFile.content as List<int>);
    final manifest = BackupManifest.fromJson(jsonDecode(manifestContent) as Map<String, dynamic>);

    // 2. Derive key using stored salt and user-provided password
    final salt = base64.decode(manifest.saltBase64);
    final key256 = await deriveKeyFromPassword(adminPassword, Uint8List.fromList(salt));

    // 3. Decrypt database in staging
    final encryptedData = Uint8List.fromList(dbEncFile.content as List<int>);
    Uint8List decryptedDbBytes;
    try {
      decryptedDbBytes = await CryptoUtils.decryptAesGcm(encryptedData, key256);
    } catch (_) {
      throw const FormatException('Incorrect administrator password or corrupted backup archive');
    }

    // 4. Verify SHA-256 checksum integrity
    final computedSha256 = sha256.convert(decryptedDbBytes).toString();
    if (computedSha256 != manifest.databaseSha256) {
      throw const FormatException('Database checksum mismatch: archive may be tampered or damaged');
    }

    // 5. Atomic replacement: Close current DB connection, write to target path
    await _db.close();
    final targetPath = await _db.getDatabasePath();
    final stagingFile = File('$targetPath.staging');
    await stagingFile.writeAsBytes(decryptedDbBytes);

    // Atomically replace target file
    await stagingFile.rename(targetPath);
  }
}
