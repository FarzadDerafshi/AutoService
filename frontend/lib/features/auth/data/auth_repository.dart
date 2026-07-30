import '../../../core/api/api_client.dart';
import 'auth_user.dart';

class LoginResult {
  final String token;
  final AuthUser user;
  const LoginResult({required this.token, required this.user});
}

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<LoginResult> register({
    required String shopName,
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'shopName': shopName,
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

  Future<LoginResult> login({required String email, required String password}) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final body = response.data as Map<String, dynamic>;
    return LoginResult(
      token: body['token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthUser> me() async {
    final response = await _client.dio.get('/auth/me');
    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.dio.post('/auth/logout');
  }
}
