// Native implementation (Android, Windows, etc.) — compiled when
// dart.library.html is NOT present (i.e. non-web platforms).
// Uses flutter_secure_storage backed by the OS keystore / Credential Manager.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

Future<String?> storageRead(String key) => _storage.read(key: key);

Future<void> storageWrite(String key, String value) =>
    _storage.write(key: key, value: value);

Future<void> storageDelete(String key) => _storage.delete(key: key);
