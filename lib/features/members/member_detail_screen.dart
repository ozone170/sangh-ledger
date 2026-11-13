import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/repayment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/entities/member.dart';
import '../../domain/services/receipt_sharing_service.dart';
import '../../features/loans/loans_screen.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/send_message_bottom_sheet.dart';
import 'members_controller.dart';

final memberDetailProvider = FutureProvider.family<Member?, String>((ref, id) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.getMemberById(id);
});

class MemberDetailScreen extends ConsumerWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final memberAsync = ref.watch(memberDetailProvider(memberId));

    return memberAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.memberDetails)),
        body: const LoadingState(),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.memberDetails)),
        body: ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(memberDetailProvider(memberId)),
        ),
      ),
      data: (member) {
        if (member == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.memberDetails)),
            body: const EmptyState(title: 'Member Not Found'),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${member.fullName} (${member.memberCode})'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => invalidateFinancialProviders(ref, memberId: member.id),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.financialTeal,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: l10n.overview),
                  Tab(text: l10n.savingsTab),
                  Tab(text: l10n.loansTab),
                  Tab(text: l10n.transactions),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildOverviewTab(context, ref, member, l10n),
                _buildSavingsTab(context, ref, member, l10n),
                _buildLoansTab(context, ref, member, l10n),
                _buildTransactionsTab(context, ref, member, l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    WidgetRef ref,
    Member member,
    AppLocalizations l10n,
  ) {
    final savingsAsync = ref.watch(memberSavingsBalanceProvider(member.id));
    final loanAsync = ref.watch(memberLoanPrincipalProvider(member.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: member.isActive
                            ? AppColors.successGreen.withValues(alpha: 0.1)
                            : AppColors.errorCrimson.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        member.isActive ? l10n.activeMembers : l10n.inactiveMembers,
                        style: TextStyle(
                          color: member.isActive ? AppColors.successGreen : AppColors.errorCrimson,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _infoRow(Icons.tag, l10n.memberCode, member.memberCode),
                const SizedBox(height: 8),
                _infoRow(Icons.phone, l10n.phone, member.phone),
                const SizedBox(height: 8),
                _infoRow(Icons.location_on, l10n.address, member.address),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FinancialSummaryCard(
                title: l10n.totalSavingsBalance,
                amountPaise: savingsAsync.value ?? 0,
                icon: Icons.savings_outlined,
                color: AppColors.financialTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FinancialSummaryCard(
                title: l10n.outstandingLoanPrincipal,
                amountPaise: loanAsync.value ?? 0,
                icon: Icons.account_balance_outlined,
                color: AppColors.errorCrimson,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          text: member.isActive ? 'Deactivate Member' : 'Activate Member',
          backgroundColor: member.isActive ? AppColors.errorCrimson : AppColors.successGreen,
          onPressed: () async {
            final confirm = await ConfirmationDialog.show(
              context,
              title: member.isActive ? 'Deactivate Member?' : 'Activate Member?',
              content: member.isActive
                  ? 'Inactive members cannot perform deposits, withdrawals, or take loans.'
                  : 'Activate member subject to 100 active members limit.',
              isDestructive: member.isActive,
            );
            if (confirm == true) {
              try {
                final repo = ref.read(memberRepositoryProvider);
                await repo.setMemberActiveStatus(member.id, !member.isActive);
                invalidateFinancialProviders(ref, memberId: member.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
                  );
                }
              }
            }
          },
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSavingsTab(
    BuildContext context,
    WidgetRef ref,
    Member member,
    AppLocalizations l10n,
  ) {
    final savingsBalanceAsync = ref.watch(memberSavingsBalanceProvider(member.id));
    final transactionsAsync = ref.watch(memberSavingsTransactionsProvider(member.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FinancialSummaryCard(
          title: l10n.totalSavingsBalance,
          amountPaise: savingsBalanceAsync.value ?? 0,
          icon: Icons.savings_outlined,
          color: AppColors.financialTeal,
        ),
        const SizedBox(height: 16),
        Text(
          'Savings Activity History',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        transactionsAsync.when(
          loading: () => const LoadingState(),
          error: (err, _) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(memberSavingsTransactionsProvider(member.id)),
          ),
          data: (transactions) {
            if (transactions.isEmpty) {
              return const EmptyState(title: 'No savings transactions for this member');
            }
            return Column(
              children: transactions.map((t) {
                final isDeposit = t['transaction_type'] == 'savings_deposit';
                final isReversed = (t['is_reversed'] as int) == 1;
                final amountPaise = t['amount_paise'] as int;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDeposit
                          ? AppColors.financialTeal.withValues(alpha: 0.1)
                          : AppColors.errorCrimson.withValues(alpha: 0.1),
                      foregroundColor: isDeposit ? AppColors.financialTeal : AppColors.errorCrimson,
                      child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward),
                    ),
                    title: Text(
                      '${t['receipt_number']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isReversed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      '${t['transaction_date'].toString().split('T').first} • Mode: ${t['payment_mode'].toString().toUpperCase()}',
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
                            final tx = await TransactionRepository().getTransactionByReceiptNumber(t['receipt_number'] as String);
                            final currentBal = savingsBalanceAsync.valueOrNull ?? 0;
                            if (context.mounted && tx != null) {
                              final msg = ReceiptSharingService.formatSavingsSummaryMessage(
                                sanghName: 'Sangh Ledger',
                                memberName: member.fullName,
                                memberCode: member.memberCode,
                                receiptNumber: t['receipt_number'] as String,
                                transactionType: t['transaction_type'] as String,
                                amountPaise: amountPaise,
                                date: DateTime.parse(t['transaction_date'] as String),
                                currentTotalSavingsPaise: currentBal,
                                remarks: t['remarks'] as String?,
                              );
                              SendMessageBottomSheet.show(
                                context,
                                transaction: tx,
                                memberPhone: member.phone,
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
    );
  }

  Widget _buildLoansTab(
    BuildContext context,
    WidgetRef ref,
    Member member,
    AppLocalizations l10n,
  ) {
    final loanPrincipalAsync = ref.watch(memberLoanPrincipalProvider(member.id));
    final loansAsync = ref.watch(loansListProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FinancialSummaryCard(
          title: l10n.outstandingLoanPrincipal,
          amountPaise: loanPrincipalAsync.value ?? 0,
          icon: Icons.account_balance_outlined,
          color: AppColors.errorCrimson,
        ),
        const SizedBox(height: 16),
        Text(
          'Loans for ${member.fullName}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        loansAsync.when(
          loading: () => const LoadingState(),
          error: (err, _) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(loansListProvider),
          ),
          data: (allLoans) {
            final memberLoans = allLoans.where((l) => l.memberId == member.id).toList();
            if (memberLoans.isEmpty) {
              return const EmptyState(title: 'No loans found for this member');
            }
            return Column(
              children: memberLoans.map((loan) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: loan.status == 'Active'
                          ? AppColors.errorCrimson.withValues(alpha: 0.1)
                          : AppColors.warningAmber.withValues(alpha: 0.1),
                      foregroundColor: loan.status == 'Active'
                          ? AppColors.errorCrimson
                          : AppColors.warningAmber,
                      child: const Icon(Icons.monetization_on_outlined),
                    ),
                    title: Text(loan.loanCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${loan.status} • Principal: ${CurrencyFormatter.formatPaise(loan.principalPaise)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loan.status != 'Draft')
                          IconButton(
                            icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF25D366)),
                            tooltip: 'Send Loan Statement',
                            onPressed: () async {
                              final summary = await RepaymentRepository().getLoanRepaymentSummary(loan.id);
                              final dummyTx = TransactionItem(
                                id: loan.id,
                                organizationId: loan.organizationId,
                                memberId: loan.memberId,
                                memberCode: member.memberCode,
                                memberName: member.fullName,
                                transactionType: 'loan_summary',
                                paymentMode: 'cash',
                                amountPaise: loan.principalPaise,
                                transactionDate: DateTime.now(),
                                receiptNumber: loan.loanCode,
                                isReversed: false,
                              );

                              final msg = ReceiptSharingService.formatLoanSummaryMessage(
                                sanghName: 'Sangh Ledger',
                                memberName: member.fullName,
                                memberCode: member.memberCode,
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
                                  memberPhone: member.phone,
                                  customInitialMessage: msg,
                                );
                              }
                            },
                          ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.loanDetail, arguments: loan.id);
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionsTab(
    BuildContext context,
    WidgetRef ref,
    Member member,
    AppLocalizations l10n,
  ) {
    final txAsync = ref.watch(memberTransactionsProvider(member.id));

    return txAsync.when(
      loading: () => const LoadingState(),
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: () => ref.invalidate(memberTransactionsProvider(member.id)),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const EmptyState(
            title: 'No transactions recorded',
            subtitle: 'All deposits, withdrawals, loans and repayments will show here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final t = transactions[index];
            final isCredit = t.transactionType == 'savings_deposit' || t.transactionType == 'loan_repayment';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCredit
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.errorCrimson.withValues(alpha: 0.1),
                  foregroundColor: isCredit ? AppColors.successGreen : AppColors.errorCrimson,
                  child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward),
                ),
                title: Text(
                  t.receiptNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: t.isReversed ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${t.transactionType.replaceAll('_', ' ').toUpperCase()} • ${t.transactionDate.toIso8601String().split('T').first}',
                ),
                trailing: Text(
                  '${isCredit ? '+' : '-'}${CurrencyFormatter.formatPaise(t.amountPaise)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: t.isReversed
                        ? AppColors.textSecondary
                        : isCredit
                            ? AppColors.successGreen
                            : AppColors.errorCrimson,
                    decoration: t.isReversed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
