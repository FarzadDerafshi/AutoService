// Selects the right storage backend at compile time:
//   • Web   → _storage_web.dart  (window.localStorage via dart:html)
//   • Native → _storage_stub.dart (flutter_secure_storage / OS keystore)
//
// We do NOT use shared_preferences on web because it requires a Flutter
// plugin channel that is unavailable in the web runtime on some browsers
// (throws MissingPluginException).  dart:html is a built-in Dart web library
// — no plugin registration required, works over plain HTTP on any device.
import '_storage_stub.dart' if (dart.library.html) '_storage_web.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';

  Future<String?> readToken() => storageRead(_tokenKey);
  Future<void> saveToken(String token) => storageWrite(_tokenKey, token);
  Future<void> clearToken() => storageDelete(_tokenKey);
}
