import 'package:flutter/material.dart';

/// Defines the app-wide Material 3 theme.
///
/// The seed colour [_seedColor] is a forest green (#31964B, RGB 49/150/75).
/// Material 3 generates the full light and dark colour schemes automatically
/// from this single value, ensuring all surfaces, containers, and text colours
/// are harmonious and accessible without manual specification.
class AppTheme {
  /// Forest green — the primary brand colour from which the full palette
  /// is derived by the Material 3 colour system.
  static const _seedColor = Color(0xFF31964B);

  /// Light theme: white/light-grey surfaces, green primary, dark-on-light text.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seedColor,
        brightness: Brightness.light,
      );

  /// Dark theme: dark-grey surfaces, lighter green primary, light-on-dark text.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seedColor,
        brightness: Brightness.dark,
      );
}
