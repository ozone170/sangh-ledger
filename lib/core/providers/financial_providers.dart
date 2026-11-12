import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/accounting_engine.dart';
import '../../features/loans/loans_screen.dart';
import '../../features/members/member_detail_screen.dart';
import '../../features/members/members_controller.dart';
import '../../features/savings/savings_screen.dart';
import '../../features/transactions/transactions_screen.dart';

final accountingEngineProvider = Provider<AccountingEngine>((ref) {
  return AccountingEngine();
});

final accountBalancesProvider = FutureProvider<Map<String, int>>((ref) async {
  final engine = ref.watch(accountingEngineProvider);
  return engine.getAllAccountBalances();
});

class DashboardSummary {
  final int cashInHandPaise;
  final int bankBalancePaise;
  final int savingsLiabilityPaise;
  final int loanPrincipalReceivablePaise;
  final int interestReceivablePaise;
  final int interestIncomePaise;
  final int activeMembersCount;
  final int activeLoansCount;

  const DashboardSummary({
    required this.cashInHandPaise,
    required this.bankBalancePaise,
    required this.savingsLiabilityPaise,
    required this.loanPrincipalReceivablePaise,
    required this.interestReceivablePaise,
    required this.interestIncomePaise,
    required this.activeMembersCount,
    required this.activeLoansCount,
  });
}

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final engine = ref.watch(accountingEngineProvider);
  final memberRepo = ref.watch(memberRepositoryProvider);
  final loanRepo = ref.watch(loanRepositoryProvider);

  final balances = await engine.getAllAccountBalances();
  final activeMembers = await memberRepo.getMembers(activeOnly: true);
  final activeLoans = await loanRepo.getLoans(status: 'Active');
  final partiallyRepaidLoans = await loanRepo.getLoans(status: 'Partially Repaid');

  return DashboardSummary(
    cashInHandPaise: balances[AccountingEngine.codeCash] ?? 0,
    bankBalancePaise: balances[AccountingEngine.codeBank] ?? 0,
    savingsLiabilityPaise: balances[AccountingEngine.codeMemberSavingsLiability] ?? 0,
    loanPrincipalReceivablePaise: balances[AccountingEngine.codeLoanPrincipalReceivable] ?? 0,
    interestReceivablePaise: balances[AccountingEngine.codeInterestReceivable] ?? 0,
    interestIncomePaise: balances[AccountingEngine.codeInterestIncome] ?? 0,
    activeMembersCount: activeMembers.length,
    activeLoansCount: activeLoans.length + partiallyRepaidLoans.length,
  );
});

final memberSavingsBalanceProvider = FutureProvider.family<int, String>((ref, memberId) async {
  final engine = ref.watch(accountingEngineProvider);
  return engine.getMemberSavingsBalance(memberId);
});

final memberLoanPrincipalProvider = FutureProvider.family<int, String>((ref, memberId) async {
  final engine = ref.watch(accountingEngineProvider);
  return engine.getMemberLoanPrincipal(memberId);
});

final memberSavingsTransactionsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getSavingsTransactions(memberId: memberId);
});

final loanDetailProvider = FutureProvider.family<LoanDetailData?, String>((ref, loanId) async {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getLoanDetail(loanId);
});

final memberTransactionsProvider = FutureProvider.family<List<TransactionItem>, String>((ref, memberId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final all = await repo.getTransactions();
  return all.where((t) => t.memberId == memberId).toList();
});

final membersWithBalancesProvider = FutureProvider<List<MemberWithBalance>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  final filter = ref.watch(memberFilterProvider);
  return repo.getMembersWithBalances(
    activeOnly: filter.activeOnly,
    query: filter.searchQuery,
  );
});

/// Centralized invalidation helper across all financial mutations
void invalidateFinancialProviders(WidgetRef ref, {String? memberId, String? loanId}) {
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(membersListProvider);
  ref.invalidate(membersWithBalancesProvider);
  ref.invalidate(loansListProvider);
  ref.invalidate(transactionsListProvider);

  if (memberId != null) {
    ref.invalidate(memberDetailProvider(memberId));
    ref.invalidate(memberSavingsBalanceProvider(memberId));
    ref.invalidate(memberLoanPrincipalProvider(memberId));
    ref.invalidate(memberSavingsTransactionsProvider(memberId));
    ref.invalidate(memberTransactionsProvider(memberId));
  }

  if (loanId != null) {
    ref.invalidate(loanDetailProvider(loanId));
  }
}
