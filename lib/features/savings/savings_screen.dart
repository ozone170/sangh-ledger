import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/amount_input.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../data/repositories/savings_repository.dart';
import '../../domain/services/accounting_engine.dart';
import '../../l10n/app_localizations.dart';
import '../members/members_controller.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository();
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
          final membersAsync = ref.watch(membersListProvider);

          return AlertDialog(
            title: Text('${l10n.deposit} ${l10n.savings}'),
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
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deposit posted! Receipt: $rcp')),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsTab)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FinancialSummaryCard(
            title: l10n.savingsLiabilities,
            amountPaise: 0,
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select member from Members tab to withdraw')),
                    );
                  },
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
          const EmptyState(
            title: 'No Recent Savings Entries',
            subtitle: 'Deposits and authorized withdrawals will be listed here.',
            icon: Icons.history,
          ),
        ],
      ),
    );
  }
}
