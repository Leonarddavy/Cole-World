import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  // The default fonts ship in assets/google_fonts; the optional ones from the
  // theme editor are still downloaded on demand (needs INTERNET on Android).
  GoogleFonts.config.allowRuntimeFetching = true;
  _registerBundledFontLicenses();
  runApp(const JColeVaultApp());
}

/// The bundled fonts are under the SIL Open Font License, which must ship
/// with them; this lists them on the app's licenses screen.
void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Rubik Wet Paint', 'OFL-RubikWetPaint.txt'),
      ('Nunito Sans', 'OFL-NunitoSans.txt'),
    ]) {
      final license = await rootBundle.loadString('assets/google_fonts/$file');
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
}
