import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/app_config_provider.dart';
import 'auth_interceptor.dart';
import 'token_refresh_interceptor.dart';

/// Provides the single HTTP client used by feature repositories.
///
/// The client owns cross-cutting HTTP behavior:
/// - environment-specific base URL,
/// - timeouts,
/// - access-token attachment,
/// - expired-token recovery.
///
/// Feature repositories should never construct their own Dio instance for
/// ordinary API calls. The refresh interceptor has its own isolated client by
/// design so that refresh failures cannot recurse through authentication.
final apiClientProvider = Provider<Dio>((ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  ));

  /// Access-token attachment runs first, allowing normal requests to receive
  /// their credentials before they are dispatched.
  dio.interceptors.add(ref.watch(authInterceptorProvider));

  /// A 401 is then handled by the isolated refresh mechanism. Successful
  /// refreshes transparently retry the original request.
  dio.interceptors.add(ref.watch(tokenRefreshInterceptorProvider));

  return dio;
});
