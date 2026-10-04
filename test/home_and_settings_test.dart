import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/app_tab.dart';
import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/pages/home_page.dart';
import 'package:jcole_player/pages/library_page.dart';
import 'package:jcole_player/pages/settings_page.dart';

const _playable = Track(
  id: 'a',
  title: 'Wet Dreamz',
  artist: 'J. Cole',
  filePath: '/a.mp3',
);
const _silent = Track(
  id: 'b',
  title: 'Middle Child',
  artist: 'J. Cole',
  filePath: '',
);

CollectionEntry _collection(
  String id,
  CollectionType type, {
  List<Track> tracks = const [_playable],
}) => CollectionEntry(
  id: id,
  type: type,
  title: 'Title $id',
  history: '',
  featuredArtists: const [],
  tracks: tracks,
);

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: child),
);

void main() {
  group('HomePage', () {
    late List<String> calls;

    Widget home({
      List<CollectionEntry>? entries,
      RecentTrackShortcut? nowPlaying,
      DateTime? now,
    }) => HomePage(
      entries: entries ?? [_collection('fhd', CollectionType.album)],
      smartPlaylists: const [],
      recentTracks: const [],
      nowPlaying: nowPlaying,
      isPlaying: false,
      onOpenCollection: (entry) => calls.add('open ${entry.id}'),
      onPlayTrack: (track, entry) async => calls.add('play ${track.id}'),
      onTogglePlayback: () => calls.add('toggle'),
      onOpenNowPlaying: () => calls.add('now playing'),
      onSeeAll: (type) => calls.add('see all ${type.name}'),
      onImportMusic: () => calls.add('import'),
      now: now ?? DateTime(2026, 1, 1, 20),
    );

    setUp(() => calls = []);

    testWidgets('greets by time of day', (tester) async {
      await tester.pumpWidget(_host(home(now: DateTime(2026, 1, 1, 9))));
      expect(find.text('Good morning'), findsOneWidget);
      await tester.pumpWidget(_host(home(now: DateTime(2026, 1, 1, 21))));
      expect(find.text('Good evening'), findsOneWidget);
    });

    testWidgets('leads with importing when nothing can play', (tester) async {
      await tester.pumpWidget(
        _host(
          home(
            entries: [
              _collection(
                'seed',
                CollectionType.album,
                tracks: const [_silent],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Bring your music in'), findsOneWidget);
      await tester.tap(find.text('Import music'));
      expect(calls, ['import']);
    });

    testWidgets('hides the import card once music plays', (tester) async {
      await tester.pumpWidget(_host(home()));
      expect(find.text('Bring your music in'), findsNothing);
    });

    testWidgets('offers to continue the current song', (tester) async {
      await tester.pumpWidget(
        _host(
          home(
            nowPlaying: RecentTrackShortcut(
              entry: _collection('fhd', CollectionType.album),
              track: _playable,
            ),
          ),
        ),
      );
      expect(find.text('CONTINUE LISTENING'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume'));
      await tester.tap(find.text('CONTINUE LISTENING'));
      expect(calls, ['toggle', 'now playing']);
    });

    testWidgets('rails link to their full tab', (tester) async {
      await tester.pumpWidget(
        _host(
          home(
            entries: [
              _collection('fhd', CollectionType.album),
              _collection('mc', CollectionType.single),
            ],
          ),
        ),
      );
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Singles'), findsOneWidget);
      await tester.tap(find.text('See all').first);
      expect(calls, ['see all album']);
    });
  });

  group('SettingsPage', () {
    late List<String> calls;
    late TabLayout lastLayout;

    Widget settings({bool onlineAllowed = true}) => SettingsPage(
      tabLayout: TabLayout.defaults,
      onTabLayoutChanged: (layout) => lastLayout = layout,
      backgroundRotation: false,
      onBackgroundRotationChanged: (value) => calls.add('rotate $value'),
      customBackgroundCount: 0,
      onUploadBackgrounds: () async {
        calls.add('upload');
        return 2;
      },
      onResetBackgrounds: () async => calls.add('reset'),
      onOpenThemeEditor: () async => calls.add('theme'),
      onlineLyrics: false,
      onSetOnlineLyrics: (value) async {
        calls.add('lyrics $value');
        return onlineAllowed && value;
      },
      editMode: false,
      onEditModeChanged: (value) => calls.add('edit $value'),
      onRescanSongInfo: () async => calls.add('rescan'),
      onImportMusic: () async => calls.add('import'),
      onReplayIntro: () => calls.add('intro'),
    );

    setUp(() {
      calls = [];
      lastLayout = TabLayout.defaults;
    });

    Future<void> pumpSettings(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: page));
    }

    testWidgets('appearance needs no Edit Mode', (tester) async {
      await pumpSettings(tester, settings());
      await tester.tap(find.text('Fonts & colors'));
      await tester.tap(find.text('Rotate background images'));
      await tester.tap(find.text('Add background images'));
      await tester.pumpAndSettle();
      expect(calls, ['theme', 'rotate true', 'upload']);
      // The reset option appears once custom images exist.
      expect(find.text('2 custom images'), findsOneWidget);
      expect(find.text('Use the built-in backgrounds'), findsOneWidget);
    });

    testWidgets('online lyrics reflects whether it was really turned on', (
      tester,
    ) async {
      await pumpSettings(tester, settings(onlineAllowed: false));
      await tester.tap(find.text('Find lyrics online'));
      await tester.pumpAndSettle();
      expect(calls, ['lyrics true']);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Find lyrics online'),
      );
      expect(tile.value, isFalse); // declined in the confirmation
    });

    testWidgets('tabs can be hidden, but not Home', (tester) async {
      await pumpSettings(tester, settings());
      final homeSwitch = tester.widget<Switch>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Home'),
          matching: find.byType(Switch),
        ),
      );
      expect(homeSwitch.onChanged, isNull);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Story'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pump();
      expect(lastLayout.visible, isNot(contains(AppTab.story)));
      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('marks which tabs sit in the bottom bar', (tester) async {
      await pumpSettings(tester, settings());
      expect(find.text('In the bottom bar'), findsNWidgets(3));
    });

    testWidgets('library and about actions', (tester) async {
      await pumpSettings(tester, settings());
      await tester.tap(find.text('Import music'));
      await tester.tap(find.text('Replay the intro'));
      expect(calls, ['import', 'intro']);
    });
  });
}
