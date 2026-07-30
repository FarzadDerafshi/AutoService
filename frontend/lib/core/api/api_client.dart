import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_exception.dart';

/// Base URL for the AutoService API. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
/// (10.0.2.2 is how the Android emulator reaches the host machine's localhost.)
const String _dartDefineBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

/// On web builds the app is always served through nginx, which already proxies
/// /api/ → the backend container. Using the page's own origin avoids any CORS
/// preflight — the request is same-origin from the browser's perspective.
/// On native (Android / Windows) we fall back to the dart-define value.
String get apiBaseUrl {
  if (kIsWeb) {
    return '${Uri.base.origin}/api/v1';
  }
  return _dartDefineBaseUrl;
}

/// Thin wrapper around Dio that attaches the current JWT (if any) to every
/// request and normalizes errors into [ApiException]. The token is injected
/// by whoever owns auth state (see auth_provider.dart) via [setToken]/[clearToken]
/// so this client has no direct dependency on Riverpod.
class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(_normalize(error));
        },
      ),
    );
  }

  final Dio dio;
  String? _token;

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  DioException _normalize(DioException error) {
    final response = error.response;
    if (response?.data is Map<String, dynamic>) {
      final body = response!.data as Map<String, dynamic>;
      final message = body['error'] as String? ?? error.message ?? 'Request failed';
      final fields = body['fields'] as Map<String, dynamic>?;
      return error.copyWith(
        error: ApiException(message, statusCode: response.statusCode, fieldErrors: fields),
      );
    }
    return error.copyWith(
      error: ApiException(error.message ?? 'Network error', statusCode: response?.statusCode),
    );
  }
}

/// Unwraps a DioException's normalized ApiException, or rethrows as-is.
ApiException toApiException(Object error) {
  if (error is DioException && error.error is ApiException) {
    return error.error as ApiException;
  }
  if (error is ApiException) return error;
  return ApiException(error.toString());
}
