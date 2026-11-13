import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/amount_input.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../data/repositories/savings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/accounting_engine.dart';
import '../../domain/services/receipt_sharing_service.dart';
import '../../l10n/app_localizations.dart';
import '../members/members_controller.dart';
import '../transactions/send_message_bottom_sheet.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository();
});

final recentSavingsActivitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getSavingsTransactions();
});

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  void _showDepositDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? selectedMemberId;
    int? depositPaise;
    PaymentMode mode = PaymentMode.cash;
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final membersAsync = ref.watch(activeMembersProvider);

          return AlertDialog(
            title: Text('${l10n.deposit} ${l10n.savings}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    label: '${l10n.amount} *',
                    onChanged: (val) => depositPaise = val,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PaymentMode>(
                    segments: [
                      ButtonSegment(value: PaymentMode.cash, label: Text(l10n.cash)),
                      ButtonSegment(value: PaymentMode.bank, label: Text(l10n.bank)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (set) => setDialogState(() => mode = set.first),
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
                  if (selectedMemberId == null || depositPaise == null || depositPaise! <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select member and valid amount')),
                    );
                    return;
                  }
                  try {
                    final repo = ref.read(savingsRepositoryProvider);
                    final rcp = await repo.recordDeposit(
                      memberId: selectedMemberId!,
                      amountPaise: depositPaise!,
                      paymentMode: mode,
                      remarks: remarksController.text.trim(),
                    );

                    // Explicitly invalidate all dependent financial providers
                    invalidateFinancialProviders(ref, memberId: selectedMemberId);
                    ref.invalidate(recentSavingsActivitiesProvider);

                    final txItem = await TransactionRepository().getTransactionByReceiptNumber(rcp);
                    final member = await MemberRepository().getMemberById(selectedMemberId!);
                    final memberBalances = await MemberRepository().getMembersWithBalances();
                    final updatedBal = memberBalances
                        .where((m) => m.member.id == selectedMemberId)
                        .map((m) => m.savingsBalancePaise)
                        .firstOrNull;

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (context.mounted && txItem != null) {
                      PostTransactionSuccessDialog.show(
                        context,
                        transaction: txItem,
                        memberPhone: member?.phone,
                        updatedBalancePaise: updatedBal,
                        balanceLabel: 'Savings Balance / ಉಳಿತಾಯ:',
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
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? selectedMemberId;
    int? withdrawPaise;
    PaymentMode mode = PaymentMode.cash;
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final membersWithBalAsync = ref.watch(membersWithBalancesProvider);

          return AlertDialog(
            title: Text('${l10n.withdraw} ${l10n.savings}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  membersWithBalAsync.when(
                    data: (members) {
                      final eligible = members.where((m) => m.member.isActive && m.savingsBalancePaise > 0).toList();
                      if (eligible.isEmpty) {
                        return const Text('No active members with savings balance available.');
                      }
                      final currentMember = eligible.where((m) => m.member.id == selectedMemberId).firstOrNull;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedMemberId,
                            decoration: InputDecoration(labelText: '${l10n.members} *'),
                            items: eligible
                                .map((m) => DropdownMenuItem(
                                      value: m.member.id,
                                      child: Text('${m.member.fullName} (${m.member.memberCode})'),
                                    ))
                                .toList(),
                            onChanged: (val) => setDialogState(() => selectedMemberId = val),
                          ),
                          if (currentMember != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Available Balance: ${CurrencyFormatter.formatPaise(currentMember.savingsBalancePaise)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.financialTeal, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Failed to load members'),
                  ),
                  const SizedBox(height: 16),
                  AmountInput(
                    label: '${l10n.amount} *',
                    onChanged: (val) => withdrawPaise = val,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PaymentMode>(
                    segments: [
                      ButtonSegment(value: PaymentMode.cash, label: Text(l10n.cash)),
                      ButtonSegment(value: PaymentMode.bank, label: Text(l10n.bank)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (set) => setDialogState(() => mode = set.first),
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
                  if (selectedMemberId == null || withdrawPaise == null || withdrawPaise! <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select member and valid amount')),
                    );
                    return;
                  }
                  try {
                    final repo = ref.read(savingsRepositoryProvider);
                    final rcp = await repo.recordWithdrawal(
                      memberId: selectedMemberId!,
                      amountPaise: withdrawPaise!,
                      paymentMode: mode,
                      reason: remarksController.text.trim().isNotEmpty
                          ? remarksController.text.trim()
                          : 'Member Savings Withdrawal',
                    );

                    invalidateFinancialProviders(ref, memberId: selectedMemberId);
                    ref.invalidate(recentSavingsActivitiesProvider);

                    final txItem = await TransactionRepository().getTransactionByReceiptNumber(rcp);
                    final member = await MemberRepository().getMemberById(selectedMemberId!);
                    final memberBalances = await MemberRepository().getMembersWithBalances();
                    final updatedBal = memberBalances
                        .where((m) => m.member.id == selectedMemberId)
                        .map((m) => m.savingsBalancePaise)
                        .firstOrNull;

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (context.mounted && txItem != null) {
                      PostTransactionSuccessDialog.show(
                        context,
                        transaction: txItem,
                        memberPhone: member?.phone,
                        updatedBalancePaise: updatedBal,
                        balanceLabel: 'Remaining Savings / ಉಳಿತಾಯ:',
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
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activitiesAsync = ref.watch(recentSavingsActivitiesProvider);

    final totalSavingsPaise = summaryAsync.when(
      data: (s) => s.savingsLiabilityPaise,
      loading: () => 0,
      error: (_, _) => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.savingsTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(recentSavingsActivitiesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(recentSavingsActivitiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinancialSummaryCard(
              title: l10n.savingsLiabilities,
              amountPaise: totalSavingsPaise,
              subtitle: 'Total savings balance deposited across all active members',
              icon: Icons.savings_outlined,
              color: AppColors.financialTeal,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: l10n.deposit,
                    icon: Icons.arrow_downward,
                    backgroundColor: AppColors.financialTeal,
                    onPressed: () => _showDepositDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    text: l10n.withdraw,
                    icon: Icons.arrow_upward,
                    onPressed: () => _showWithdrawDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Savings Activities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            activitiesAsync.when(
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(recentSavingsActivitiesProvider),
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return const EmptyState(
                    title: 'No Recent Savings Entries',
                    subtitle: 'Deposits and authorized withdrawals will be listed here.',
                    icon: Icons.history,
                  );
                }
                return Column(
                  children: activities.take(15).map((act) {
                    final isDeposit = act['transaction_type'] == 'savings_deposit';
                    final isReversed = (act['is_reversed'] as int) == 1;
                    final amountPaise = act['amount_paise'] as int;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isReversed
                              ? AppColors.textSecondary.withValues(alpha: 0.1)
                              : isDeposit
                                  ? AppColors.financialTeal.withValues(alpha: 0.1)
                                  : AppColors.errorCrimson.withValues(alpha: 0.1),
                          foregroundColor: isReversed
                              ? AppColors.textSecondary
                              : isDeposit
                                  ? AppColors.financialTeal
                                  : AppColors.errorCrimson,
                          child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward),
                        ),
                        title: Text(
                          '${act['member_name']} (${act['member_code']})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isReversed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${act['receipt_number']} • ${act['transaction_date'].toString().split('T').first}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isDeposit ? '+' : '-'}${CurrencyFormatter.formatPaise(amountPaise)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isReversed
                                    ? AppColors.textSecondary
                                    : isDeposit
                                        ? AppColors.financialTeal
                                        : AppColors.errorCrimson,
                                decoration: isReversed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF25D366)),
                              tooltip: 'Send Receipt',
                              onPressed: () async {
                                final memberBalances = await MemberRepository().getMembersWithBalances();
                                final bal = memberBalances
                                        .where((m) => m.member.id == act['member_id'])
                                        .map((m) => m.savingsBalancePaise)
                                        .firstOrNull ??
                                    0;
                                final member = await MemberRepository().getMemberById(act['member_id'] as String);
                                final tx = await TransactionRepository().getTransactionByReceiptNumber(act['receipt_number'] as String);
                                if (context.mounted && tx != null) {
                                  final msg = ReceiptSharingService.formatSavingsSummaryMessage(
                                    sanghName: (ref.read(organizationProvider).value?.name.trim().isNotEmpty == true) ? ref.read(organizationProvider).value!.name : 'Sangh Ledger',
                                    memberName: act['member_name'] as String,
                                    memberCode: act['member_code'] as String,
                                    receiptNumber: act['receipt_number'] as String,
                                    transactionType: act['transaction_type'] as String,
                                    amountPaise: amountPaise,
                                    date: DateTime.parse(act['transaction_date'] as String),
                                    currentTotalSavingsPaise: bal,
                                    remarks: act['remarks'] as String?,
                                  );
                                  SendMessageBottomSheet.show(
                                    context,
                                    transaction: tx,
                                    memberPhone: member?.phone,
                                    customInitialMessage: msg,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
