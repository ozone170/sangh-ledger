import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/inputs.dart';
import '../../core/ui/list_items.dart';
import '../../core/ui/states.dart';
import '../../l10n/app_localizations.dart';
import 'members_controller.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddMemberDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addMember),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: '${l10n.fullName} *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: '${l10n.phone} *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: '${l10n.address} *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final repo = ref.read(memberRepositoryProvider);
                  await repo.addMember(
                    fullName: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                  );
                  invalidateFinancialProviders(ref);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
                    );
                  }
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final membersAsync = ref.watch(membersWithBalancesProvider);
    final filter = ref.watch(memberFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.members} (Cap: 100)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(membersWithBalancesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addMember),
        onPressed: () => _showAddMemberDialog(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchField(
              controller: _searchController,
              hint: 'Search members by name, SGH code or phone...',
              onChanged: (val) {
                ref.read(memberFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: val);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter.activeOnly == null,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(memberFilterProvider.notifier).state =
                          MemberListFilter(searchQuery: filter.searchQuery);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.activeMembers),
                  selected: filter.activeOnly == true,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(memberFilterProvider.notifier).state =
                          filter.copyWith(activeOnly: true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.inactiveMembers),
                  selected: filter.activeOnly == false,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(memberFilterProvider.notifier).state =
                          filter.copyWith(activeOnly: false);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: membersAsync.when(
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(membersWithBalancesProvider),
              ),
              data: (membersList) {
                if (membersList.isEmpty) {
                  return EmptyState(
                    title: 'No Members Found',
                    subtitle: 'Add a new member to begin transactions.',
                    actionText: l10n.addMember,
                    onAction: () => _showAddMemberDialog(context),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: membersList.length,
                  itemBuilder: (context, index) {
                    final item = membersList[index];
                    final member = item.member;
                    return MemberListItem(
                      memberCode: member.memberCode,
                      name: member.fullName,
                      phone: member.phone,
                      savingsBalancePaise: item.savingsBalancePaise,
                      loanBalancePaise: item.loanPrincipalPaise,
                      isActive: member.isActive,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.memberDetail,
                          arguments: member.id,
                        );
                      },
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
