import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../domain/services/backup_service.dart';
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
        messenger.showSnackBar(
          SnackBar(
            content: Text('Backup created: ${file.path.split(Platform.pathSeparator).last}'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.errorCrimson),
        );
      } finally {
        if (mounted) setState(() => _isBackingUp = false);
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
                  const Text('Local AES-256-GCM Backup Archive', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Backups are encrypted using your master admin password and can be restored on any Android device seamlessly.'),
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
