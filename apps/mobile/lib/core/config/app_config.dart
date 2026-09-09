/// Application-wide configuration.
///
/// This class holds values that can change depending on the environment
/// in which the application is running.
///
/// Examples of environments we will eventually support:
/// - Development: our local development machine
/// - Staging: a server used for testing before production
/// - Production: the real application used by customers
///
/// Keeping configuration in one place prevents values such as API URLs
/// from being hard-coded throughout the application.
class AppConfig {
  /// Creates an application configuration.
  ///
  /// [apiBaseUrl] is the root URL that the Flutter application will use
  /// when communicating with the FastAPI backend.
  const AppConfig({required this.apiBaseUrl});

  /// Base URL of the backend API.
  ///
  /// Individual API calls will eventually append their endpoint to this
  /// value. For example:
  ///
  ///     GET /providers
  ///
  /// will ultimately be sent to:
  ///
  ///     <apiBaseUrl>/providers
  ///
  /// Keeping the base URL separate means that changing environments does
  /// not require changing every API request in the application.
  final String apiBaseUrl;

  /// Configuration used when running the application locally.
  ///
  /// Android emulators have a special address, `10.0.2.2`, that maps back
  /// to the host computer's localhost.
  ///
  /// Therefore, if Mage's FastAPI server is running on our computer at:
  ///
  ///     http://localhost:8000
  ///
  /// the Android emulator reaches that same server through:
  ///
  ///     http://10.0.2.2:8000
  ///
  /// This is specifically useful for our local Android development setup.
  ///
  /// Later, we can add separate configurations for staging and production
  /// without changing the rest of the application architecture.
  static const development = AppConfig(apiBaseUrl: 'http://10.0.2.2:8000');
}
