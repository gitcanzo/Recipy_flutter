import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'recipy_colors.dart';

/// Defines the app-wide Material 3 theme for Recipy.
///
/// Design choices:
/// - Colour palette is sourced from [RecipyColors] (sage-mint direction).
/// - Typography uses Geist (body/UI) from Google Fonts, as specified in BRAND.md.
/// - [CardTheme] uses a slightly elevated tonal surface so cards pop without
///   heavy shadows on white backgrounds.
/// - [AppBarTheme] pins a transparent/surface-tinted bar with a larger title.
/// - [ChipTheme] reduces padding so tag chips read as labels, not buttons.
class AppTheme {
  /// Light theme — uses [RecipyColors] palette seeded from [RecipyColors.accent].
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: RecipyColors.accent,
      brightness: Brightness.light,
    );
    // Apply Geist as the base font for all text styles, then layer our
    // custom overrides on top.
    final geistBase = base.copyWith(
      textTheme: GoogleFonts.geistTextTheme(base.textTheme).apply(
        bodyColor: RecipyColors.ink,
        displayColor: RecipyColors.ink,
      ),
    );
    return geistBase.copyWith(
      scaffoldBackgroundColor: RecipyColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RecipyColors.accent,
        primary: RecipyColors.accent,
        onPrimary: RecipyColors.paperHi,
        secondary: RecipyColors.accent2,
        surface: RecipyColors.surface,
        onSurface: RecipyColors.ink,
        outline: RecipyColors.rule,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme(geistBase.textTheme),
      appBarTheme: _appBarTheme(geistBase),
      cardTheme: _cardTheme(geistBase),
      chipTheme: _chipTheme(geistBase),
      dividerColor: RecipyColors.rule,
      // Pill-shaped elevated buttons — accent green fill, paper-tinted text.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RecipyColors.accent,
          foregroundColor: RecipyColors.paperHi,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      // FAB matches the accent button style, fully circular.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RecipyColors.accent,
        foregroundColor: RecipyColors.paperHi,
        shape: CircleBorder(),
      ),
      // Input fields use the elevated paper surface as fill.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RecipyColors.paperHi,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
          color: RecipyColors.inkSoft.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Dark theme — uses the same seed colour with dark brightness.
  ///
  /// Geist font and structural theme settings match [light]; colours are
  /// derived automatically by [ColorScheme.fromSeed] in dark mode.
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: RecipyColors.accent,
      brightness: Brightness.dark,
    );
    final geistBase = base.copyWith(
      textTheme: GoogleFonts.geistTextTheme(base.textTheme),
    );
    return geistBase.copyWith(
      textTheme: _textTheme(geistBase.textTheme),
      appBarTheme: _appBarTheme(geistBase),
      cardTheme: _cardTheme(geistBase),
      chipTheme: _chipTheme(geistBase),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-theme builders
  // ---------------------------------------------------------------------------

  /// Applies Recipy-specific type scale overrides on top of the Geist base.
  ///
  /// - [titleLarge]: recipe titles — 28 px, medium weight, tight leading.
  /// - [labelSmall]: section eyebrows — spaced caps in accent green (BRAND.md §6).
  /// - [bodyMedium] / [bodySmall]: general body copy with comfortable line-height.
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
        displaySmall: base.displaySmall?.copyWith(
          letterSpacing: -0.5,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          letterSpacing: -0.3,
          fontWeight: FontWeight.w700,
        ),
        // Used for recipe titles on the detail screen.
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: RecipyColors.ink,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        // Eyebrow labels above card sections (e.g. "INGREDIENTS", "METHOD").
        // Wide letter-spacing and accent colour per BRAND.md §6.
        labelSmall: base.labelSmall?.copyWith(
          fontSize: 10.5,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
          color: RecipyColors.accent,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.5,
          color: RecipyColors.ink,
        ),
        bodySmall: base.bodySmall?.copyWith(
          fontSize: 11,
          color: RecipyColors.inkSoft,
        ),
      );

  /// AppBar with paper background, zero resting elevation.
  ///
  /// Uses [RecipyColors.paper] so the bar blends with the scaffold background
  /// on screens that don't have a hero image behind the app bar.
  static AppBarTheme _appBarTheme(ThemeData base) => AppBarTheme(
        backgroundColor: RecipyColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: RecipyColors.accent,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: RecipyColors.ink),
      );

  /// Cards with a gentle shadow and rounded 16 px corners.  [clipBehavior] is
  /// set to [Clip.antiAlias] so child images respect the border radius without
  /// needing an extra ClipRRect wrapper in every card widget.
  static CardThemeData _cardTheme(ThemeData base) => CardThemeData(
        color: RecipyColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      );

  /// Compact chips so tag lists read as labels rather than interactive buttons.
  static ChipThemeData _chipTheme(ThemeData base) => ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: base.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        backgroundColor: RecipyColors.soft,
      );
}
