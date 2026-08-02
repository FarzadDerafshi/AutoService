import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthState {
  final String token;
  final AuthUser user;
  const AuthState({required this.token, required this.user});
}

class AuthController extends AsyncNotifier<AuthState?> {
  @override
  Future<AuthState?> build() async {
    final client = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null) return null;

    client.setToken(token);
    try {
      final user = await ref.read(authRepositoryProvider).me();
      return AuthState(token: token, user: user);
    } on ApiException {
      // Stored token is expired/invalid — clear it and fall back to logged-out.
      await storage.clearToken();
      client.clearToken();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(authRepositoryProvider).login(email: email, password: password);
      await _persist(result);
      return AuthState(token: result.token, user: result.user);
    });
  }

  Future<void> register({
    required String shopName,
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(authRepositoryProvider).register(
            shopName: shopName,
            fullName: fullName,
            email: email,
            password: password,
          );
      await _persist(result);
      return AuthState(token: result.token, user: result.user);
    });
  }

  Future<void> updateProfile({required String fullName}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).updateProfile(fullName: fullName);
      return AuthState(token: current.token, user: user);
    });
  }

  /// Doesn't touch [state] — the caller (a dialog) handles its own loading/error
  /// UI directly and neither the token nor the displayed user changes on success.
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  Future<void> logout() async {
    final client = ref.read(apiClientProvider);
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // stateless JWT — logout is best-effort; always clear local state.
    }
    await ref.read(tokenStorageProvider).clearToken();
    client.clearToken();
    state = const AsyncData(null);
  }

  Future<void> _persist(LoginResult result) async {
    await ref.read(tokenStorageProvider).saveToken(result.token);
    ref.read(apiClientProvider).setToken(result.token);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState?>(AuthController.new);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).valueOrNull != null;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull?.user;
});
