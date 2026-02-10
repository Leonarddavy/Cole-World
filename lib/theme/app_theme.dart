import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get dark {
    const foreground = Color(0xFFF6F1E8);
    const background = Color(0xFF0C0B0A);
    const surface = Color(0xFF161310);
    const surfaceAlt = Color(0xFF221B16);
    const primary = Color(0xFFFFB547);
    const secondary = Color(0xFF2EE6D6);
    const tertiary = Color(0xFFB4FF5C);

    TextStyle displayStyle(double size, {Color? color}) {
      return GoogleFonts.rubikWetPaint(
        textStyle: const TextStyle(inherit: false),
        fontSize: size,
        color: color ?? foreground,
        letterSpacing: 0.9,
        height: 1.0,
      );
    }

    final baseText = GoogleFonts.permanentMarkerTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    final tunedText = baseText.copyWith(
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
      bodySmall: baseText.bodySmall?.copyWith(
        color: const Color(0xFFCEC7BC),
        height: 1.3,
      ),
    );

    final textTheme = tunedText.copyWith(
      displayLarge: displayStyle(54),
      headlineLarge: displayStyle(38),
      headlineMedium: displayStyle(30),
      headlineSmall: displayStyle(24),
      titleLarge: tunedText.titleLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      titleMedium: tunedText.titleMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelLarge: tunedText.labelLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _GraffitiPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: Color(0xFF1B1209),
        onSecondary: Color(0xFF071C1A),
        onSurface: foreground,
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: displayStyle(26),
      ),
      cardTheme: CardThemeData(
        color: surfaceAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF241B12),
        contentTextStyle: TextStyle(color: foreground),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: displayStyle(26),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF241C14),
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF1B1209),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1612),
        hintStyle: const TextStyle(color: Color(0xFF9B9288)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF251D15),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

class _GraffitiPageTransitionsBuilder extends PageTransitionsBuilder {
  const _GraffitiPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
