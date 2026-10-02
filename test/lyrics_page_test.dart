import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/models/lyrics.dart';
import 'package:jcole_player/pages/lyrics_page.dart';

const _track = Track(
  id: 't1',
  title: 'Love Yourz',
  artist: 'J. Cole',
  filePath: '/love.mp3',
);

/// The color a lyric line is actually drawn with.
Color? _lineColor(WidgetTester tester, String text) {
  return DefaultTextStyle.of(tester.element(find.text(text))).style.color;
}

void main() {
  late StreamController<Duration> positions;
  late List<Duration> seeks;

  setUp(() {
    positions = StreamController<Duration>.broadcast(sync: true);
    seeks = [];
  });

  tearDown(() => positions.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    required Lyrics? lyrics,
    Duration initialPosition = Duration.zero,
    bool onlineEnabled = false,
    Future<bool> Function()? onEnableOnline,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LyricsPage(
          currentTrackListenable: ValueNotifier<Track?>(_track),
          positionStream: positions.stream,
          initialPosition: initialPosition,
          onSeek: (position) async => seeks.add(position),
          loadLyrics: (_) async => lyrics,
          onImportLyrics: (_) async => null,
          onRemoveLyrics: (_) async {},
          onlineLyricsListenable: ValueNotifier(onlineEnabled),
          onEnableOnlineLyrics: onEnableOnline ?? () async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('highlights the line being sung and follows playback', (
    tester,
  ) async {
    final lyrics = Lyrics.tryParse(
      '[00:05]First line\n[00:10]Second line\n[00:20]Third line',
    );
    await pumpPage(
      tester,
      lyrics: lyrics,
      initialPosition: const Duration(seconds: 6),
    );
    final accent = Theme.of(
      tester.element(find.text('First line')),
    ).colorScheme.primary;

    expect(_lineColor(tester, 'First line'), accent);
    expect(_lineColor(tester, 'Second line'), isNot(accent));

    positions.add(const Duration(seconds: 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_lineColor(tester, 'Second line'), accent);
    expect(_lineColor(tester, 'First line'), isNot(accent));
  });

  testWidgets('tapping a line seeks to it', (tester) async {
    await pumpPage(
      tester,
      lyrics: Lyrics.tryParse('[00:05]First line\n[00:42.5]Later line'),
    );
    await tester.tap(find.text('Later line'));
    expect(seeks, [const Duration(seconds: 42, milliseconds: 500)]);
  });

  testWidgets('shows plain lyrics as unsynced', (tester) async {
    await pumpPage(tester, lyrics: Lyrics.tryParse('Just words\nNo times'));
    expect(find.text("These lyrics aren't time-synced."), findsOneWidget);
    expect(find.text('No times'), findsOneWidget);
  });

  testWidgets('offers to import when there are no lyrics', (tester) async {
    await pumpPage(tester, lyrics: null);
    expect(find.text('No lyrics for this song yet'), findsOneWidget);
    expect(find.text('Import lyrics file'), findsOneWidget);
  });

  testWidgets('offers an online search while it is off', (tester) async {
    var asked = 0;
    await pumpPage(
      tester,
      lyrics: null,
      onEnableOnline: () async {
        asked++;
        return false;
      },
    );
    await tester.tap(find.text('Find lyrics online'));
    await tester.pump();
    expect(asked, 1);
  });

  testWidgets('says when the online search found nothing', (tester) async {
    await pumpPage(tester, lyrics: null, onlineEnabled: true);
    expect(find.text('Find lyrics online'), findsNothing);
    expect(find.text('Nothing found on LRCLIB either.'), findsOneWidget);
  });

  testWidgets('credits LRCLIB for lyrics found online', (tester) async {
    await pumpPage(
      tester,
      lyrics: Lyrics.tryParse('[re:LRCLIB]\n[00:01.00]Hello'),
    );
    expect(find.text('Lyrics provided by LRCLIB (lrclib.net)'), findsOneWidget);
  });
}
