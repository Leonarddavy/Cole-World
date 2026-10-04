import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/app_tab.dart';
import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/theme/app_theme.dart';
import 'package:jcole_player/ui/formatting.dart';

Track _t(String id, {Duration? duration, String filePath = '/x.mp3'}) => Track(
  id: id,
  title: id,
  artist: 'J. Cole',
  filePath: filePath,
  duration: duration,
);

void main() {
  // The theme loads its bundled fonts through the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatting', () {
    test('track durations', () {
      expect(
        formatTrackDuration(const Duration(minutes: 4, seconds: 7)),
        '4:07',
      );
      expect(
        formatTrackDuration(const Duration(hours: 1, minutes: 2, seconds: 9)),
        '1:02:09',
      );
      expect(formatTrackDuration(Duration.zero), '0:00');
    });

    test('collection lengths', () {
      expect(
        formatTotalLength(const Duration(minutes: 47, seconds: 40)),
        '48 min',
      );
      expect(formatTotalLength(const Duration(minutes: 60)), '1 hr');
      expect(formatTotalLength(const Duration(minutes: 65)), '1 hr 5 min');
    });

    test('total length needs every song length', () {
      final known = [
        _t('a', duration: const Duration(minutes: 3)),
        _t('b', duration: const Duration(minutes: 4)),
      ];
      expect(totalDuration(known), const Duration(minutes: 7));
      expect(totalDuration([...known, _t('c')]), isNull);
      expect(totalDuration(const []), isNull);
    });

    test('song counts', () {
      expect(songCount(1), '1 song');
      expect(songCount(12), '12 songs');
    });
  });

  group('Track', () {
    test('round-trips its length and knows whether it has a file', () {
      final track = _t('a', duration: const Duration(seconds: 247));
      final restored = Track.fromJson(track.toJson());
      expect(restored.duration, const Duration(seconds: 247));
      expect(restored.hasFile, isTrue);
      expect(_t('b', filePath: '  ').hasFile, isFalse);
      expect(Track.fromJson({'id': 'x', 'durationMs': -5}).duration, isNull);
    });

    test('a changed length counts as changed info', () {
      final track = _t('a');
      expect(
        track
            .copyWith(duration: const Duration(minutes: 3))
            .hasSameInfoAs(track),
        isFalse,
      );
    });
  });

  group('TabLayout', () {
    test('defaults to every tab, Home first', () {
      expect(TabLayout.defaults.visible.first, AppTab.home);
      expect(TabLayout.defaults.visible, AppTab.values);
    });

    test('round-trips order and hidden tabs', () {
      final layout = TabLayout(
        order: const [
          AppTab.home,
          AppTab.playlists,
          AppTab.albums,
          AppTab.singles,
          AppTab.features,
          AppTab.story,
        ],
      ).withVisibility(AppTab.story, false);
      final restored = TabLayout.fromJson(layout.toJson());
      expect(restored.order, layout.order);
      expect(restored.visible, isNot(contains(AppTab.story)));
    });

    test('tolerates unknown, duplicate and missing tabs', () {
      final restored = TabLayout.fromJson({
        'order': ['story', 'launch', 'story', 'home'],
        'hidden': ['home', 'nope', 'singles'],
      });
      expect(restored.order.first, AppTab.story);
      expect(restored.order.toSet(), AppTab.values.toSet());
      expect(restored.order.length, AppTab.values.length);
      // Home can never be hidden.
      expect(restored.visible, contains(AppTab.home));
      expect(restored.visible, isNot(contains(AppTab.singles)));
      expect(TabLayout.fromJson('garbage').order, AppTab.values);
    });

    test('Home cannot be hidden', () {
      final layout = TabLayout.defaults.withVisibility(AppTab.home, false);
      expect(layout.visible, contains(AppTab.home));
    });
  });

  group('theme', () {
    test('defaults to a readable body font', () {
      expect(const AppThemeSettings().bodyFontKey, 'nunito_sans');
      expect(AppThemeSettings.fromJson(const {}).bodyFontKey, 'nunito_sans');
    });

    test('card surfaces follow the chosen colors', () {
      final gold = AppTheme.dark().colorScheme;
      final sky = AppTheme.dark(
        settings: const AppThemeSettings(primaryColorValue: 0xFF5CC8FF),
      ).colorScheme;
      final slate = AppTheme.dark(
        settings: const AppThemeSettings(backgroundColorValue: 0xFF101720),
      ).colorScheme;
      expect(sky.surfaceContainerHigh, isNot(gold.surfaceContainerHigh));
      expect(slate.surfaceContainerHigh, isNot(gold.surfaceContainerHigh));
      // Surfaces stay dark enough for light text.
      expect(
        ThemeData.estimateBrightnessForColor(gold.surfaceContainerHighest),
        Brightness.dark,
      );
    });
  });
}
