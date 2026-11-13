import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'backup_service.dart';
import 'google_drive_backup_service.dart';

/// Zero-touch silent automatic backup coordinator.
/// Handles:
/// 1. Post-transaction debounced (5s) silent background backups
/// 2. Daily periodic background backups (24h)
/// 3. Dual-target write: User-selected device folder (2-day rolling) + Google Drive
/// 4. Offline sync queue via connectivity_plus
class AutoBackupCoordinator {
  static final AutoBackupCoordinator _instance = AutoBackupCoordinator._internal();
  factory AutoBackupCoordinator() => _instance;

  AutoBackupCoordinator._internal() {
    _initConnectivityListener();
    _initPeriodicTimer();
  }

  Timer? _debounceTimer;
  Timer? _dailyTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isBackingUp = false;

  final BackupService _backupService = BackupService();
  final GoogleDriveBackupService _gDriveService = GoogleDriveBackupService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  void _initConnectivityListener() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          final pending = await _gDriveService.hasPendingCloudSync();
          if (pending && await _gDriveService.isConnected()) {
            await _syncPendingToCloud();
          }
        }
      });
    } catch (_) {}
  }

  void _initPeriodicTimer() {
    // Run every 24 hours for daily end-of-day backup
    _dailyTimer = Timer.periodic(const Duration(hours: 24), (_) {
      triggerSilentBackup();
    });
  }

  /// Debounced trigger called whenever a financial transaction or member registration commits
  static void triggerSilentBackup() {
    _instance._scheduleDebouncedBackup();
  }

  void _scheduleDebouncedBackup() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_executeBackup());
    });
  }

  /// Executes immediate backup (for testing or explicit triggers)
  Future<void> executeImmediate() async {
    await _executeBackup();
  }

  Future<void> _executeBackup() async {
    if (_isBackingUp) return;
    _isBackingUp = true;

    try {
      // 1. Retrieve stored admin backup password
      final password = await _storage.read(key: 'admin_backup_password') ?? 'sangh_offline_ledger_backup';

      // 2. Target A: Save locally to selected folder (PRAGMA wal_checkpoint(TRUNCATE), AES-256-GCM, 2-day rolling)
      final localBackupFile = await _backupService.createBackup(adminPassword: password, isAuto: true);

      // 3. Target B: Google Drive silent upload if connected
      if (await _gDriveService.isConnected()) {
        try {
          final results = await Connectivity().checkConnectivity();
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          if (isOnline) {
            await _gDriveService.syncBackup(localBackupFile);
          } else {
            await _gDriveService.setPendingCloudSync(true);
          }
        } catch (_) {
          await _gDriveService.setPendingCloudSync(true);
        }
      }
    } catch (e) {
      debugPrint('Auto-backup notice: $e');
    } finally {
      _isBackingUp = false;
    }
  }

  Future<void> _syncPendingToCloud() async {
    try {
      final info = await _backupService.getLastBackupInfo();
      if (info != null && info['path'] != null) {
        final file = File(info['path'] as String);
        if (await file.exists()) {
          await _gDriveService.syncBackup(file);
        }
      }
    } catch (_) {}
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dailyTimer?.cancel();
    _connectivitySub?.cancel();
  }
}

