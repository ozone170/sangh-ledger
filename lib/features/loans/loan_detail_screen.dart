import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/accounting_engine.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/send_message_bottom_sheet.dart';
import 'loans_screen.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  void _disburseLoan(BuildContext context, WidgetRef ref, String loanId, String loanCode, int principalPaise, String memberId) async {
    final l10n = AppLocalizations.of(context)!;
    PaymentMode mode = PaymentMode.cash;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${l10n.disburseLoan} $loanCode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.principalAmount}: ${CurrencyFormatter.formatPaise(principalPaise)}'),
              const SizedBox(height: 16),
              Text('${l10n.mode}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<PaymentMode>(
                segments: [
                  ButtonSegment(value: PaymentMode.cash, label: Text(l10n.cash)),
                  ButtonSegment(value: PaymentMode.bank, label: Text(l10n.bank)),
                ],
                selected: {mode},
                onSelectionChanged: (set) => setDialogState(() => mode = set.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financialTeal),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(loanRepositoryProvider);
        final rcp = await repo.disburseLoan(loanId: loanId, paymentMode: mode);
        invalidateFinancialProviders(ref, memberId: memberId, loanId: loanId);

        final txItem = await TransactionRepository().getTransactionByReceiptNumber(rcp);
        final member = await MemberRepository().getMemberById(memberId);

        if (context.mounted) {
          if (txItem != null) {
            PostTransactionSuccessDialog.show(
              context,
              transaction: txItem,
              memberPhone: member?.phone,
              updatedBalancePaise: principalPaise,
              balanceLabel: 'Loan Principal / ಸಾಲದ ಮೊತ್ತ:',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.loanDisbursedSuccess), backgroundColor: AppColors.successGreen),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
          );
        }
      }
    }
  }

  void _reverseDisbursement(BuildContext context, WidgetRef ref, String loanId, String loanCode, String memberId) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.reverseDisbursement} ($loanCode)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reverseDisbursementConfirm),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: '${l10n.reversalReason} *',
                hintText: 'e.g. Accidental disbursement entry',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorCrimson),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.errorRequired)),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(loanRepositoryProvider);
        await repo.reverseDisbursement(
          loanId: loanId,
          reason: reasonController.text.trim(),
        );
        invalidateFinancialProviders(ref, memberId: memberId, loanId: loanId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.disbursementReversedSuccess), backgroundColor: AppColors.successGreen),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final loanDetailAsync = ref.watch(loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.loans} $loanId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
          ),
        ],
      ),
      body: loanDetailAsync.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(loanDetailProvider(loanId)),
        ),
        data: (detail) {
          if (detail == null) {
            return const EmptyState(title: 'Loan Not Found');
          }

          final loan = detail.loan;
          final isDraft = loan.status == 'Draft';
          final isActive = loan.status == 'Active' || loan.status == 'Partially Repaid';
          final canReverse = isActive && detail.repaymentsCount == 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loan.loanCode,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDraft
                                  ? AppColors.warningAmber.withValues(alpha: 0.15)
                                  : loan.status == 'Closed'
                                      ? AppColors.successGreen.withValues(alpha: 0.15)
                                      : AppColors.errorCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              loan.status,
                              style: TextStyle(
                                color: isDraft
                                    ? AppColors.warningAmber
                                    : loan.status == 'Closed'
                                        ? AppColors.successGreen
                                        : AppColors.errorCrimson,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '${detail.memberName} (${detail.memberCode})',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.percent, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '1.0% / month (100 bps) - Reducing Balance (365 days)',
                            style: const TextStyle(color: AppColors.financialTeal, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text('Issue Date: ${loan.issueDate.toIso8601String().split('T').first}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Balances Cards
              Row(
                children: [
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.principalAmount,
                      amountPaise: loan.principalPaise,
                      icon: Icons.payments_outlined,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialSummaryCard(
                      title: l10n.outstandingLoanPrincipal,
                      amountPaise: detail.outstandingPrincipalPaise,
                      icon: Icons.account_balance_outlined,
                      color: AppColors.errorCrimson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FinancialSummaryCard(
                      title: 'Repaid Principal',
                      amountPaise: detail.totalRepaidPrincipalPaise,
                      icon: Icons.check_circle_outline,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialSummaryCard(
                      title: 'Paid Interest',
                      amountPaise: detail.totalPaidInterestPaise,
                      icon: Icons.trending_up,
                      color: AppColors.financialTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Post-Disbursement / Pre-Disbursement Action Area
              if (isDraft) ...[
                PrimaryButton(
                  text: l10n.disburseLoan,
                  icon: Icons.check,
                  backgroundColor: AppColors.financialTeal,
                  onPressed: () => _disburseLoan(
                    context,
                    ref,
                    loan.id,
                    loan.loanCode,
                    loan.principalPaise,
                    loan.memberId,
                  ),
                ),
              ] else if (isActive) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PrimaryButton(
                        text: l10n.recordRepayment,
                        icon: Icons.payment,
                        backgroundColor: AppColors.primaryNavy,
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.repayment,
                            arguments: loan.id,
                          );
                        },
                      ),
                    ),
                    if (canReverse) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SecondaryButton(
                          text: l10n.reverseDisbursement,
                          icon: Icons.undo,
                          onPressed: () => _reverseDisbursement(
                            context,
                            ref,
                            loan.id,
                            loan.loanCode,
                            loan.memberId,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Repayment History
              Text(
                l10n.repaymentHistory,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (detail.repayments.isEmpty)
                EmptyState(
                  title: l10n.noRepaymentsYet,
                  subtitle: isDraft
                      ? 'Disburse the loan to begin tracking repayments.'
                      : 'Record loan repayments using the button above.',
                  icon: Icons.history,
                )
              else
                Column(
                  children: detail.repayments.map((rep) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.payment, size: 20),
                        ),
                        title: Text(
                          rep.receiptNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${rep.paymentDate.toIso8601String().split('T').first} • Interest: ${CurrencyFormatter.formatPaise(rep.interestPortionPaise)} • Principal: ${CurrencyFormatter.formatPaise(rep.principalPortionPaise)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaise(rep.totalPaidPaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.successGreen,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF25D366)),
                              tooltip: 'Send Message (WhatsApp/SMS/PDF)',
                              onPressed: () async {
                                final member = await MemberRepository().getMemberById(loan.memberId);
                                final tx = TransactionItem(
                                  id: rep.transactionId,
                                  organizationId: loan.organizationId,
                                  memberId: loan.memberId,
                                  memberCode: detail.memberCode,
                                  memberName: detail.memberName,
                                  transactionType: 'loan_repayment',
                                  paymentMode: 'cash',
                                  amountPaise: rep.totalPaidPaise,
                                  transactionDate: rep.paymentDate,
                                  receiptNumber: rep.receiptNumber,
                                  remarks: 'Interest: ${CurrencyFormatter.formatPaise(rep.interestPortionPaise)}, Principal: ${CurrencyFormatter.formatPaise(rep.principalPortionPaise)}',
                                  isReversed: false,
                                );
                                if (context.mounted) {
                                  SendMessageBottomSheet.show(
                                    context,
                                    transaction: tx,
                                    memberPhone: member?.phone,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
