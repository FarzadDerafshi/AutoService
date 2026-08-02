import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/invite_model.dart';
import '../data/team_member_model.dart';
import '../data/team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(apiClientProvider));
});

final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) async {
  return ref.watch(teamRepositoryProvider).listMembers();
});

final teamInvitesProvider = FutureProvider.autoDispose<List<Invite>>((ref) async {
  return ref.watch(teamRepositoryProvider).listInvites();
});
