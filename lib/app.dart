import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'pages/splash_catalog_page.dart';
import 'theme/app_theme.dart';

class JColeVaultApp extends StatelessWidget {
  const JColeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'II.VI',
      theme: AppTheme.dark,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

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
          : const HomeShell(key: ValueKey('home')),
    );
  }
}
