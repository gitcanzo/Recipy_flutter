import 'package:flutter/material.dart';

/// Recipy brand palette — Mint / sage green direction.
///
/// All colours are defined as plain [Color] constants so they can be
/// referenced in both widget code and [ThemeData] without a [BuildContext].
///
/// Usage: `RecipyColors.accent` — no instance needed.
class RecipyColors {
  RecipyColors._(); // prevent instantiation

  /// Page / scaffold background — warm off-white.
  static const Color paper = Color(0xFFF4F6EE);

  /// Elevated surface background — slightly lighter than [paper].
  /// Used for icon tiles, input fills, and the AppBar.
  static const Color paperHi = Color(0xFFFBFCF4);

  /// Card surface — pure white, sits above [paper] with a soft shadow.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text — near-black with a green undertone.
  static const Color ink = Color(0xFF0F1F18);

  /// Secondary / supporting text — muted mid-green.
  static const Color inkSoft = Color(0xFF52685D);

  /// Dividers and border strokes — light sage.
  static const Color rule = Color(0xFFDEE5D2);

  /// Primary accent — the Recipy green used on buttons, the wordmark, and
  /// the chef hat icon.
  static const Color accent = Color(0xFF73A14A);

  /// Dark accent — hat band, subtitles, headings, and selected states.
  static const Color accent2 = Color(0xFF3C5B22);

  /// Sage tint — chip backgrounds and icon backdrop discs.
  static const Color soft = Color(0xFFE1ECCB);
}
