import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Provides the application's runtime configuration through Riverpod.
///
/// Why do we need a provider for configuration?
///
/// The AppConfig class contains configuration values such as the backend
/// API URL. Other parts of the application will need access to those values,
/// especially the networking layer.
///
/// Instead of creating AppConfig manually inside every class that needs it,
/// we register it with Riverpod once and allow dependent components to
/// request it.
///
/// This gives us a dependency chain such as:
///
///     AppConfig
///         ↓
///     API Client
///         ↓
///     Repositories
///         ↓
///     Features
///
/// It also makes these dependencies easier to replace in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  /// For now, every local development build uses the development
  /// configuration.
  ///
  /// Later, this provider can select between development, staging,
  /// and production configurations based on the application's build
  /// environment.
  return AppConfig.development;
});
