import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

/// Provides the authentication interceptor.
///
/// The interceptor is responsible only for attaching the persisted access
/// token to normal API requests.
///
/// Token refresh is intentionally handled by a separate interceptor so that
/// each component has one clear responsibility.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(secureStorage: ref.watch(secureStorageProvider));
});

/// Adds the current access token to outgoing API requests.
///
/// Normal authenticated requests become:
///
///     Authorization: Bearer <access-token>
///
/// An important exception exists:
///
/// If a request already contains an Authorization header, this interceptor
/// leaves it untouched.
///
/// That exception is required for authentication operations such as
/// `/auth/refresh` and `/auth/logout`, where the backend expects the
/// **refresh token** rather than the access token.
class AuthInterceptor extends Interceptor {
  /// Creates an authentication interceptor.
  ///
  /// SecureStorage is injected so the interceptor can retrieve the current
  /// access token without knowing how or where credentials are persisted.
  AuthInterceptor({required this.secureStorage});

  /// Secure storage containing the persisted authentication credentials.
  final SecureStorage secureStorage;

  /// Runs before Dio sends a request to the backend.
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    /// Do not overwrite an Authorization header that another part of the
    /// application deliberately supplied.
    ///
    /// This is particularly important for:
    ///
    ///     POST /auth/refresh
    ///     POST /auth/logout
    ///
    /// because those endpoints use the refresh token.
    if (options.headers['Authorization'] != null) {
      handler.next(options);
      return;
    }

    /// Retrieve the current access token from secure storage.
    final accessToken = await secureStorage.getAccessToken();

    /// Only attach the header when an access token actually exists.
    ///
    /// Login and registration requests are intentionally allowed to proceed
    /// without authentication credentials.
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    /// Continue the request lifecycle.
    handler.next(options);
  }
}
