import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/entities/member.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

class MemberListFilter {
  final bool? activeOnly;
  final String searchQuery;

  const MemberListFilter({this.activeOnly, this.searchQuery = ''});

  MemberListFilter copyWith({bool? activeOnly, String? searchQuery}) {
    return MemberListFilter(
      activeOnly: activeOnly ?? this.activeOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final memberFilterProvider = StateProvider<MemberListFilter>((ref) {
  return const MemberListFilter();
});

final membersListProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  final filter = ref.watch(memberFilterProvider);
  return repo.getMembers(
    activeOnly: filter.activeOnly,
    query: filter.searchQuery,
  );
});
