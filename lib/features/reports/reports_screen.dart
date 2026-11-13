import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/services/pdf_report_service.dart';
import '../../domain/services/reports_service.dart';
import '../../l10n/app_localizations.dart';

final reportsServiceProvider = Provider<ReportsService>((ref) {
  return ReportsService();
});

final trialBalanceProvider = FutureProvider<TrialBalanceReport>((ref) async {
  final service = ref.watch(reportsServiceProvider);
  return service.getTrialBalance();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trialAsync = ref.watch(trialBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.trialBalance,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          trialAsync.when(
            loading: () => const LoadingState(),
            error: (err, _) => ErrorState(message: err.toString()),
            data: (report) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Ledger Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: report.isBalanced
                                  ? AppColors.successGreen.withValues(alpha: 0.1)
                                  : AppColors.errorCrimson.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.isBalanced ? 'BALANCED (DR == CR)' : 'UNBALANCED',
                              style: TextStyle(
                                color: report.isBalanced ? AppColors.successGreen : AppColors.errorCrimson,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ...report.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text('${item.accountCode} - ${item.accountName}', style: const TextStyle(fontSize: 13)),
                                const Spacer(),
                                Text(
                                  item.debitBalancePaise > 0
                                      ? 'DR ${CurrencyFormatter.formatPaise(item.debitBalancePaise)}'
                                      : 'CR ${CurrencyFormatter.formatPaise(item.creditBalancePaise)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sum of Debits: ${CurrencyFormatter.formatPaise(report.totalDebitsPaise)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Sum of Credits: ${CurrencyFormatter.formatPaise(report.totalCreditsPaise)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '12 Standard Sangh Reports',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _reportTile(context, ref, 1, Icons.people, '1. Member Register', 'All active and inactive registered members'),
          _reportTile(context, ref, 2, Icons.person, '2. Individual Member Ledger', 'Account statement per member'),
          _reportTile(context, ref, 3, Icons.savings, '3. Savings Register', 'Total member savings liabilities'),
          _reportTile(context, ref, 4, Icons.account_balance, '4. Loan Register', 'All issued loans & lifecycle statuses'),
          _reportTile(context, ref, 5, Icons.trending_up, '5. Outstanding Principal Report', 'Current unpaid principal balances'),
          _reportTile(context, ref, 6, Icons.alarm, '6. Outstanding Interest Report', 'Accrued reducing-balance interest due'),
          _reportTile(context, ref, 7, Icons.attach_money, '7. Interest Collected Report', 'All interest income earned & settled'),
          _reportTile(context, ref, 8, Icons.payment, '8. Repayment Report', 'Historical loan repayments and allocations'),
          _reportTile(context, ref, 9, Icons.book, '9. Daily Cashbook', 'Daily cash receipts and cash disbursements'),
          _reportTile(context, ref, 10, Icons.calendar_view_month, '10. Monthly Summary', 'Aggregated monthly financial positions'),
          _reportTile(context, ref, 11, Icons.balance, '11. Trial Balance', 'Double-entry debit & credit verification'),
          _reportTile(context, ref, 12, Icons.security, '12. Audit History Report', 'Immutable log of all user & financial actions'),
        ],
      ),
    );
  }

  Widget _reportTile(BuildContext context, WidgetRef ref, int index, IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryNavy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.picture_as_pdf, color: AppColors.financialTeal),
        onTap: () async {
          final service = ref.read(reportsServiceProvider);
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Generating PDF for $title...'), duration: const Duration(seconds: 1)),
            );
            await PdfReportService.exportReportByIndex(index, service);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error generating report: $e'), backgroundColor: AppColors.errorCrimson),
              );
            }
          }
        },
      ),
    );
  }
}
