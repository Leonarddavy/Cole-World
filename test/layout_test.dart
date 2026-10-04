// Regression tests for the layout problems found in the UI review: these
// measure real sizes on small phones and with large text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/models/playback_models.dart';
import 'package:jcole_player/pages/library_page.dart';
import 'package:jcole_player/pages/now_playing_page.dart';
import 'package:jcole_player/services/play_queue.dart';
import 'package:jcole_player/widgets/floating_nav_bar.dart';
import 'package:jcole_player/widgets/mini_player_bar.dart';

final _entry = CollectionEntry(
  id: 'fhd',
  type: CollectionType.album,
  title: '2014 Forest Hills Drive',
  history: 'history',
  featuredArtists: const [],
  tracks: [
    for (var i = 0; i < 12; i++)
      Track(
        id: 't$i',
        title: 'Song number $i with a longer title',
        artist: 'J. Cole',
        filePath: '/$i.mp3',
      ),
  ],
);

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {double textScale = 1.0}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

/// Collects layout overflow errors instead of failing on the first one.
List<String> _captureOverflows() {
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      overflows.add(text.split('\n').first);
    } else {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return overflows;
}

NowPlayingPage _nowPlaying() {
  return NowPlayingPage(
    resolveEntry: (_) => _entry,
    currentTrackListenable: ValueNotifier(_entry.tracks.first),
    playerStateStream: const Stream<PlayerState>.empty(),
    positionStream: const Stream<Duration>.empty(),
    durationStream: const Stream<Duration?>.empty(),
    onJumpToQueueItem: (_) {},
    onRemoveFromQueue: (_) {},
    onMoveQueueItem: (_, _) {},
    onOpenLyrics: () {},
    onSeek: (_) async {},
    onTogglePlayback: () {},
    onSkipNext: () {},
    onSkipPrevious: () {},
    onToggleShuffle: () {},
    onCycleRepeat: () {},
    queueListenable: ValueNotifier(
      PlayQueueView(
        items: [
          for (final track in _entry.tracks)
            QueueItem(track: track, entryId: 'fhd'),
        ],
        currentIndex: 0,
        contextEntryId: 'fhd',
      ),
    ),
    shuffleEnabledListenable: ValueNotifier(false),
    repeatModeListenable: ValueNotifier(PlaybackRepeatMode.off),
    onShowTrackDetails: (_, _) async {},
    likedTrackIdsListenable: ValueNotifier(<String>{}),
    onToggleLike: (_) {},
    sleepTimerListenable: ValueNotifier<SleepTimerState?>(null),
    onSetSleepTimer: (_) {},
    onSleepAtEndOfTrack: () {},
  );
}

void main() {
  group('Now Playing', () {
    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(1280, 800), 1.0),
    ]) {
      testWidgets('never overflows on $size at ${scale}x text', (tester) async {
        _setScreen(tester, size);
        final overflows = _captureOverflows();
        await tester.pumpWidget(_app(_nowPlaying(), textScale: scale));
        await tester.pump(const Duration(milliseconds: 500));
        expect(overflows, isEmpty);
        // The controls and the queue strip are always reachable.
        expect(find.byTooltip('Play'), findsOneWidget);
        expect(find.textContaining('Next: Song number 1'), findsOneWidget);
      });
    }

    testWidgets('fits without scrolling on a small phone', (tester) async {
      _setScreen(tester, const Size(360, 640));
      await tester.pumpWidget(_app(_nowPlaying()));
      await tester.pump(const Duration(milliseconds: 500));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      // The cover stays a usable size and square.
      final cover = tester.getSize(find.byType(Hero));
      expect(cover.width, cover.height);
      expect(cover.width, greaterThanOrEqualTo(200));
    });

    testWidgets('the queue opens as a sheet', (tester) async {
      _setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(_app(_nowPlaying()));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.textContaining('Next: Song number 1'));
      await tester.pumpAndSettle();
      expect(find.text('Queue'), findsWidgets);
      expect(find.text('Now playing'.toUpperCase()), findsOneWidget);
      expect(find.text('Next from: 2014 Forest Hills Drive'), findsOneWidget);
    });
  });

  testWidgets('mini player and nav leave most of a small screen free', (
    tester,
  ) async {
    _setScreen(tester, const Size(360, 640));
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: const ValueKey('mini'),
                child: MiniPlayerBar(
                  track: _entry.tracks.first,
                  entry: _entry,
                  isPlaying: true,
                  isLoading: false,
                  isBuffering: false,
                  durationListenable: ValueNotifier(const Duration(minutes: 4)),
                  positionListenable: ValueNotifier(const Duration(minutes: 1)),
                  onToggle: () {},
                  onPrevious: () async {},
                  onNext: () async {},
                  isLiked: false,
                  onToggleLike: () {},
                ),
              ),
              KeyedSubtree(
                key: const ValueKey('nav'),
                child: FloatingNavBar(
                  items: const [
                    NavItem(label: 'Home', icon: Icons.home),
                    NavItem(label: 'Albums', icon: Icons.album),
                    NavItem(label: 'Singles', icon: Icons.music_note),
                    NavItem(label: 'Features', icon: Icons.mic),
                  ],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mini = tester.getSize(find.byKey(const ValueKey('mini'))).height;
    final nav = tester.getSize(find.byKey(const ValueKey('nav'))).height;
    // Was 200 + 102 = 302 px (47% of the screen) before the redesign.
    expect(mini, lessThanOrEqualTo(72));
    expect(mini + nav, lessThanOrEqualTo(160));
  });

  group('library grid', () {
    Future<void> pumpGrid(WidgetTester tester, Size size) async {
      _setScreen(tester, size);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: LibraryPage(
              tabType: CollectionType.album,
              entries: [
                for (var i = 0; i < 8; i++)
                  _entry.copyWith(title: 'Album $i').withThumbnail(),
              ],
              recentTracks: const [],
              onOpen: (_) {},
              onPlayRecentTrack: (_, _) async {},
              onCreateCollection: () {},
              onUploadToCollection: () {},
              onMenuAction: null,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows square covers in two columns on a phone', (
      tester,
    ) async {
      final overflows = _captureOverflows();
      await pumpGrid(tester, const Size(360, 640));
      final covers = find.byType(Hero);
      final first = tester.getRect(covers.at(0));
      final second = tester.getRect(covers.at(1));
      expect(first.width, closeTo(first.height, 0.5));
      expect(second.top, first.top); // side by side
      expect(overflows, isEmpty);
    });

    testWidgets('uses more columns on wide screens', (tester) async {
      await pumpGrid(tester, const Size(1280, 900));
      final covers = find.byType(Hero);
      final top = tester.getRect(covers.at(0)).top;
      final inFirstRow = [
        for (var i = 0; i < covers.evaluate().length; i++)
          if (tester.getRect(covers.at(i)).top == top) i,
      ];
      expect(inFirstRow.length, greaterThanOrEqualTo(5));
    });
  });
}
