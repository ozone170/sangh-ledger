import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/financial_summary_card.dart';
import '../../core/ui/states.dart';
import '../../domain/entities/member.dart';
import '../../l10n/app_localizations.dart';
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
                _buildSavingsTab(context, l10n),
                _buildLoansTab(context, l10n),
                _buildTransactionsTab(context, l10n),
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
                    Text(
                      member.fullName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                ref.invalidate(memberDetailProvider(member.id));
                ref.invalidate(membersListProvider);
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

  Widget _buildSavingsTab(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FinancialSummaryCard(
          title: 'Total Savings Balance',
          amountPaise: 0,
          icon: Icons.savings_outlined,
          color: AppColors.financialTeal,
        ),
        const SizedBox(height: 16),
        const EmptyState(title: 'No savings transactions for this member'),
      ],
    );
  }

  Widget _buildLoansTab(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FinancialSummaryCard(
          title: 'Outstanding Loan Principal',
          amountPaise: 0,
          icon: Icons.account_balance_outlined,
          color: AppColors.errorCrimson,
        ),
        const SizedBox(height: 16),
        const EmptyState(title: 'No active loans for this member'),
      ],
    );
  }

  Widget _buildTransactionsTab(BuildContext context, AppLocalizations l10n) {
    return const EmptyState(
      title: 'No transactions recorded',
      subtitle: 'All deposits, withdrawals, loans and repayments will show here.',
    );
  }
}
