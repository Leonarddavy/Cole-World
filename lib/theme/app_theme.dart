import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontChoice {
  const FontChoice({required this.key, required this.label});

  final String key;
  final String label;
}

class AppThemeSettings {
  const AppThemeSettings({
    this.primaryColorValue = 0xFFFFB547,
    this.secondaryColorValue = 0xFF2EE6D6,
    this.backgroundColorValue = 0xFF0C0B0A,
    this.displayFontKey = 'rubik_wet_paint',
    this.bodyFontKey = 'permanent_marker',
  });

  final int primaryColorValue;
  final int secondaryColorValue;
  final int backgroundColorValue;
  final String displayFontKey;
  final String bodyFontKey;

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);
  Color get backgroundColor => Color(backgroundColorValue);

  AppThemeSettings copyWith({
    int? primaryColorValue,
    int? secondaryColorValue,
    int? backgroundColorValue,
    String? displayFontKey,
    String? bodyFontKey,
  }) {
    return AppThemeSettings(
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      displayFontKey: displayFontKey ?? this.displayFontKey,
      bodyFontKey: bodyFontKey ?? this.bodyFontKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColorValue': primaryColorValue,
      'secondaryColorValue': secondaryColorValue,
      'backgroundColorValue': backgroundColorValue,
      'displayFontKey': displayFontKey,
      'bodyFontKey': bodyFontKey,
    };
  }

  static AppThemeSettings fromJson(Object? raw) {
    if (raw is! Map) {
      return const AppThemeSettings();
    }
    final json = Map<String, dynamic>.from(raw);
    return AppThemeSettings(
      primaryColorValue: _parseInt(json['primaryColorValue'], 0xFFFFB547),
      secondaryColorValue: _parseInt(json['secondaryColorValue'], 0xFF2EE6D6),
      backgroundColorValue: _parseInt(json['backgroundColorValue'], 0xFF0C0B0A),
      displayFontKey: (json['displayFontKey'] ?? 'rubik_wet_paint')
          .toString()
          .trim(),
      bodyFontKey: (json['bodyFontKey'] ?? 'permanent_marker')
          .toString()
          .trim(),
    );
  }

  static int _parseInt(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}

class AppTheme {
  static const List<FontChoice> displayFontChoices = [
    FontChoice(key: 'rubik_wet_paint', label: 'Rubik Wet Paint'),
    FontChoice(key: 'bangers', label: 'Bangers'),
    FontChoice(key: 'black_ops_one', label: 'Black Ops One'),
    FontChoice(key: 'oswald', label: 'Oswald'),
    FontChoice(key: 'teko', label: 'Teko'),
  ];

  static const List<FontChoice> bodyFontChoices = [
    FontChoice(key: 'permanent_marker', label: 'Permanent Marker'),
    FontChoice(key: 'montserrat', label: 'Montserrat'),
    FontChoice(key: 'lato', label: 'Lato'),
    FontChoice(key: 'nunito_sans', label: 'Nunito Sans'),
    FontChoice(key: 'open_sans', label: 'Open Sans'),
  ];

  static ThemeData dark({
    AppThemeSettings settings = const AppThemeSettings(),
  }) {
    const foreground = Color(0xFFF6F1E8);
    final background = settings.backgroundColor;
    final surface = _shiftLightness(background, 0.055);
    final surfaceAlt = _shiftLightness(background, 0.095);
    final primary = settings.primaryColor;
    final secondary = settings.secondaryColor;
    const tertiary = Color(0xFFB4FF5C);
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B1209);
    final onSecondary =
        ThemeData.estimateBrightnessForColor(secondary) == Brightness.dark
        ? Colors.white
        : const Color(0xFF071C1A);

    TextStyle displayStyle(double size, {Color? color}) {
      return _displayStyle(
        settings.displayFontKey,
        textStyle: const TextStyle(inherit: false),
      ).copyWith(
        fontSize: size,
        color: color ?? foreground,
        letterSpacing: 0.9,
        height: 1.0,
      );
    }

    final baseText = _applyBodyFont(
      settings.bodyFontKey,
      ThemeData.dark().textTheme,
    ).apply(bodyColor: foreground, displayColor: foreground);

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
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _shiftLightness(background, 0.1),
        contentTextStyle: const TextStyle(color: foreground),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: displayStyle(26),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _shiftLightness(background, 0.11),
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _shiftLightness(background, 0.08),
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
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _shiftLightness(background, 0.09),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _applyBodyFont(String fontKey, TextTheme base) {
    switch (fontKey) {
      case 'montserrat':
        return GoogleFonts.montserratTextTheme(base);
      case 'lato':
        return GoogleFonts.latoTextTheme(base);
      case 'nunito_sans':
        return GoogleFonts.nunitoSansTextTheme(base);
      case 'open_sans':
        return GoogleFonts.openSansTextTheme(base);
      case 'permanent_marker':
      default:
        return GoogleFonts.permanentMarkerTextTheme(base);
    }
  }

  static TextStyle _displayStyle(String fontKey, {TextStyle? textStyle}) {
    switch (fontKey) {
      case 'bangers':
        return GoogleFonts.bangers(textStyle: textStyle);
      case 'black_ops_one':
        return GoogleFonts.blackOpsOne(textStyle: textStyle);
      case 'oswald':
        return GoogleFonts.oswald(textStyle: textStyle);
      case 'teko':
        return GoogleFonts.teko(textStyle: textStyle);
      case 'rubik_wet_paint':
      default:
        return GoogleFonts.rubikWetPaint(textStyle: textStyle);
    }
  }

  static Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + delta).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(lightness).toColor();
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
