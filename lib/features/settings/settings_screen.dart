import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../data/repositories/organization_repository.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/google_drive_backup_service.dart';
import '../../l10n/app_localizations.dart';
import '../backup/restore_backup_dialog.dart';

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
  bool _isCloudSyncing = false;

  Map<String, dynamic>? _lastBackupInfo;
  bool _gDriveConnected = false;
  String? _gDriveEmail;
  DateTime? _gDriveLastSync;
  String? _customFolderPath;

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
    final folder = await backupService.getCustomBackupFolderPath();

    if (mounted) {
      setState(() {
        _lastBackupInfo = info;
        _gDriveConnected = connected;
        _gDriveEmail = email;
        _gDriveLastSync = lastSync;
        _customFolderPath = folder;
      });
    }
  }

  void _changeBackupFolder() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      final backupDir = Directory(p.join(selectedDirectory, 'SanghLedger_Backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final backupService = ref.read(backupServiceProvider);
      await backupService.setCustomBackupFolderPath(backupDir.path);
      await _loadBackupMetadata();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup folder updated: ${backupDir.path}'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
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

  void _connectGoogleDrive(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final gDriveService = ref.read(googleDriveBackupServiceProvider);
      final email = await gDriveService.signInAndBindAccount();
      if (email != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Google Drive connected: $email'), backgroundColor: AppColors.successGreen),
        );
        await _loadBackupMetadata();
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      _connectGoogleDriveDialog(context);
    }
  }

  void _restoreBackup(BuildContext context) async {
    await RestoreBackupDialog.show(context);
    await _loadBackupMetadata();
  }

  Future<void> _updateLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (result.isEmpty || result.first.path == null) return;

      final sourceFile = File(result.first.path!);
      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image file');

      final resized = img.copyResize(decoded, width: 256, height: 256);
      final pngBytes = img.encodePng(resized);

      final docDir = await getApplicationDocumentsDirectory();
      final logoFile = File(p.join(docDir.path, 'sangh_logo.png'));
      await logoFile.writeAsBytes(pngBytes);

      final repo = ref.read(organizationRepositoryProvider);
      await repo.updateLogoPath(logoFile.path);
      ref.invalidate(organizationProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sangh logo updated successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update logo: $e'),
            backgroundColor: AppColors.errorCrimson,
          ),
        );
      }
    }
  }

  void _editOrganizationProfile(OrganizationInfo org) async {
    final nameController = TextEditingController(text: org.name);
    final addressController = TextEditingController(text: org.address);
    final phoneController = TextEditingController(text: org.contactPhone);
    final regNoController = TextEditingController(text: org.registrationNumber ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Sangh Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Sangh Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact Phone *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regNoController,
                decoration: const InputDecoration(labelText: 'Registration Number (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(organizationRepositoryProvider);
      await repo.updateProfile(
        name: nameController.text.trim(),
        address: addressController.text.trim(),
        contactPhone: phoneController.text.trim(),
        registrationNumber: regNoController.text.trim().isEmpty ? null : regNoController.text.trim(),
      );
      ref.invalidate(organizationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sangh profile updated successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final orgAsync = ref.watch(organizationProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Organization Profile & Branding Card
          Text('Organization Profile & Branding', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          orgAsync.when(
            data: (org) {
              if (org == null) return const SizedBox.shrink();
              final hasLogo = org.logoPath != null && org.logoPath!.isNotEmpty && File(org.logoPath!).existsSync();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _updateLogo,
                            child: Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryNavy.withValues(alpha: 0.1),
                                    border: Border.all(color: AppColors.primaryNavy, width: 1.5),
                                  ),
                                  child: hasLogo
                                      ? ClipOval(
                                          child: Image.file(
                                            File(org.logoPath!),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.business, size: 30, color: AppColors.primaryNavy),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryNavy,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(org.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  'Phone: ${org.contactPhone}${org.registrationNumber != null ? ' • Reg: ${org.registrationNumber}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              icon: const Icon(Icons.upload, size: 15),
                              label: Text(hasLogo ? 'Change Logo' : 'Upload Logo', style: const TextStyle(fontSize: 12)),
                              onPressed: _updateLogo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              icon: const Icon(Icons.edit, size: 15),
                              label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                              onPressed: () => _editOrganizationProfile(org),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
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

          // Passive Auto-Backup Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lastBackupInfo != null
                        ? 'Auto-Backup Active • Last synced: ${dateFormat.format(_lastBackupInfo!['modifiedAt'] as DateTime)}'
                        : 'Auto-Backup Active • Ready for transactions',
                    style: const TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

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
                            const Icon(Icons.folder_shared, color: AppColors.primaryNavy, size: 16),
                            const SizedBox(width: 6),
                            const Text('Backup Folder:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const Spacer(),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Change Folder', style: TextStyle(fontSize: 12)),
                              onPressed: _changeBackupFolder,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customFolderPath ?? 'Default app storage (/SanghLedger_Backups)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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
                          text: 'Backup to Device Now',
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
                      onPressed: () => _connectGoogleDrive(context),
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
                  _InfoRow('Interest Basis', 'Daily Reducing Balance (30-day month convention)'),
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
