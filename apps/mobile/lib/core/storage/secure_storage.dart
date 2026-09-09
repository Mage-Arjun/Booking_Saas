import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys used to identify values stored in secure storage.
///
/// Keeping storage keys centralized prevents subtle bugs caused by different
/// parts of the application using different strings for the same credential.
///
/// These values are implementation details of the Flutter client. They do
/// not need to match any variable names used by the FastAPI backend.
abstract final class SecureStorageKeys {
  /// Key under which the current access token is stored.
  static const String accessToken = 'access_token';

  /// Key under which the current refresh token is stored.
  static const String refreshToken = 'refresh_token';
}

/// Provides the application's secure storage service.
///
/// A Riverpod provider gives the rest of the application a single
/// dependency instead of creating FlutterSecureStorage instances throughout
/// feature code.
///
/// Authentication will eventually depend on this provider.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Application wrapper around FlutterSecureStorage.
///
/// Feature code should depend on this class rather than directly depending
/// on the third-party FlutterSecureStorage package.
///
/// This creates an architectural boundary:
///
///     Authentication
///          │
///          ▼
///     SecureStorage
///          │
///          ▼
///     FlutterSecureStorage
///
/// If we ever need to change the underlying storage implementation, the
/// authentication layer does not need to know about that change.
class SecureStorage {
  /// Creates the secure storage service.
  ///
  /// FlutterSecureStorage handles platform-specific secure storage
  /// underneath, using the appropriate mechanism for each supported platform.
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// The underlying platform-secure storage implementation.
  ///
  /// It is kept private so callers interact only with the methods exposed by
  /// this application-level abstraction.
  final FlutterSecureStorage _storage;

  /// Stores the access token securely.
  ///
  /// The access token is sensitive authentication material, so it should not
  /// be placed in ordinary preferences or written to application logs.
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: SecureStorageKeys.accessToken, value: token);
  }

  /// Retrieves the currently stored access token.
  ///
  /// Returns null when no access token has been stored.
  Future<String?> getAccessToken() {
    return _storage.read(key: SecureStorageKeys.accessToken);
  }

  /// Stores the refresh token securely.
  ///
  /// The refresh token has a longer lifetime than the access token and is
  /// therefore particularly sensitive.
  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: SecureStorageKeys.refreshToken, value: token);
  }

  /// Retrieves the currently stored refresh token.
  ///
  /// Returns null when the application has no persisted refresh token.
  Future<String?> getRefreshToken() {
    return _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Stores both authentication tokens as one operation.
  ///
  /// Keeping this operation together makes it harder for authentication code
  /// to accidentally persist only half of a newly issued token pair.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  /// Removes both authentication tokens.
  ///
  /// This is used when the user logs out or when the application determines
  /// that the persisted session is no longer valid.
  Future<void> clearTokens() async {
    await _storage.delete(key: SecureStorageKeys.accessToken);
    await _storage.delete(key: SecureStorageKeys.refreshToken);
  }
}
