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

  /// Returns the dedicated directory for storing Sangh Ledger backups
  Future<Directory> getBackupDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'SanghLedger_Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Enforces a rolling 2-day retention policy:
  /// Keeps all backups belonging to the 2 most recent calendar dates found,
  /// deleting any backups older than those 2 dates.
  /// Never deletes anything if there are 2 or fewer distinct calendar dates available.
  Future<List<String>> enforceTwoDayRollingRetention(Directory backupDir) async {
    if (!await backupDir.exists()) return [];

    final deletedPaths = <String>[];
    final files = backupDir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('SanghLedger_Backup_') && name.endsWith('.zip');
    }).toList();

    if (files.isEmpty) return [];

    final dateMap = <String, List<File>>{};
    final regExp = RegExp(r'SanghLedger_Backup_(\d{8})');

    for (final file in files) {
      final name = p.basename(file.path);
      final match = regExp.firstMatch(name);
      String dateKey;
      if (match != null) {
        dateKey = match.group(1)!;
      } else {
        final mod = file.lastModifiedSync();
        dateKey = "${mod.year.toString().padLeft(4, '0')}${mod.month.toString().padLeft(2, '0')}${mod.day.toString().padLeft(2, '0')}";
      }
      dateMap.putIfAbsent(dateKey, () => []).add(file);
    }

    final sortedDates = dateMap.keys.toList()..sort((a, b) => b.compareTo(a)); // Descending: newest first

    // If 2 or fewer distinct calendar dates exist, retain all!
    if (sortedDates.length <= 2) {
      return [];
    }

    // Keep top 2 dates, delete older dates
    final datesToDelete = sortedDates.sublist(2);
    for (final date in datesToDelete) {
      final filesToDelete = dateMap[date] ?? [];
      for (final file in filesToDelete) {
        try {
          await file.delete();
          deletedPaths.add(file.path);
        } catch (_) {}
      }
    }

    return deletedPaths;
  }

  /// Retrieves metadata of the most recent local backup
  Future<Map<String, dynamic>?> getLastBackupInfo() async {
    final backupDir = await getBackupDirectory();
    final files = backupDir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('SanghLedger_Backup_') && name.endsWith('.zip');
    }).toList();

    if (files.isEmpty) return null;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final latest = files.first;
    final stat = latest.statSync();

    return {
      'path': latest.path,
      'fileName': p.basename(latest.path),
      'sizeBytes': stat.size,
      'modifiedAt': stat.modified,
    };
  }

  /// Creates a space-efficient encrypted zip backup of the active database
  /// with WAL checkpointing, VACUUM compaction, and 2-day rolling retention.
  Future<File> createBackup({required String adminPassword}) async {
    // 0. Checkpoint WAL and VACUUM SQLite database before archiving for space efficiency
    try {
      final db = await _db.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
      await db.execute('VACUUM;');
    } catch (_) {
      // Continue gracefully if vacuum cannot run in active context
    }

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

    // Store in dedicated SanghLedger_Backups folder
    final backupDir = await getBackupDirectory();
    final datePart = "${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final timePart = "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final backupFile = File(p.join(backupDir.path, 'SanghLedger_Backup_${datePart}_$timePart.zip'));
    await backupFile.writeAsBytes(zipData);

    // 5. Enforce 2-Day Rolling Retention Policy
    await enforceTwoDayRollingRetention(backupDir);

    // Record into backup history
    try {
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
    } catch (_) {}

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

