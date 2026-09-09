import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking_app/core/storage/secure_storage.dart';
import 'package:booking_app/features/auth/data/auth_repository.dart';
import 'package:booking_app/features/auth/presentation/auth_screens.dart';
import 'package:booking_app/main.dart';

/// In-memory stand-in for SecureStorage.
///
/// The smoke test must not touch real platform channels (the plugin is not
/// registered in the test environment), so every operation is a no-op and no
/// credentials are ever returned.
class _FakeSecureStorage implements SecureStorage {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String token) async {}

  @override
  Future<void> saveRefreshToken(String token) async {}

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

/// Basic smoke test for the root application.
///
/// This test verifies that the application's root widget can be constructed
/// and rendered, that the session is restored, and that the router redirects
/// unauthenticated users to the login screen.
///
/// It is intentionally small at this stage. As we build authentication,
/// navigation, marketplace, and booking functionality, we'll add focused
/// tests for those features separately.
void main() {
  testWidgets('BookingApp renders and redirects to login', (
    WidgetTester tester,
  ) async {
    /// Build the application inside a ProviderScope with the repository
    /// overridden to use fake storage instead of platform channels.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(dio: Dio(), secureStorage: _FakeSecureStorage()),
          ),
        ],
        child: const BookingApp(),
      ),
    );

    /// Allow the session-restore microtask to complete and the router to
    /// redirect unauthenticated users away from the splash screen.
    await tester.pump();
    await tester.pump();

    /// The session starts without credentials, so the router must have
    /// redirected to the login screen.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
