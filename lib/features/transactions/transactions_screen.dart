import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/inputs.dart';
import '../../core/ui/list_items.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/pdf_receipt_service.dart';
import '../../domain/services/receipt_sharing_service.dart';
import '../../l10n/app_localizations.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class TransactionFilterState {
  final String searchQuery;
  final String? type;

  const TransactionFilterState({this.searchQuery = '', this.type});

  TransactionFilterState copyWith({String? searchQuery, String? type}) {
    return TransactionFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      type: type ?? this.type,
    );
  }
}

final transactionFilterProvider = StateProvider<TransactionFilterState>((ref) {
  return const TransactionFilterState();
});

final transactionsListProvider = FutureProvider<List<TransactionItem>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);
  return repo.getTransactions(
    query: filter.searchQuery,
    transactionType: filter.type,
  );
});

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTransactionDetails(BuildContext context, TransactionItem tx) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(transactionRepositoryProvider);
    final detail = await repo.getTransactionDetails(tx.id);

    if (!context.mounted || detail == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Receipt #${tx.receiptNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (tx.isReversed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorCrimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('REVERSED', style: TextStyle(color: AppColors.errorCrimson, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 24),
            _detailRow('Member:', '${tx.memberName} (${tx.memberCode})'),
            _detailRow('Type:', tx.transactionType.replaceAll('_', ' ').toUpperCase()),
            _detailRow('Amount:', CurrencyFormatter.formatPaise(tx.amountPaise), isBold: true),
            _detailRow('Date:', tx.transactionDate.toIso8601String().substring(0, 10)),
            _detailRow('Mode:', tx.paymentMode.toUpperCase()),
            if (tx.remarks != null) _detailRow('Remarks:', tx.remarks!),
            if (tx.isReversed && tx.reversalReason != null)
              _detailRow('Reversal Reason:', tx.reversalReason!, color: AppColors.errorCrimson),
            const SizedBox(height: 16),
            const Text('Double-Entry Journal Lines', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...detail.journalLines.map((line) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceNeutral,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Account ${line['account_code']}'),
                      Text(
                        (line['debit_paise'] as int) > 0
                            ? 'DR ${CurrencyFormatter.formatPaise(line['debit_paise'] as int)}'
                            : 'CR ${CurrencyFormatter.formatPaise(line['credit_paise'] as int)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ReceiptSharingService.showShareOptionsModal(
                        context,
                        transaction: tx,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print (PDF)'),
                    onPressed: () async {
                      await PdfReceiptService.printReceipt(
                        sanghName: 'Sangh Ledger',
                        sanghAddress: 'Main Branch',
                        transaction: tx,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (!tx.isReversed) ...[
              const SizedBox(height: 12),
              PrimaryButton(
                text: l10n.reversal,
                icon: Icons.undo,
                backgroundColor: AppColors.errorCrimson,
                onPressed: () => _promptReversal(context, tx),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _promptReversal(BuildContext context, TransactionItem tx) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt #${tx.receiptNumber} (${CurrencyFormatter.formatPaise(tx.amountPaise)}) will be marked as reversed and equal-and-opposite journal entries will be posted.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Mandatory Reason *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorCrimson),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm Reversal'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(transactionRepositoryProvider);
        await repo.reverseTransaction(
          transactionId: tx.id,
          reason: reasonController.text.trim(),
        );
        invalidateFinancialProviders(ref, memberId: tx.memberId);
        if (context.mounted) {
          Navigator.of(context).pop(); // close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction successfully reversed and ledger balanced!')),
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

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final txAsync = ref.watch(transactionsListProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchField(
              controller: _searchController,
              hint: 'Search by receipt, member or code...',
              onChanged: (val) {
                ref.read(transactionFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: val);
              },
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(transactionsListProvider),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyState(
                    title: 'No Transactions Found',
                    subtitle: 'Recorded deposits, withdrawals, disbursements and repayments will appear here.',
                    icon: Icons.receipt_long,
                  );
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isCredit = tx.transactionType == 'savings_deposit' ||
                        tx.transactionType == 'loan_repayment';

                    return TransactionListItem(
                      title: '${tx.memberName} (${tx.memberCode})',
                      subtitle: tx.receiptNumber,
                      date: tx.transactionDate.toIso8601String().substring(0, 10),
                      amountPaise: tx.amountPaise,
                      isCredit: isCredit,
                      badgeText: tx.isReversed ? 'REVERSED' : tx.transactionType.replaceAll('_', ' ').toUpperCase(),
                      onTap: () => _showTransactionDetails(context, tx),
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
