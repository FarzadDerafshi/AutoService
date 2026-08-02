import '../../../core/api/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_user.dart';
import 'invite_model.dart';
import 'team_member_model.dart';

class TeamRepository {
  TeamRepository(this._client);
  final ApiClient _client;

  Future<List<TeamMember>> listMembers() async {
    final response = await _client.dio.get('/users');
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List).map((e) => TeamMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setMemberActive(String id, bool isActive) =>
      _client.dio.patch('/users/$id', data: {'isActive': isActive});

  Future<void> deleteMember(String id) => _client.dio.delete('/users/$id');

  Future<List<Invite>> listInvites() async {
    final response = await _client.dio.get('/invites');
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List).map((e) => Invite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Invite> createInvite({required String role, required int expiresInHours}) async {
    final response = await _client.dio.post('/invites', data: {
      'role': role,
      'expiresInHours': expiresInHours,
    });
    return Invite.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> revokeInvite(String id) => _client.dio.delete('/invites/$id');

  /// Public — reachable by someone with no account and no stored token yet.
  /// [ApiClient]'s auth interceptor only *adds* a header when a token is
  /// set, so this needs no special handling even if called from a session
  /// that happens to be logged in as someone else.
  Future<InvitePublicInfo> getInvitePublicInfo(String id) async {
    final response = await _client.dio.get('/invites/$id/public');
    return InvitePublicInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResult> joinViaInvite(
    String id, {
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post('/invites/$id/join', data: {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
    final body = response.data as Map<String, dynamic>;
    return LoginResult(
      token: body['token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }
}
