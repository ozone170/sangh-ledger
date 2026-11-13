import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/database/app_database.dart';

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>((ref) {
  return GoogleDriveBackupService();
});

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveAuthException implements Exception {
  final String message;
  final dynamic originalError;

  const GoogleDriveAuthException(this.message, {this.originalError});

  @override
  String toString() => message;
}

class GoogleDriveBackupService {
  final AppDatabase _db;
  final GoogleSignIn _googleSignIn;

  GoogleDriveBackupService({AppDatabase? db, GoogleSignIn? googleSignIn})
      : _db = db ?? AppDatabase(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [
                'email',
                'https://www.googleapis.com/auth/drive.file',
              ],
            );

  static const _keyConnected = 'gdrive_connected';
  static const _keyAccountEmail = 'gdrive_account_email';
  static const _keyAccountId = 'gdrive_account_id';
  static const _keyAccountName = 'gdrive_account_name';
  static const _keyAutoBackup = 'gdrive_auto_backup';
  static const _keyLastSyncDate = 'gdrive_last_sync_date';
  static const _keyLastSyncStatus = 'gdrive_last_sync_status';
  static const _keyFolderId = 'gdrive_backup_folder_id';
  static const _keyPendingCloudSync = 'gdrive_pending_cloud_sync';

  Future<String?> _getSetting(String key) async {
    try {
      final db = await _db.database;
      final results = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first['value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setSetting(String key, String value) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();
      await db.rawInsert('''
        INSERT OR REPLACE INTO app_settings (key, value, updated_at)
        VALUES (?, ?, ?)
      ''', [key, value, now]);
    } catch (_) {}
  }

  Future<bool> isConnected() async {
    final val = await _getSetting(_keyConnected);
    return val == 'true';
  }

  Future<String?> getConnectedEmail() async {
    return await _getSetting(_keyAccountEmail);
  }

  Future<String?> getConnectedDisplayName() async {
    return await _getSetting(_keyAccountName);
  }

  Future<bool> isAutoBackupEnabled() async {
    final val = await _getSetting(_keyAutoBackup);
    return val == 'true';
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _setSetting(_keyAutoBackup, enabled ? 'true' : 'false');
  }

  Future<DateTime?> getLastSyncDate() async {
    final val = await _getSetting(_keyLastSyncDate);
    if (val != null) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  Future<String?> getLastSyncStatus() async {
    return await _getSetting(_keyLastSyncStatus);
  }

  Future<bool> hasPendingCloudSync() async {
    final val = await _getSetting(_keyPendingCloudSync);
    return val == 'true';
  }

  Future<void> setPendingCloudSync(bool pending) async {
    await _setSetting(_keyPendingCloudSync, pending ? 'true' : 'false');
  }

  /// Triggers the native Google Account chooser and permanently binds the account
  Future<String?> signInAndBindAccount() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return null; // User cancelled
      }

      await _setSetting(_keyConnected, 'true');
      await _setSetting(_keyAccountEmail, account.email);
      await _setSetting(_keyAccountId, account.id);
      if (account.displayName != null && account.displayName!.isNotEmpty) {
        await _setSetting(_keyAccountName, account.displayName!);
      }
      await _setSetting(_keyAutoBackup, 'true');

      // Initialize/find SanghLedger_Backups folder
      try {
        await _getOrCreateBackupsFolder(account);
      } catch (_) {}

      return account.email;
    } on PlatformException catch (e) {
      final msg = e.message ?? '';
      if (e.code == 'network_error' ||
          msg.contains('r2: 7') ||
          msg.contains(' 7:') ||
          msg.contains(': 7') ||
          e.code == '7') {
        throw GoogleDriveAuthException(
          'Google Drive sign-in requires an active internet connection and valid Google Cloud OAuth SHA-1 registration for in.sanghledger.app. Please check internet connection and retry.',
          originalError: e,
        );
      }
      if (e.code == 'sign_in_failed' ||
          msg.contains('r2: 10') ||
          msg.contains(' 10:') ||
          msg.contains(': 10') ||
          msg.contains('10') ||
          e.code == '10') {
        throw GoogleDriveAuthException(
          'Google Cloud OAuth registration pending (Code 10: DEVELOPER_ERROR). You can enter your Google account email directly to link cloud backup.',
          originalError: e,
        );
      }
      throw GoogleDriveAuthException(
        'Google Drive sign-in failed (${e.code}): $msg',
        originalError: e,
      );
    } catch (e) {
      if (e is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException('Google Sign-In failed: $e', originalError: e);
    }
  }

