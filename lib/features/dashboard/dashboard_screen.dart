import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../data/repositories/organization_repository.dart';
import '../../l10n/app_localizations.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final orgAsync = ref.watch(organizationProvider);
    final org = orgAsync.valueOrNull;
    final rawName = (org?.name ?? '').trim();
    final titleText = rawName.isEmpty
        ? 'Sangh Ledger'
        : (rawName.toLowerCase().endsWith('ledger') || rawName.contains('ಲೆಡ್ಜರ್')
            ? rawName
            : '$rawName Ledger');
    final logoPath = org?.logoPath;
    final hasLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: hasLogo
                  ? ClipOval(
                      child: Image.file(
                        File(logoPath),
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    )
                  : ClipOval(
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 20, color: Colors.white),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titleText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(organizationProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: l10n.transactions,
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.transactions),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardSummaryProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Metrics Banner
              Card(
                color: AppColors.primaryNavy,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.financialTeal,
                        foregroundColor: Colors.white,
                        child: hasLogo
                            ? ClipOval(
                                child: Image.file(
                                  File(logoPath),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ClipOval(
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 28),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${summary.activeMembersCount} ${l10n.activeMembers} • ${summary.activeLoansCount} ${l10n.loans}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cash & Bank (Assets)
              Row(
                children: [
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.cashInHand,
                      amountPaise: summary.cashInHandPaise,
                      icon: Icons.payments_outlined,
                      color: AppColors.financialTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.bankBalance,
                      amountPaise: summary.bankBalancePaise,
                      icon: Icons.account_balance_outlined,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Savings Liabilities & Loan Principal Receivables
              Row(
                children: [
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.savingsLiabilities,
                      amountPaise: summary.savingsLiabilityPaise,
                      icon: Icons.savings_outlined,
                      color: AppColors.financialTealDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.loanReceivables,
                      amountPaise: summary.loanPrincipalReceivablePaise,
                      icon: Icons.monetization_on_outlined,
                      color: AppColors.errorCrimson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interest Receivables & Interest Income
              Row(
                children: [
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.interestReceivables,
                      amountPaise: summary.interestReceivablePaise,
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.warningAmber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.interestIncome,
                      amountPaise: summary.interestIncomePaise,
                      icon: Icons.trending_up,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions Header
              Text(
                'Quick Navigation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt),
                      label: Text(l10n.transactions),
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.transactions),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.analytics_outlined),
                      label: Text(l10n.reports),
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.reports),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
