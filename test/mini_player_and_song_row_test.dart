import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/widgets/mini_player_bar.dart';
import 'package:jcole_player/widgets/song_row.dart';

const _track = Track(
  id: 't1',
  title: 'Love Yourz',
  artist: 'J. Cole',
  filePath: '/love.mp3',
  duration: Duration(minutes: 3, seconds: 31),
);

final _entry = CollectionEntry(
  id: 'fhd',
  type: CollectionType.album,
  title: 'Forest Hills Drive',
  history: '',
  featuredArtists: const [],
  tracks: const [_track],
);

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('MiniPlayerBar', () {
    late List<String> calls;

    Widget miniPlayer() => SizedBox(
      width: 360,
      child: MiniPlayerBar(
        track: _track,
        entry: _entry,
        isPlaying: true,
        isLoading: false,
        isBuffering: false,
        durationListenable: ValueNotifier(const Duration(minutes: 4)),
        positionListenable: ValueNotifier(const Duration(minutes: 2)),
        onToggle: () => calls.add('toggle'),
        onPrevious: () async => calls.add('previous'),
        onNext: () async => calls.add('next'),
        isLiked: false,
        onToggleLike: () => calls.add('like'),
        onOpenNowPlaying: () => calls.add('open'),
      ),
    );

    setUp(() => calls = []);

    testWidgets('shows the song with a progress line', (tester) async {
      await tester.pumpWidget(_host(miniPlayer()));
      expect(find.text('Love Yourz'), findsOneWidget);
      expect(find.text('J. Cole'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.5, 0.001));
    });

    testWidgets('tap opens the player; buttons do their own thing', (
      tester,
    ) async {
      await tester.pumpWidget(_host(miniPlayer()));
      await tester.tap(find.text('Love Yourz'));
      await tester.tap(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Add to Liked Songs'));
      expect(calls, ['open', 'toggle', 'like']);
    });

    testWidgets('swiping skips songs', (tester) async {
      await tester.pumpWidget(_host(miniPlayer()));
      await tester.fling(find.text('Love Yourz'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.text('Love Yourz'), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      expect(calls, ['next', 'previous']);
    });

    testWidgets('screen readers get next/previous actions', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(miniPlayer()));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Now playing: Love Yourz')),
      );
      final actions = node.getSemanticsData().customSemanticsActionIds!.map(
        CustomSemanticsAction.getAction,
      );
      expect(
        actions.map((action) => action!.label),
        containsAll(['Next song', 'Previous song']),
      );
      handle.dispose();
    });
  });

  group('SongRow', () {
    Widget row(
      Track track, {
      bool active = false,
      bool playing = false,
      VoidCallback? onTap,
      VoidCallback? onActions,
      VoidCallback? onQueue,
    }) => SizedBox(
      width: 380,
      child: SongRow(
        track: track,
        number: 3,
        isActive: active,
        isPlaying: playing,
        isLoading: false,
        animateIn: false,
        onTap: onTap ?? () {},
        onShowActions: onActions ?? () {},
        onSwipeToQueue: onQueue,
      ),
    );

    testWidgets('shows the number, artist and length', (tester) async {
      await tester.pumpWidget(_host(row(_track)));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('J. Cole · 3:31'), findsOneWidget);
    });

    testWidgets('songs without audio invite adding a file', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(
          row(
            const Track(
              id: 'x',
              title: 'Middle Child',
              artist: 'J. Cole',
              filePath: '',
            ),
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('No audio file · tap to add'), findsOneWidget);
      await tester.tap(find.text('Middle Child'));
      expect(tapped, isTrue);
    });

    testWidgets('long-press and ⋮ open the song actions', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(row(_track, onActions: () => opened++)));
      await tester.longPress(find.text('Love Yourz'));
      await tester.tap(find.byTooltip('Song options'));
      expect(opened, 2);
    });

    testWidgets('swiping right adds to the queue and keeps the row', (
      tester,
    ) async {
      var queued = 0;
      await tester.pumpWidget(_host(row(_track, onQueue: () => queued++)));
      await tester.drag(find.text('Love Yourz'), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(queued, 1);
      expect(find.text('Love Yourz'), findsOneWidget);
    });
  });
}
