import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../domain/services/backup_service.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());
  late PageController _pageController;
  int _currentStep = 0;
  bool _isCommitting = false;
  bool _showChoice = true;

  // Screen 1 controllers
  late final TextEditingController _sanghNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _regNoController;

  // Screen 2 controllers
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  // Screen 3 controllers
  late final TextEditingController _pinController;
  late final TextEditingController _recoveryQuestionController;
  late final TextEditingController _recoveryAnswerController;
  bool _biometricOptIn = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    _currentStep = draft.currentStep;
    if (_currentStep > 0 || draft.sanghName.isNotEmpty) {
      _showChoice = false;
    }
    _pageController = PageController(initialPage: _currentStep);

    _sanghNameController = TextEditingController(text: draft.sanghName);
    _addressController = TextEditingController(text: draft.address);
    _phoneController = TextEditingController(text: draft.contactPhone);
    _regNoController = TextEditingController(text: draft.registrationNumber ?? '');

    _usernameController = TextEditingController(text: draft.username);
    _passwordController = TextEditingController(text: draft.password);
    _confirmPasswordController = TextEditingController(text: draft.password);

    _pinController = TextEditingController(text: draft.pin ?? '');
    _recoveryQuestionController = TextEditingController(text: draft.recoveryQuestion);
    _recoveryAnswerController = TextEditingController(text: draft.recoveryAnswer);
    _biometricOptIn = draft.biometricEnabled;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sanghNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _regNoController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _recoveryQuestionController.dispose();
    _recoveryAnswerController.dispose();
    super.dispose();
  }

  void _syncDraft() {
    final updated = ref.read(onboardingProvider).copyWith(
          currentStep: _currentStep,
          sanghName: _sanghNameController.text.trim(),
          address: _addressController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          registrationNumber: _regNoController.text.trim().isEmpty ? null : _regNoController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          pin: _pinController.text.trim().isEmpty ? null : _pinController.text.trim(),
          biometricEnabled: _biometricOptIn,
          recoveryQuestion: _recoveryQuestionController.text.trim(),
          recoveryAnswer: _recoveryAnswerController.text.trim(),
        );
    ref.read(onboardingProvider.notifier).saveStep(updated);
  }

  void _nextStep() {
    if (_currentStep < 5) {
      if (_formKeys[_currentStep].currentState?.validate() ?? true) {
        _syncDraft();
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _syncDraft();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isCommitting = true);
    try {
      _syncDraft();
      await ref.read(onboardingProvider.notifier).commitOrganizationSetup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sangh organization & admin setup completed!')),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.mainShell);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e'), backgroundColor: AppColors.errorCrimson),
      );
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (files.isEmpty || files.first.path == null || !context.mounted) return;
    final backupFile = File(files.first.path!);
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Encrypted Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup File: ${backupFile.path.split(Platform.pathSeparator).last}'),
            const SizedBox(height: 12),
            const Text('Enter the Admin password that was used when creating this backup:'),
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
            onPressed: () {
              if (passwordController.text.isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: const Text('Decrypt & Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty && context.mounted) {
      try {
        await BackupService().restoreBackup(
          backupZipFile: backupFile,
          adminPassword: passwordController.text,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully! Welcome back.'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          Navigator.of(context).pushReplacementNamed(AppRoutes.mainShell);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.errorCrimson),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    if (_showChoice) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            TextButton(
              onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
              child: Text(
                currentLocale.languageCode == 'en' ? 'ಕನ್ನಡ' : 'English',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance, size: 64, color: AppColors.primaryNavy),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Sangh Ledger',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to set up your financial ledger:',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Choice 1: New Setup
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.financialTeal, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _showChoice = false),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.financialTeal,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.add_business_rounded),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Sangh Setup / ಹೊಸ ಸಂಘ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Set up a new organization, admin password, and initial ledger.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.financialTeal),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Choice 2: Restore from Backup
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleRestoreBackup(context),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.restore_page_rounded),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restore from Backup / ಮರುಸ್ಥಾಪಿಸಿ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Migrating from another phone or reinstalling? Restore from .zip backup.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primaryNavy),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.firstTimeSetup} (${_currentStep + 1}/6)'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showChoice = true),
              ),
        actions: [
          TextButton(
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            child: Text(
              currentLocale.languageCode == 'en' ? 'ಕನ್ನಡ' : 'English',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            backgroundColor: AppColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.financialTeal),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(l10n),
                _buildStep2(l10n),
                _buildStep3(l10n),
                _buildStep4(l10n),
                _buildStep5(l10n),
                _buildStep6(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen 1: Language & Organization Profile
  Widget _buildStep1(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1: Organization Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Enter your Sangh name and primary contact details.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: _sanghNameController,
              decoration: const InputDecoration(labelText: 'Sangh Name *', prefixIcon: Icon(Icons.business)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(labelText: '${l10n.address} *', prefixIcon: const Icon(Icons.location_on)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: '${l10n.phone} *', prefixIcon: const Icon(Icons.phone)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regNoController,
              decoration: const InputDecoration(labelText: 'Registration Number (Optional)', prefixIcon: Icon(Icons.assignment)),
            ),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Next: Admin Account', onPressed: _nextStep),
          ],
        ),
      ),
    );
  }

  // Screen 2: Administrator Account
  Widget _buildStep2(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 2: Administrator Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Create the master administrator account for this device.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: '${l10n.username} *', prefixIcon: const Icon(Icons.person)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: '${l10n.password} (Min 6 chars) *', prefixIcon: const Icon(Icons.lock)),
              validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: '${l10n.confirmPassword} *', prefixIcon: const Icon(Icons.lock_outline)),
              validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Next: Security Setup', onPressed: _nextStep),
          ],
        ),
      ),
    );
  }

  // Screen 3: Security Setup
  Widget _buildStep3(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 3: Security Setup', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Configure quick unlock PIN and password recovery question.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(labelText: '${l10n.pin} (Optional 4-6 digits)', prefixIcon: const Icon(Icons.pin)),
            ),
            SwitchListTile(
              title: Text(l10n.biometricLogin),
              subtitle: const Text('Unlock quickly with fingerprint or face'),
              value: _biometricOptIn,
              onChanged: (val) => setState(() => _biometricOptIn = val),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _recoveryQuestionController,
              decoration: const InputDecoration(labelText: 'Security Recovery Question *', prefixIcon: Icon(Icons.help_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _recoveryAnswerController,
              decoration: const InputDecoration(labelText: 'Security Recovery Answer *', prefixIcon: Icon(Icons.check_circle_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Next: Financial Defaults', onPressed: _nextStep),
          ],
        ),
      ),
    );
  }

  // Screen 4: Financial Defaults
  Widget _buildStep4(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 4: Non-Negotiable Financial Defaults', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('As defined in AGENTS.md, these financial rules are locked by system policy:', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _buildDefaultTile(Icons.currency_rupee, 'Currency', 'Indian Rupee (INR - ₹) in exact integer paise'),
          _buildDefaultTile(Icons.percent, 'Interest Rate', '1% monthly reducing-balance (100 basis points)'),
          _buildDefaultTile(Icons.calendar_month, 'Day-Count Convention', '365-day reducing daily balance basis'),
          _buildDefaultTile(Icons.group, 'Member Scale Constraint', 'Maximum 100 active members (SGH001–SGH100)'),
          _buildDefaultTile(Icons.account_balance, 'Accounting Method', 'Strict Double-Entry Balanced Ledger (Assets = Liabilities + Equity)'),
          const SizedBox(height: 24),
          PrimaryButton(text: 'Next: Review Settings', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildDefaultTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.financialTeal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.lock, size: 18, color: AppColors.textMuted),
      ),
    );
  }

  // Screen 5: Review
  Widget _buildStep5(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 5: Review Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Verify your settings before initializing the encrypted ledger.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildReviewRow('Sangh Name', _sanghNameController.text),
                  _buildReviewRow('Address', _addressController.text),
                  _buildReviewRow('Contact Phone', _phoneController.text),
                  _buildReviewRow('Admin Username', _usernameController.text),
                  _buildReviewRow('PIN Configured', _pinController.text.isNotEmpty ? 'Yes (Hashed)' : 'No'),
                  _buildReviewRow('Biometrics', _biometricOptIn ? 'Enabled' : 'Disabled'),
                  _buildReviewRow('Financial Year', 'April 1st Start'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(text: 'Proceed to Commit', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Screen 6: Commit & Complete
  Widget _buildStep6(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, size: 64, color: AppColors.financialTeal),
            const SizedBox(height: 20),
            Text(
              'Ready to Initialize Ledger',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your organization and administrator credentials will be atomically recorded in the encrypted SQLCipher database.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Initialize & Launch Sangh Ledger',
              isLoading: _isCommitting,
              onPressed: _completeSetup,
            ),
          ],
        ),
      ),
    );
  }
}
