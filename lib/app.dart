import 'package:flutter/material.dart';

import 'data/artist_editions.dart';
import 'pages/home_shell.dart';
import 'pages/splash_catalog_page.dart';
import 'services/app_prefs.dart';
import 'services/library_storage.dart';
import 'theme/app_theme.dart';
import 'widgets/graffiti_backdrop.dart';

class JColeVaultApp extends StatefulWidget {
  const JColeVaultApp({
    super.key,
    this.prefs = const AppPrefs(),
    this.libraryStorageFor,
  });

  /// Where settings are read and saved (overridable in tests).
  final AppPrefs prefs;

  /// Opens an artist's saved library; null uses the device's storage.
  final LibraryStorage Function(String vault)? libraryStorageFor;

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
        libraryStorageFor: widget.libraryStorageFor,
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
    this.libraryStorageFor,
  });

  final AppPrefs prefs;
  final LibraryStorage Function(String vault)? libraryStorageFor;
  final ValueChanged<AppThemeSettings> onThemeSettingsChanged;
  final AppThemeSettings initialThemeSettings;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /// Null until saved settings are read: the intro only plays on the very
  /// first launch, so returning listeners go straight to their music.
  bool? _showIntro;

  /// The saved settings, handed to the shell so it needn't read them again.
  Map<String, dynamic>? _prefs;

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
    // Open straight into the current artist's look, not J. Cole's first.
    final artist = activeArtistIn(prefs);
    final cardShape = prefs['cardShape'];
    widget.onThemeSettingsChanged(
      themeForVault(
        artist,
        vaultsIn(prefs)[artist.name],
        cardShapeKey: cardShape is String ? cardShape : null,
      ),
    );
    GraffitiBackdrop.setDefaultSources(artistEdition(artist).backdropAssets);
    setState(() {
      _prefs = prefs;
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
              initialPrefs: _prefs,
              prefs: widget.prefs,
              libraryStorageFor: widget.libraryStorageFor,
            ),
    );
  }
}
