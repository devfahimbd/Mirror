/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * App Theme: High-end Cyber-Minimalist Dark Theme with Glowing Orange Accents.
 */

import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF090A0E);
  static const Color surface = Color(0xFF13151D);
  static const Color surfaceElevated = Color(0xFF1B1E2B);
  static const Color surfaceGlass = Color(0xCC13151D);
  static const Color border = Color(0xFF262A38);

  // Brand Orange Gradients (matching logo)
  static const Color primary = Color(0xFFFF6D00);
  static const Color secondary = Color(0xFFFF9100);
  static const Color accent = Color(0xFFFFAB40);

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF161822), Color(0xFF11131A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}

