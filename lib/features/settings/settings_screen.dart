import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/google_drive_backup_service.dart';
import '../../l10n/app_localizations.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isCloudSyncing = false;

  Map<String, dynamic>? _lastBackupInfo;
  bool _gDriveConnected = false;
  String? _gDriveEmail;
  DateTime? _gDriveLastSync;

  @override
  void initState() {
    super.initState();
    _loadBackupMetadata();
  }

  Future<void> _loadBackupMetadata() async {
    final backupService = ref.read(backupServiceProvider);
    final gDriveService = ref.read(googleDriveBackupServiceProvider);

    final info = await backupService.getLastBackupInfo();
    final connected = await gDriveService.isConnected();
    final email = await gDriveService.getConnectedEmail();
    final lastSync = await gDriveService.getLastSyncDate();

    if (mounted) {
      setState(() {
        _lastBackupInfo = info;
        _gDriveConnected = connected;
        _gDriveEmail = email;
        _gDriveLastSync = lastSync;
      });
    }
  }

  void _createBackup(BuildContext context) async {
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Encrypted Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your Admin login password to encrypt the backup with AES-256-GCM:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Admin Password *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: const Text('Encrypt & Export'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      setState(() => _isBackingUp = true);
      try {
        final backupService = ref.read(backupServiceProvider);
        final file = await backupService.createBackup(adminPassword: passwordController.text);
        
        // Auto-sync to Google Drive if connected
        final gDriveService = ref.read(googleDriveBackupServiceProvider);
        if (await gDriveService.isConnected()) {
          try {
            await gDriveService.syncBackup(file);
          } catch (_) {}
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text('Backup created: ${file.path.split(Platform.pathSeparator).last}'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        await _loadBackupMetadata();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.errorCrimson),
        );
      } finally {
        if (mounted) setState(() => _isBackingUp = false);
      }
    }
  }

  void _syncGoogleDriveNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(backupServiceProvider);
    final gDriveService = ref.read(googleDriveBackupServiceProvider);

    final info = await backupService.getLastBackupInfo();
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please create a local backup first before syncing to Google Drive'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    setState(() => _isCloudSyncing = true);
    try {
      final file = File(info['path'] as String);
      await gDriveService.syncBackup(file);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google Drive backup sync completed successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _loadBackupMetadata();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Cloud sync failed: $e'), backgroundColor: AppColors.errorCrimson),
      );
    } finally {
      if (mounted) setState(() => _isCloudSyncing = false);
    }
  }

  void _connectGoogleDriveDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Google Drive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Google account email for cloud backup synchronization:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Google Account Email *', hintText: 'admin@sangh.org'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.trim().isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirmed == true && emailController.text.trim().isNotEmpty) {
      try {
        final gDriveService = ref.read(googleDriveBackupServiceProvider);
        await gDriveService.connectAccount(emailController.text.trim());
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Google Drive connected successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        await _loadBackupMetadata();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: AppColors.errorCrimson),
        );
      }
    }
  }

  void _restoreBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (files.isEmpty || files.first.path == null) return;
    final backupFile = File(files.first.path!);

    if (!context.mounted) return;
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Encrypted Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${backupFile.path.split(Platform.pathSeparator).last}'),
            const SizedBox(height: 12),
            const Text('Enter the Admin password that was used when creating this backup:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Admin Password *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorCrimson),
            onPressed: () {
              if (passwordController.text.isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: const Text('Verify & Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      setState(() => _isRestoring = true);
      try {
        final backupService = ref.read(backupServiceProvider);
        await backupService.restoreBackup(
          backupZipFile: backupFile,
          adminPassword: passwordController.text,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Database successfully verified and restored!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        await _loadBackupMetadata();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.errorCrimson),
        );
      } finally {
        if (mounted) setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('General & Language', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppColors.primaryNavy),
              title: Text(l10n.language),
              subtitle: Text(currentLocale.languageCode == 'en' ? 'English' : 'ಕನ್ನಡ (Kannada)'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(90, 36)),
                onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
                child: Text(currentLocale.languageCode == 'en' ? 'ಕನ್ನಡ' : 'English'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Encrypted Backup & Recovery', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Local AES-256-GCM Backup Archive',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Active (2-Day Rolling Policy)',
                          style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_lastBackupInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Last Backup: ${dateFormat.format(_lastBackupInfo!['modifiedAt'] as DateTime)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                '${((_lastBackupInfo!['sizeBytes'] as int) / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'File: ${_lastBackupInfo!['fileName']}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Backups are space-efficiently checkpointed, vacuumed, and encrypted with your master admin password.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: l10n.backup,
                          icon: Icons.backup,
                          isLoading: _isBackingUp,
                          onPressed: () => _createBackup(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SecondaryButton(
                          text: l10n.restore,
                          icon: Icons.restore,
                          isLoading: _isRestoring,
                          onPressed: () => _restoreBackup(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Google Drive Rolling Cloud Backup Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload_rounded, color: AppColors.primaryNavy),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Google Drive Rolling Backup',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (_gDriveConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(color: AppColors.primaryNavy, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_gDriveConnected) ...[
                    Text('Account: ${_gDriveEmail ?? "Connected"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      _gDriveLastSync != null
                          ? 'Last Cloud Sync: ${dateFormat.format(_gDriveLastSync!)}'
                          : 'Last Cloud Sync: Pending first sync',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: 'Backup Now to Cloud',
                            icon: Icons.cloud_sync_rounded,
                            isLoading: _isCloudSyncing,
                            onPressed: () => _syncGoogleDriveNow(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Disconnect Account',
                          icon: const Icon(Icons.link_off, color: AppColors.textSecondary),
                          onPressed: () async {
                            final gDrive = ref.read(googleDriveBackupServiceProvider);
                            await gDrive.disconnectAccount();
                            await _loadBackupMetadata();
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Sync your AES-256-GCM encrypted backups directly to your Google Drive AppData folder with automated 2-day rolling retention.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      text: 'Connect Google Drive',
                      icon: Icons.add_to_drive,
                      onPressed: () => _connectGoogleDriveDialog(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('App Identity & Constraints', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow('Package', 'in.sanghledger.app'),
                  _InfoRow('Storage Mode', '100% Offline (SQLCipher 256-bit)'),
                  _InfoRow('Max Active Members', '100 Members (SGH001–SGH100)'),
                  _InfoRow('Interest Basis', 'Daily Reducing Balance (365 days)'),
                  _InfoRow('Timezone', 'Asia/Kolkata (UTC+05:30)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
