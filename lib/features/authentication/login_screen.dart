import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../data/repositories/organization_repository.dart';
import '../../l10n/app_localizations.dart';

final isAppInitializedProvider = FutureProvider<bool>((ref) async {
  try {
    final db = await AppDatabase().database;
    final orgs = await db.rawQuery('SELECT COUNT(*) as count FROM organizations WHERE is_initialized = 1');
    final orgCount = Sqflite.firstIntValue(orgs) ?? 0;
    final admins = await db.rawQuery('SELECT COUNT(*) as count FROM admins');
    final adminCount = Sqflite.firstIntValue(admins) ?? 0;
    return orgCount > 0 && adminCount > 0;
  } catch (_) {
    return false;
  }
});

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final isInitAsync = ref.watch(isAppInitializedProvider);
    final isInitialized = isInitAsync.valueOrNull ?? false;
    final orgAsync = ref.watch(organizationProvider);
    final org = orgAsync.valueOrNull;

    final logoPath = org?.logoPath;
    final hasCustomLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
    final rawName = (org?.name ?? '').trim();
    final displayName = rawName.isEmpty
        ? l10n.appTitle
        : (rawName.toLowerCase().endsWith('ledger') || rawName.contains('ಲೆಡ್ಜರ್')
            ? rawName
            : '$rawName Ledger');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            icon: const Icon(Icons.language, color: Colors.white, size: 18),
            label: Text(
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
              // Dynamic Sangh Logo (custom uploaded logo or branded app emblem)
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primaryNavy, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: hasCustomLogo
                    ? ClipOval(
                        child: Image.file(
                          File(logoPath),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      )
                    : ClipOval(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 54, color: AppColors.primaryNavy),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                textAlign: TextAlign.center,
              ),
              if (org?.registrationNumber != null && org!.registrationNumber!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Reg: ${org.registrationNumber}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Offline-first Community Financial Ledger',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: l10n.loginToLedger,
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.mainShell);
                },
              ),
              if (!isInitialized) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  text: l10n.firstTimeSetup,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.onboarding);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
