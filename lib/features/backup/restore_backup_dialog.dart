import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../domain/services/google_drive_backup_service.dart';
import '../settings/settings_screen.dart';

class RestoreBackupDialog extends ConsumerStatefulWidget {
  const RestoreBackupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const RestoreBackupDialog(),
    );
  }

  @override
  ConsumerState<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends ConsumerState<RestoreBackupDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _statusMessage;
  List<Map<String, dynamic>> _driveBackups = [];
  bool _isLoadingDrive = false;
  String? _driveEmail;
  String? _configuredLocalFolder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final gDrive = ref.read(googleDriveBackupServiceProvider);
    final backupService = ref.read(backupServiceProvider);

    final email = await gDrive.getConnectedEmail();
    final folder = await backupService.getCustomBackupFolderPath();

    if (mounted) {
      setState(() {
        _driveEmail = email;
        _configuredLocalFolder = folder;
      });
      if (email != null && email.isNotEmpty) {
        _fetchDriveBackups();
      }
    }
  }

  Future<void> _fetchDriveBackups() async {
    setState(() => _isLoadingDrive = true);
    try {
      final gDrive = ref.read(googleDriveBackupServiceProvider);
      final list = await gDrive.listDriveBackups();
      if (mounted) {
        setState(() {
          _driveBackups = list;
          _isLoadingDrive = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDrive = false);
    }
  }

  Future<void> _connectAndFetchDrive() async {
    setState(() => _isLoadingDrive = true);
    try {
      final gDrive = ref.read(googleDriveBackupServiceProvider);
      final email = await gDrive.signInAndBindAccount();
      if (email != null && mounted) {
        setState(() => _driveEmail = email);
        await _fetchDriveBackups();
      } else {
        if (mounted) setState(() => _isLoadingDrive = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDrive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: AppColors.errorCrimson),
        );
      }
    }
  }

  Future<void> _promptPasswordAndRestore(File backupFile) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Encrypted Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${backupFile.path.split(Platform.pathSeparator).last}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Enter the master Admin password used when this backup was created:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Admin Password *', prefixIcon: Icon(Icons.lock)),
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
            child: const Text('Decrypt & Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Decrypting and verifying database...';
      });

      try {
        final backupService = ref.read(backupServiceProvider);
        await backupService.restoreBackup(
          backupZipFile: backupFile,
          adminPassword: passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database successfully restored! Please login with your Admin credentials.'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.errorCrimson),
          );
        }
      }
    }
  }

  Future<void> _restoreFromDriveItem(Map<String, dynamic> item) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Downloading backup from Google Drive...';
    });

    try {
      final gDrive = ref.read(googleDriveBackupServiceProvider);
      final downloadedFile = await gDrive.downloadDriveBackup(item['id'] as String, item['name'] as String);
      setState(() => _isLoading = false);
      await _promptPasswordAndRestore(downloadedFile);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed downloading cloud backup: $e'), backgroundColor: AppColors.errorCrimson),
        );
      }
    }
  }

  Future<void> _pickAndRestoreLocalFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (files.isEmpty || files.first.path == null) return;
    final file = File(files.first.path!);
    await _promptPasswordAndRestore(file);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restore from Backup',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select where your encrypted backup archive is stored:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryNavy,
            indicatorColor: AppColors.primaryNavy,
            tabs: const [
              Tab(icon: Icon(Icons.cloud_download), text: 'Google Drive'),
              Tab(icon: Icon(Icons.folder), text: 'Device Folder'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_statusMessage ?? 'Processing restore...', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Google Drive Backups
                      _buildDriveTab(dateFormat),
                      // Tab 2: Local Device Backups
                      _buildLocalTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveTab(DateFormat dateFormat) {
    if (_driveEmail == null || _driveEmail!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No Google Account Connected',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your Google Account to view and download your cloud backups.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Sign In with Google Drive',
              icon: Icons.add_to_drive,
              isLoading: _isLoadingDrive,
              onPressed: _connectAndFetchDrive,
            ),
          ],
        ),
      );
    }

    if (_isLoadingDrive) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_circle, size: 20, color: AppColors.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected: $_driveEmail',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh Backups',
              onPressed: _fetchDriveBackups,
            ),
          ],
        ),
        const Divider(height: 16),
        if (_driveBackups.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No backup archives found in SanghLedger_Backups folder on Google Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _driveBackups.length,
              itemBuilder: (ctx, i) {
                final item = _driveBackups[i];
                final sizeKb = ((item['size'] as int) / 1024).toStringAsFixed(1);
                final dateStr = item['createdTime'] != null
                    ? dateFormat.format(item['createdTime'] as DateTime)
                    : '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F0FE),
                      child: Icon(Icons.archive, color: AppColors.primaryNavy),
                    ),
                    title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('$dateStr • $sizeKb KB', style: const TextStyle(fontSize: 12)),
                    trailing: const ElevatedButton(
                      onPressed: null,
                      child: Text('Restore'),
                    ),
                    onTap: () => _restoreFromDriveItem(item),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocalTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configured Backup Folder:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                _configuredLocalFolder ?? 'Default app storage (/SanghLedger_Backups)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const Icon(Icons.folder_open, size: 56, color: AppColors.primaryNavy),
              const SizedBox(height: 12),
              const Text(
                'Pick Encrypted Backup File',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a SanghLedger_Backup_*.zip file from your phone storage or SD card.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Select Backup .ZIP File',
                icon: Icons.file_upload,
                onPressed: _pickAndRestoreLocalFile,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
