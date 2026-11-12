import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/amount_input.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/loan_repository.dart';
import '../../domain/entities/loan.dart';
import '../../domain/services/accounting_engine.dart';
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

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  void _showCreateLoanDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? selectedMemberId;
    int? principalPaise;
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final membersAsync = ref.watch(membersListProvider);

          return AlertDialog(
            title: Text(l10n.issueLoan),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  membersAsync.when(
                    data: (members) {
                      final activeMembers = members.where((m) => m.isActive).toList();
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
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Failed to load members'),
                  ),
                  const SizedBox(height: 16),
                  AmountInput(
                    label: '${l10n.principalAmount} *',
                    onChanged: (val) => principalPaise = val,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(labelText: l10n.interestRate),
                    child: const Text(
                      '1.0% / month (100 basis points) - Reducing Balance',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.financialTeal),
                    ),
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
                    final repo = ref.read(loanRepositoryProvider);
                    final loan = await repo.createLoanDraft(
                      memberId: selectedMemberId!,
                      principalPaise: principalPaise!,
                      remarks: remarksController.text.trim(),
                    );
                    ref.invalidate(loansListProvider);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Loan created in Draft: ${loan.loanCode}')),
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
          title: Text('Disburse Loan ${loan.loanCode}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Principal: ${CurrencyFormatter.formatPaise(loan.principalPaise)}'),
              const SizedBox(height: 16),
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
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm Disbursement'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(loanRepositoryProvider);
        await repo.disburseLoan(loanId: loan.id, paymentMode: mode);
        ref.invalidate(loansListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loan ${loan.loanCode} successfully disbursed!')),
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loansAsync = ref.watch(loansListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loansTab)),
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
              amountPaise: 0,
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
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: loan.status == 'Active'
                              ? AppColors.errorCrimson.withValues(alpha: 0.1)
                              : AppColors.warningAmber.withValues(alpha: 0.1),
                          foregroundColor: loan.status == 'Active'
                              ? AppColors.errorCrimson
                              : AppColors.warningAmber,
                          child: Icon(loan.status == 'Active' ? Icons.monetization_on : Icons.edit_note),
                        ),
                        title: Row(
                          children: [
                            Text(loan.loanCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: loan.status == 'Active'
                                    ? AppColors.errorCrimson.withValues(alpha: 0.1)
                                    : AppColors.warningAmber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                loan.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: loan.status == 'Active'
                                      ? AppColors.errorCrimson
                                      : AppColors.warningAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Principal: ${CurrencyFormatter.formatPaise(loan.principalPaise)} @ 1%/mo',
                        ),
                        trailing: loan.status == 'Draft'
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.financialTeal,
                                  minimumSize: const Size(80, 36),
                                ),
                                onPressed: () => _disburseLoan(context, loan),
                                child: const Text('Disburse'),
                              )
                            : IconButton(
                                icon: const Icon(Icons.payment),
                                tooltip: 'Repay',
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.repayment,
                                    arguments: loan.id,
                                  );
                                },
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