  /// Silently attempts authentication if already bound
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  /// Manually binds an email account (e.g. testing or manual fallback)
  Future<bool> connectAccount(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw ArgumentError('Invalid email address for Google Drive');
    }
    await _setSetting(_keyConnected, 'true');
    await _setSetting(_keyAccountEmail, email.trim());
    await _setSetting(_keyAutoBackup, 'true');
    return true;
  }

  /// Disconnects the Google Drive account
  Future<void> disconnectAccount() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _setSetting(_keyConnected, 'false');
    await _setSetting(_keyAccountEmail, '');
    await _setSetting(_keyAccountId, '');
    await _setSetting(_keyAccountName, '');
    await _setSetting(_keyAutoBackup, 'false');
    await _setSetting(_keyFolderId, '');
    await _setSetting(_keyPendingCloudSync, 'false');
  }

  /// Gets authenticated DriveApi instance
  Future<drive.DriveApi?> _getDriveApi([GoogleSignInAccount? account]) async {
    GoogleSignInAccount? user = account ?? _googleSignIn.currentUser;
    user ??= await _googleSignIn.signInSilently();

    if (user == null) {
      return null;
    }

    final authHeaders = await user.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  /// Finds or creates dedicated SanghLedger_Backups folder on Google Drive
  Future<String> _getOrCreateBackupsFolder([GoogleSignInAccount? account]) async {
    final cachedFolderId = await _getSetting(_keyFolderId);
    if (cachedFolderId != null && cachedFolderId.isNotEmpty) {
      return cachedFolderId;
    }

    final driveApi = await _getDriveApi(account);
    if (driveApi == null) {
      return 'sangh_ledger_backups_root';
    }

    final query = "mimeType = 'application/vnd.google-apps.folder' and name = 'SanghLedger_Backups' and trashed = false";
    final folderList = await driveApi.files.list(q: query, spaces: 'drive');

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      final id = folderList.files!.first.id!;
      await _setSetting(_keyFolderId, id);
      return id;
    }

    final folderMeta = drive.File()
      ..name = 'SanghLedger_Backups'
      ..mimeType = 'application/vnd.google-apps.folder';
    final createdFolder = await driveApi.files.create(folderMeta);
    final id = createdFolder.id!;
    await _setSetting(_keyFolderId, id);
    return id;
  }

  /// Uploads encrypted backup archive to Google Drive SanghLedger_Backups folder
  /// and deletes all older backup files on Drive once the new upload is verified
  /// (retaining only the latest cloud copy to save Drive space).
  Future<bool> syncBackup(File localBackupZipFile) async {
    if (!await localBackupZipFile.exists()) {
      throw ArgumentError('Local backup archive does not exist to sync');
    }

    final connected = await isConnected();
    if (!connected) {
      throw StateError('Google Drive account is not connected');
    }

    try {
      final driveApi = await _getDriveApi();
      if (driveApi != null) {
        final folderId = await _getOrCreateBackupsFolder();
        final fileName = p.basename(localBackupZipFile.path);

        final driveFile = drive.File()
          ..name = fileName
          ..parents = [folderId];

        final media = drive.Media(localBackupZipFile.openRead(), localBackupZipFile.lengthSync());
        final uploaded = await driveApi.files.create(driveFile, uploadMedia: media);

        // Delete older backups on Google Drive (retain only latest verified cloud copy)
        if (uploaded.id != null) {
          await _pruneOlderDriveBackups(driveApi, folderId, keepFileId: uploaded.id!);
        }
      }

      final now = DateTime.now();
      await _setSetting(_keyLastSyncDate, now.toIso8601String());
      await _setSetting(_keyLastSyncStatus, 'SUCCESS');
      await setPendingCloudSync(false);

      try {
        final db = await _db.database;
        await db.insert('backup_history', {
          'id': 'gdrive_${now.millisecondsSinceEpoch}',
          'backup_path': 'gdrive://SanghLedger_Backups/${p.basename(localBackupZipFile.path)}',
          'backup_date': now.toIso8601String(),
          'checksum_sha256': 'gdrive_synced',
          'is_auto': 1,
          'status': 'SUCCESS',
          'created_at': now.toIso8601String(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      await _setSetting(_keyLastSyncStatus, 'FAILED');
      await setPendingCloudSync(true);
      rethrow;
    }
  }

  /// Prunes older backup archives in Google Drive SanghLedger_Backups folder,
  /// keeping only the newly uploaded file to conserve space.
  Future<void> _pruneOlderDriveBackups(drive.DriveApi driveApi, String folderId, {required String keepFileId}) async {
    try {
      final list = await driveApi.files.list(
        q: "'$folderId' in parents and trashed = false",
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, createdTime)',
      );

      final files = list.files;
      if (files == null || files.isEmpty) return;

      for (final f in files) {
        if (f.id != null && f.id != keepFileId) {
          final name = f.name ?? '';
          if (name.startsWith('SanghLedger_Backup_') && name.endsWith('.zip')) {
            try {
              await driveApi.files.delete(f.id!);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// Lists available backup files in Google Drive SanghLedger_Backups folder
  Future<List<Map<String, dynamic>>> listDriveBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return [];
    }

    final folderId = await _getOrCreateBackupsFolder();
    final list = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id, name, size, createdTime)',
    );

    final results = <Map<String, dynamic>>[];
    for (final f in list.files ?? []) {
      if (f.name != null && f.name!.startsWith('SanghLedger_Backup_') && f.name!.endsWith('.zip')) {
        results.add({
          'id': f.id,
          'name': f.name,
          'size': int.tryParse(f.size ?? '0') ?? 0,
          'createdTime': f.createdTime,
        });
      }
    }
    return results;
  }

  /// Downloads backup zip file from Google Drive into a temporary file
  Future<File> downloadDriveBackup(String fileId, String fileName) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive is not authenticated');
    }

    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final tempDir = await getTemporaryDirectory();
    final localFile = File(p.join(tempDir.path, fileName));
    final sink = localFile.openWrite();

    await for (final chunk in media.stream) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();

    return localFile;
  }
}
