import 'package:flutter/material.dart';

/// Central definition of the application's visual theme.
///
/// The theme is kept separate from individual screens so that the entire
/// application follows one consistent design system.
///
/// This class currently provides:
/// - Light theme
/// - Dark theme
///
/// Later, we can expand the design system with:
/// - Typography
/// - Button styles
/// - Text-field styles
/// - Card styles
/// - Navigation styles
/// - Dialog styles
/// - Other reusable Material component configurations
///
/// Keeping these decisions centralized prevents individual screens from
/// developing inconsistent visual styles.
class AppTheme {
  /// Private constructor.
  ///
  /// AppTheme only exposes static theme factories, so there is no reason
  /// for the application to create an AppTheme instance.
  const AppTheme._();

  /// The primary brand color used to generate the light color scheme.
  ///
  /// We use a single seed color with Material 3's ColorScheme.fromSeed()
  /// rather than manually defining dozens of related colors.
  ///
  /// This is an initial product color, not a permanent branding decision.
  /// We can refine the visual identity later without changing the theme
  /// architecture.
  static const Color _seedColor = Color(0xFF2563EB);

  /// Creates the application's light theme.
  ///
  /// This is intended for users who prefer a light interface or when the
  /// application is explicitly configured to use light mode.
  static ThemeData light() {
    return ThemeData(
      /// Enables Google's current Material 3 design system.
      ///
      /// This provides the modern Material component behavior used by
      /// Flutter for buttons, navigation, text fields, dialogs, etc.
      useMaterial3: true,

      /// Generates a complete semantic color palette from our brand seed.
      ///
      /// Screens should use semantic theme colors such as:
      ///
      ///     Theme.of(context).colorScheme.primary
      ///
      /// instead of hard-coding colors themselves.
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),

      /// Default background used by Scaffold widgets.
      ///
      /// A very light neutral gives the application a slightly softer
      /// appearance than pure white while remaining suitable for a
      /// professional SaaS interface.
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),

      /// Uses standard Material component density.
      ///
      /// This provides comfortable touch targets for a mobile-first
      /// application.
      visualDensity: VisualDensity.standard,
    );
  }

  /// Creates the application's dark theme.
  ///
  /// Dark mode is generated from the same brand seed color as the light
  /// theme. This keeps the application's visual identity consistent while
  /// allowing Material 3 to produce an appropriate dark color palette.
  static ThemeData dark() {
    return ThemeData(
      /// Keep Material 3 enabled in dark mode so both themes use the same
      /// component system and design language.
      useMaterial3: true,

      /// Generate the dark semantic color palette from the same brand color.
      ///
      /// Material adjusts the resulting tones for dark surfaces and
      /// appropriate contrast.
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),

      /// Default background for dark-mode Scaffold widgets.
      ///
      /// We let the dark ColorScheme establish the overall dark surface
      /// hierarchy rather than forcing every screen to specify its own
      /// background color.
      scaffoldBackgroundColor: const Color(0xFF0F172A),

      /// Keep component density consistent between light and dark modes.
      visualDensity: VisualDensity.standard,
    );
  }
}
