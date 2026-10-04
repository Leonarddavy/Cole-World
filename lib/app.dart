import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'pages/splash_catalog_page.dart';
import 'services/app_prefs.dart';
import 'theme/app_theme.dart';

class JColeVaultApp extends StatefulWidget {
  const JColeVaultApp({super.key, this.prefs = const AppPrefs()});

  /// Where "has the intro been seen" is read from (overridable in tests).
  final AppPrefs prefs;

  @override
  State<JColeVaultApp> createState() => _JColeVaultAppState();
}

class _JColeVaultAppState extends State<JColeVaultApp> {
  AppThemeSettings _themeSettings = const AppThemeSettings();

  void _onThemeSettingsChanged(AppThemeSettings next) {
    if (_themeSettings == next || !mounted) {
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
        prefs: widget.prefs,
        onThemeSettingsChanged: _onThemeSettingsChanged,
        initialThemeSettings: _themeSettings,
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.prefs,
    required this.onThemeSettingsChanged,
    required this.initialThemeSettings,
  });

  final AppPrefs prefs;
  final ValueChanged<AppThemeSettings> onThemeSettingsChanged;
  final AppThemeSettings initialThemeSettings;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /// Null until saved settings are read: the intro only plays on the very
  /// first launch, so returning listeners go straight to their music.
  bool? _showIntro;

  @override
  void initState() {
    super.initState();
    _decideIntro();
  }

  Future<void> _decideIntro() async {
    final prefs = await widget.prefs.load();
    if (!mounted) {
      return;
    }
    setState(() {
      // Only a fresh install has no saved settings; people updating from a
      // version without the "intro seen" flag shouldn't see it again.
      _showIntro = prefs['introSeen'] != true && prefs.isEmpty;
    });
  }

  void _finishIntro() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showIntro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showIntro = _showIntro;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showIntro == null
          ? ColoredBox(
              key: const ValueKey('loading'),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const SizedBox.expand(),
            )
          : showIntro
          ? SplashCatalogPage(
              key: const ValueKey('splash'),
              onFinished: _finishIntro,
            )
          : HomeShell(
              key: const ValueKey('home'),
              onThemeSettingsChanged: widget.onThemeSettingsChanged,
              initialThemeSettings: widget.initialThemeSettings,
            ),
    );
  }
}
