import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.jcole_player.playback',
      androidNotificationChannelName: 'II.VI Playback',
      androidNotificationChannelDescription:
          'Background playback controls for II.VI.',
      notificationColor: const Color(0xFFFFB547),
      androidNotificationIcon: 'drawable/ic_stat_ii_vi',
      androidShowNotificationBadge: false,
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
      androidStopForegroundOnPause: false,
      fastForwardInterval: const Duration(seconds: 10),
      rewindInterval: const Duration(seconds: 10),
      preloadArtwork: true,
    );
  }
  // Ensure GoogleFonts can fetch in release builds (Android needs INTERNET permission in main manifest).
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const JColeVaultApp());
}
