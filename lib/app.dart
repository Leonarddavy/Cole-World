import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'pages/splash_catalog_page.dart';
import 'theme/app_theme.dart';

class JColeVaultApp extends StatefulWidget {
  const JColeVaultApp({super.key});

  @override
  State<JColeVaultApp> createState() => _JColeVaultAppState();
}

class _JColeVaultAppState extends State<JColeVaultApp> {
  AppThemeSettings _themeSettings = const AppThemeSettings();

  void _onThemeSettingsChanged(AppThemeSettings next) {
    final hasChanged =
        _themeSettings.primaryColorValue != next.primaryColorValue ||
        _themeSettings.secondaryColorValue != next.secondaryColorValue ||
        _themeSettings.backgroundColorValue != next.backgroundColorValue ||
        _themeSettings.displayFontKey != next.displayFontKey ||
        _themeSettings.bodyFontKey != next.bodyFontKey;
    if (!hasChanged || !mounted) {
      return;
    }
    setState(() {
      _themeSettings = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'II.VI',
      theme: AppTheme.dark(settings: _themeSettings),
      home: AppRoot(
        onThemeSettingsChanged: _onThemeSettingsChanged,
        initialThemeSettings: _themeSettings,
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.onThemeSettingsChanged,
    required this.initialThemeSettings,
  });

  final ValueChanged<AppThemeSettings> onThemeSettingsChanged;
  final AppThemeSettings initialThemeSettings;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _showSplash = true;

  void _finishSplash() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSplash
          ? SplashCatalogPage(
              key: const ValueKey('splash'),
              onFinished: _finishSplash,
            )
          : HomeShell(
              key: const ValueKey('home'),
              onThemeSettingsChanged: widget.onThemeSettingsChanged,
              initialThemeSettings: widget.initialThemeSettings,
            ),
    );
  }
}
