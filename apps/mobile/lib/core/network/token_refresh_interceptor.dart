import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import '../storage/secure_storage.dart';

final tokenRefreshInterceptorProvider =
    Provider<TokenRefreshInterceptor>((ref) {
  final config = ref.watch(appConfigProvider);
  return TokenRefreshInterceptor(
    secureStorage: ref.watch(secureStorageProvider),
    refreshClient: Dio(BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    )),
  );
});

/// Recovers expired access tokens without allowing refresh storms.
///
/// A dedicated Dio client is used for the refresh call. It has no
/// authentication or refresh interceptors, so a failed refresh cannot recurse
/// back into this interceptor.
class TokenRefreshInterceptor extends QueuedInterceptor {
  TokenRefreshInterceptor({
    required this.secureStorage,
    required this.refreshClient,
  });

  final SecureStorage secureStorage;
  final Dio refreshClient;

  /// Shared in-flight refresh operation.
  ///
  /// If several requests fail with 401 together, they all await this same
  /// Future instead of rotating the refresh token independently.
  Future<void>? _refreshFuture;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;

    /// Only an expired/invalid access credential should enter refresh logic.
    /// A request is retried at most once to prevent infinite loops.
    if (statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      await _refreshOnce();
      final accessToken = await secureStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        handler.next(err);
        return;
      }

      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.extra['authRetried'] = true;

      final response = await dioFetch(refreshClient, request);
      handler.resolve(response);
    } on Object {
      /// The refresh token is no longer usable. Clear credentials so the
      /// session layer can return the application to an unauthenticated state.
      await secureStorage.clearTokens();
      handler.next(err);
    }
  }

  Future<void> _refreshOnce() async {
    final existing = _refreshFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _performRefresh();
    _refreshFuture = future;

    try {
      await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<void> _performRefresh() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token is available.');
    }

    final response = await refreshClient.post<Map<String, dynamic>>(
      '/auth/refresh',
      options: Options(
        headers: {'Authorization': 'Bearer $refreshToken'},
      ),
    );

    final data = response.data;
    final accessToken = data?['access_token'];
    final newRefreshToken = data?['refresh_token'];

    if (accessToken is! String || newRefreshToken is! String) {
      throw const FormatException('Invalid token refresh response.');
    }

    await secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );
  }
}

/// Calls Dio's low-level fetch operation through the original client.
///
/// The helper is kept outside the interceptor so the retry path remains
/// explicit. The original request's method, URI, headers, body, and options
/// are preserved.
Future<Response<dynamic>> dioFetch(Dio client, RequestOptions request) {
  return client.fetch<dynamic>(request);
}
