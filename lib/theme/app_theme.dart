import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get dark {
    const foreground = Color(0xFFF7F0E4);
    const background = Color(0xFF141312);
    const surface = Color(0xFF221F1B);

    final baseText = GoogleFonts.spaceGroteskTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: foreground, height: 1.35),
        bodyMedium: TextStyle(color: foreground, height: 1.35),
        titleLarge: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelLarge: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE3B253),
        secondary: Color(0xFFD79A36),
        surface: surface,
        onPrimary: Color(0xFF1D1407),
        onSecondary: Color(0xFF1D1407),
        onSurface: foreground,
      ),
      textTheme: baseText,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
