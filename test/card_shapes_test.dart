import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/data/artist_editions.dart';
import 'package:jcole_player/models/app_tab.dart';
import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/pages/settings_page.dart';
import 'package:jcole_player/theme/app_theme.dart';
import 'package:jcole_player/theme/card_shapes.dart';
import 'package:jcole_player/widgets/artwork_card.dart';
import 'package:jcole_player/widgets/song_row.dart';

final _entry = CollectionEntry(
  id: 'fhd',
  type: CollectionType.album,
  title: 'Forest Hills Drive',
  history: '',
  featuredArtists: const [],
  tracks: const [],
);

ThemeData _themeWith(CardShapeStyle style) =>
    ThemeData.dark().copyWith(extensions: [CardShapes(style)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardShapes', () {
    test('each style draws its own outline', () {
      expect(
        const CardShapes(CardShapeStyle.rounded).card(14),
        isA<RoundedRectangleBorder>(),
      );
      expect(
        const CardShapes(CardShapeStyle.cut).card(14),
        isA<BeveledRectangleBorder>(),
      );
      expect(
        const CardShapes(CardShapeStyle.squircle).card(14),
        isA<ContinuousRectangleBorder>(),
      );
      expect(
        const CardShapes(CardShapeStyle.round).card(14),
        isA<StadiumBorder>(),
      );
      final sharp =
          const CardShapes(CardShapeStyle.sharp).card(14)
              as RoundedRectangleBorder;
      expect((sharp.borderRadius as BorderRadius).topLeft.x, 3);
      final soft =
          const CardShapes(CardShapeStyle.soft).card(14)
              as RoundedRectangleBorder;
      expect((soft.borderRadius as BorderRadius).topLeft.x, greaterThan(14));
    });

    test('only the Circle style makes covers round', () {
      expect(
        const CardShapes(CardShapeStyle.round).artwork(12),
        isA<CircleBorder>(),
      );
      expect(
        const CardShapes(CardShapeStyle.cut).artwork(12),
        isA<BeveledRectangleBorder>(),
      );
    });

    test('a zero radius always stays square', () {
      for (final style in CardShapeStyle.values) {
        final shape = CardShapes(style).artwork(0);
        expect(shape, isA<RoundedRectangleBorder>(), reason: style.name);
        expect(
          (shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.zero,
          reason: style.name,
        );
      }
    });

    test('keeps the outline it is given', () {
      const side = BorderSide(color: Colors.red, width: 2);
      for (final style in CardShapeStyle.values) {
        expect(
          CardShapes(style).card(14, side: side).side,
          side,
          reason: style.name,
        );
      }
    });
  });

  group('theme settings', () {
    test('save the card shape and ignore unknown ones', () {
      const settings = AppThemeSettings(cardShapeKey: 'cut');
      final restored = AppThemeSettings.fromJson(settings.toJson());
      expect(restored.cardShape, CardShapeStyle.cut);
      expect(restored, settings);
      expect(
        AppThemeSettings.fromJson({'cardShapeKey': 'blob'}).cardShape,
        CardShapeStyle.rounded,
      );
      expect(const AppThemeSettings().cardShape, CardShapeStyle.rounded);
    });

    test('editing colors keeps the chosen shape', () {
      const settings = AppThemeSettings(cardShapeKey: 'round');
      expect(
        settings.copyWith(primaryColorValue: 0xFF5CC8FF).cardShape,
        CardShapeStyle.round,
      );
    });

    test('the app theme carries the shapes', () {
      final theme = AppTheme.dark(
        settings: const AppThemeSettings(cardShapeKey: 'squircle'),
      );
      expect(theme.extension<CardShapes>()!.style, CardShapeStyle.squircle);
      expect(theme.cardTheme.shape, isA<ContinuousRectangleBorder>());
    });
  });

  testWidgets('falls back to rounded when the theme has no shapes', (
    tester,
  ) async {
    late CardShapes found;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            found = CardShapes.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(found.style, CardShapeStyle.rounded);
  });

  testWidgets('covers and song rows follow the theme shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _themeWith(CardShapeStyle.round),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox.square(
                dimension: 80,
                child: ArtworkCard(
                  entry: _entry,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SongRow(
                track: const Track(
                  id: 't',
                  title: 'Love Yourz',
                  artist: 'J. Cole',
                  filePath: '/x.mp3',
                ),
                number: 1,
                isActive: false,
                isPlaying: false,
                isLoading: false,
                animateIn: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final cover = tester.widget<ShapedBox>(find.byType(ShapedBox));
    expect(cover.shape, isA<CircleBorder>());
    final ink = tester.widget<Ink>(find.byType(Ink));
    expect((ink.decoration! as ShapeDecoration).shape, isA<StadiumBorder>());
  });

  testWidgets('Settings lets you pick a shape with previews', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picked = <CardShapeStyle>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SettingsPage(
          tabLayout: TabLayout.defaults,
          onTabLayoutChanged: (_) {},
          backgroundRotation: false,
          onBackgroundRotationChanged: (_) {},
          customBackgroundCount: 0,
          onUploadBackgrounds: () async => 0,
          onResetBackgrounds: () async {},
          onOpenThemeEditor: () async {},
          onlineLyrics: false,
          onSetOnlineLyrics: (value) async => value,
          editMode: false,
          onEditModeChanged: (_) {},
          onRescanSongInfo: () async {},
          onImportMusic: () async {},
          onReplayIntro: () {},
          youtubeApiKeySet: false,
          onEditYoutubeApiKey: () async => false,
          cardShape: CardShapeStyle.rounded,
          onCardShapeChanged: picked.add,
          artist: ArtistProfile.jcole,
          onArtistChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Card shape'));
    await tester.pumpAndSettle();
    for (final style in CardShapeStyle.values) {
      expect(find.text(style.label), findsWidgets, reason: style.name);
    }
    await tester.tap(find.text('Cut corners'));
    await tester.pumpAndSettle();
    expect(picked, [CardShapeStyle.cut]);
    expect(find.textContaining('Cut corners:'), findsOneWidget);
  });
}
