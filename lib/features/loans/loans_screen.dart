import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/amount_input.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../domain/entities/loan.dart';
import '../../domain/services/accounting_engine.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/repayment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/receipt_sharing_service.dart';
import '../transactions/send_message_bottom_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../members/members_controller.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository();
});

final loansListProvider = FutureProvider<List<Loan>>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getLoans();
});

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  /// Converts decimal percentage string (e.g. "1.5") into integer basis points (150) without float math
  static int parseRateToBps(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 100;
    final parts = clean.split('.');
    final whole = int.tryParse(parts[0]) ?? 0;
    int frac = 0;
    if (parts.length > 1) {
      final fracStr = parts[1].padRight(2, '0').substring(0, 2);
      frac = int.tryParse(fracStr) ?? 0;
    }
    final bps = (whole * 100) + frac;
    if (bps < 0 || bps > 10000) {
      throw ArgumentError('Monthly interest rate must be between 0% and 100%');
    }
    return bps;
  }

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  void _showCreateLoanDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? selectedMemberId;
    int? principalPaise;
    final interestRateController = TextEditingController(text: '1.0');
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final membersAsync = ref.watch(activeMembersProvider);

          return AlertDialog(
            title: Text(l10n.issueLoan),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  membersAsync.when(
                    data: (members) {
                      final activeMembers = members.where((m) => m.isActive).toList();
                      if (activeMembers.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No active members found. Please register members first.',
                            style: TextStyle(color: AppColors.errorCrimson),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: selectedMemberId,
                        decoration: InputDecoration(labelText: '${l10n.members} *'),
                        items: activeMembers
                            .map((m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text('${m.fullName} (${m.memberCode})'),
                                ))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedMemberId = val),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Failed to load members: $err', style: const TextStyle(color: AppColors.errorCrimson)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AmountInput(
                    label: '${l10n.principalAmount} *',
                    onChanged: (val) => principalPaise = val,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: interestRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${l10n.interestRate} *',
                      suffixText: '% / mo',
                      helperText: 'Reducing Balance • 30-Day Month Convention',
                    ),
                    onChanged: (val) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1.0%'),
                        selected: interestRateController.text.trim() == '1.0' || interestRateController.text.trim() == '1',
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() => interestRateController.text = '1.0');
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('1.5%'),
                        selected: interestRateController.text.trim() == '1.5',
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() => interestRateController.text = '1.5');
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('2.0%'),
                        selected: interestRateController.text.trim() == '2.0' || interestRateController.text.trim() == '2',
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() => interestRateController.text = '2.0');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(labelText: l10n.remarks),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedMemberId == null || principalPaise == null || principalPaise! <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select member and principal amount')),
                    );
                    return;
                  }
                  try {
                    final bps = LoansScreen.parseRateToBps(interestRateController.text);
                    final repo = ref.read(loanRepositoryProvider);
                    final loan = await repo.createLoanDraft(
                      memberId: selectedMemberId!,
                      principalPaise: principalPaise!,
                      monthlyInterestBps: bps,
                      remarks: remarksController.text.trim(),
                    );
                    invalidateFinancialProviders(ref, memberId: selectedMemberId, loanId: loan.id);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Loan created in Draft: ${loan.loanCode}'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
                      );
                    }
                  }
                },
                child: const Text('Create Draft'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _disburseLoan(BuildContext context, Loan loan) async {
    final l10n = AppLocalizations.of(context)!;
    PaymentMode mode = PaymentMode.cash;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${l10n.disburseLoan} ${loan.loanCode}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Principal: ${CurrencyFormatter.formatPaise(loan.principalPaise)}'),
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
        final rcp = await repo.disburseLoan(loanId: loan.id, paymentMode: mode);
        invalidateFinancialProviders(ref, memberId: loan.memberId, loanId: loan.id);

        final txItem = await TransactionRepository().getTransactionByReceiptNumber(rcp);
        final member = await MemberRepository().getMemberById(loan.memberId);

        if (context.mounted) {
          if (txItem != null) {
            PostTransactionSuccessDialog.show(
              context,
              transaction: txItem,
              memberPhone: member?.phone,
              updatedBalancePaise: loan.principalPaise,
              balanceLabel: 'Loan Principal / ಸಾಲದ ಮೊತ್ತ:',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.loanDisbursedSuccess),
                backgroundColor: AppColors.successGreen,
              ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loansAsync = ref.watch(loansListProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    final loanReceivablePaise = summaryAsync.when(
      data: (s) => s.loanPrincipalReceivablePaise,
      loading: () => 0,
      error: (_, _) => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loansTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(loansListProvider);
              ref.invalidate(dashboardSummaryProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(l10n.issueLoan),
        onPressed: () => _showCreateLoanDialog(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FinancialSummaryCard(
              title: l10n.loanReceivables,
              amountPaise: loanReceivablePaise,
              subtitle: 'Total outstanding principal across active loans',
              icon: Icons.account_balance_outlined,
              color: AppColors.errorCrimson,
            ),
          ),
          Expanded(
            child: loansAsync.when(
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(loansListProvider),
              ),
              data: (loans) {
                if (loans.isEmpty) {
                  return EmptyState(
                    title: 'No Loans Found',
                    subtitle: 'Issue a new loan to an active member.',
                    actionText: l10n.issueLoan,
                    onAction: () => _showCreateLoanDialog(context),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: loans.length,
                  itemBuilder: (context, index) {
                    final loan = loans[index];
                    final isDraft = loan.status == 'Draft';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.loanDetail,
                            arguments: loan.id,
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: isDraft
                              ? AppColors.warningAmber.withValues(alpha: 0.15)
                              : loan.status == 'Closed'
                                  ? AppColors.successGreen.withValues(alpha: 0.15)
                                  : AppColors.errorCrimson.withValues(alpha: 0.15),
                          foregroundColor: isDraft
                              ? AppColors.warningAmber
                              : loan.status == 'Closed'
                                  ? AppColors.successGreen
                                  : AppColors.errorCrimson,
                          child: Icon(isDraft ? Icons.edit_note : Icons.monetization_on),
                        ),
                        title: Row(
                          children: [
                            Text(loan.loanCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDraft
                                    ? AppColors.warningAmber.withValues(alpha: 0.1)
                                    : loan.status == 'Closed'
                                        ? AppColors.successGreen.withValues(alpha: 0.1)
                                        : AppColors.errorCrimson.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                loan.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDraft
                                      ? AppColors.warningAmber
                                      : loan.status == 'Closed'
                                          ? AppColors.successGreen
                                          : AppColors.errorCrimson,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Principal: ${CurrencyFormatter.formatPaise(loan.principalPaise)} @ ${(loan.monthlyInterestBps / 100).toStringAsFixed(loan.monthlyInterestBps % 100 == 0 ? 1 : 2)}%/mo',
                        ),
                        trailing: isDraft
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.financialTeal,
                                  minimumSize: const Size(80, 36),
                                ),
                                onPressed: () => _disburseLoan(context, loan),
                                child: Text(l10n.disburseLoan),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 20),
                                    tooltip: 'Send Loan Statement',
                                    onPressed: () async {
                                      final summary = await RepaymentRepository().getLoanRepaymentSummary(loan.id);
                                      final member = await MemberRepository().getMemberById(loan.memberId);
                                      final dummyTx = TransactionItem(
                                        id: loan.id,
                                        organizationId: loan.organizationId,
                                        memberId: loan.memberId,
                                        memberCode: member?.memberCode ?? '',
                                        memberName: member?.fullName ?? 'Member',
                                        transactionType: 'loan_summary',
                                        paymentMode: 'cash',
                                        amountPaise: loan.principalPaise,
                                        transactionDate: DateTime.now(),
                                        receiptNumber: loan.loanCode,
                                        isReversed: false,
                                      );

                                      final msg = ReceiptSharingService.formatLoanSummaryMessage(
                                        sanghName: (ref.read(organizationProvider).value?.name.trim().isNotEmpty == true) ? ref.read(organizationProvider).value!.name : 'Sangh Ledger',
                                        memberName: member?.fullName ?? 'Member',
                                        memberCode: member?.memberCode ?? '',
                                        loanCode: loan.loanCode,
                                        principalPaise: summary['principalPaise'] as int,
                                        accruedInterestPaise: summary['accruedInterestPaise'] as int,
                                        totalPendingPaise: summary['totalOutstandingPaise'] as int,
                                        monthlyBps: loan.monthlyInterestBps,
                                      );

                                      if (context.mounted) {
                                        SendMessageBottomSheet.show(
                                          context,
                                          transaction: dummyTx,
                                          memberPhone: member?.phone,
                                          customInitialMessage: msg,
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.payment, color: AppColors.financialTeal),
                                    tooltip: l10n.recordRepayment,
                                    onPressed: () {
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.repayment,
                                        arguments: loan.id,
                                      );
                                    },
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
