import 'package:flutter/material.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sangh Ledger')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance, size: 64, color: AppColors.primaryNavy),
              const SizedBox(height: 16),
              Text(
                'Sangh Ledger',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Offline-first Community Financial Ledger',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Login to Ledger',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.mainShell);
                },
              ),
              const SizedBox(width: 8, height: 12),
              SecondaryButton(
                text: 'First-Time Setup (Onboarding)',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.onboarding);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
