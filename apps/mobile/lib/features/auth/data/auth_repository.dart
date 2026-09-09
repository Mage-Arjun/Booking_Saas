import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import 'models/auth_tokens.dart';
import 'models/user.dart';

/// Provides the authentication repository to the application.
///
/// The repository is the data-access boundary for authentication.
///
/// UI code should not need to know:
/// - which API endpoint is used,
/// - how tokens are stored,
/// - how authentication responses are decoded.
///
/// Those responsibilities belong here.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// Handles communication between the Flutter application and the
/// authentication API.
///
/// This class deliberately contains no UI concerns.
///
/// Its responsibilities are:
/// - communicate with authentication endpoints,
/// - persist authentication tokens,
/// - retrieve the current authenticated user,
/// - clear persisted credentials when logging out.
class AuthRepository {
  /// Creates an authentication repository.
  ///
  /// Dependencies are injected rather than constructed internally.
  /// This keeps the repository testable and prevents it from being coupled
  /// to a particular HTTP client or storage implementation.
  const AuthRepository({required this.dio, required this.secureStorage});

  /// HTTP client used to communicate with the backend.
  final Dio dio;

  /// Secure storage used for access and refresh tokens.
  final SecureStorage secureStorage;

  /// Registers a new user.
  ///
  /// The backend accepts:
  /// - email
  /// - password
  /// - role
  ///
  /// The backend returns an authentication token pair.
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {'email': email, 'password': password, 'role': role},
    );

    final tokens = AuthTokens.fromJson(response.data!);

    await secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  /// Logs an existing user in.
  ///
  /// Successful authentication returns a new access/refresh token pair.
  ///
  /// The tokens are immediately persisted in secure storage so subsequent
  /// API requests can authenticate without requiring the user to log in again.
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );

    final tokens = AuthTokens.fromJson(response.data!);

    await secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  /// Retrieves the currently authenticated user.
  ///
  /// AuthInterceptor automatically adds the access token to this request.
  Future<User> getCurrentUser() async {
    final response = await dio.get<Map<String, dynamic>>(ApiEndpoints.me);

    return User.fromJson(response.data!);
  }

  /// Refreshes the authentication token pair.
  ///
  /// IMPORTANT:
  /// Mage's backend expects the refresh token in the Authorization header:
  ///
  ///     Authorization: Bearer <refresh-token>
  ///
  /// It does NOT expect:
  ///
  ///     {"refresh_token": "..."}
  ///
  /// We explicitly provide the header here because the normal
  /// AuthInterceptor is responsible for attaching the access token.
  Future<AuthTokens> refreshTokens() async {
    final refreshToken = await secureStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token is available.');
    }

    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.refresh,
      options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
    );

    final tokens = AuthTokens.fromJson(response.data!);

    await secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  /// Logs the current user out.
  ///
  /// The backend revokes the refresh token identified by its JWT ID.
  ///
  /// Therefore the refresh token must be sent using:
  ///
  ///     Authorization: Bearer <refresh-token>
  ///
  /// After the server accepts the logout request, locally persisted
  /// credentials are removed as well.
  Future<void> logout() async {
    final refreshToken = await secureStorage.getRefreshToken();

    /// If there is no refresh token, there is nothing meaningful to send
    /// to the backend. Clearing local storage still ensures that stale
    /// credentials cannot remain on the device.
    if (refreshToken == null || refreshToken.isEmpty) {
      await secureStorage.clearTokens();
      return;
    }

    try {
      await dio.post<void>(
        ApiEndpoints.logout,
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );
    } finally {
      /// Local credentials are cleared even if the network request fails.
      ///
      /// This prevents the application from leaving the user appearing
      /// logged in after they explicitly requested logout.
      await secureStorage.clearTokens();
    }
  }
}
