import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/models/lyrics.dart';
import 'package:jcole_player/pages/lyrics_page.dart';
import 'package:jcole_player/services/music_video.dart';
import 'package:jcole_player/widgets/music_video_player.dart';

const _track = Track(
  id: 't1',
  title: 'Love Yourz',
  artist: 'J. Cole',
  filePath: '/love.mp3',
);

/// Stands in for the WebView-based YouTube player.
class _FakeVideo implements MusicVideoPlayer {
  _FakeVideo({
    required this.videoId,
    required this.start,
    required this.autoPlay,
  }) : _position = start,
       _status = autoPlay ? MusicVideoStatus.playing : MusicVideoStatus.paused;

  final String videoId;
  final Duration start;
  final bool autoPlay;
  final StreamController<Duration> _positions = StreamController.broadcast(
    sync: true,
  );
  final StreamController<MusicVideoStatus> _statuses =
      StreamController.broadcast(sync: true);
  Duration _position;
  MusicVideoStatus _status;
  final seeks = <Duration>[];
  bool disposed = false;

  void emit(Duration position) {
    _position = position;
    _positions.add(position);
  }

  void setStatus(MusicVideoStatus status) {
    _status = status;
    _statuses.add(status);
  }

  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<MusicVideoStatus> get statuses => _statuses.stream;
  @override
  Duration get position => _position;
  @override
  MusicVideoStatus get status => _status;
  @override
  Future<void> play() async => setStatus(MusicVideoStatus.playing);
  @override
  Future<void> pause() async => setStatus(MusicVideoStatus.paused);
  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Widget buildView(BuildContext context, {required double aspectRatio}) =>
      const ColoredBox(key: ValueKey('fake_video'), color: Colors.black);

  @override
  Future<void> dispose() async => disposed = true;
}

class _Harness {
  final saved = <MusicVideoLink?>[];
  final resumed = <(Duration, bool)>[];
  final opened = <Uri>[];
  final videos = <_FakeVideo>[];
  final songPlaying = StreamController<bool>.broadcast(sync: true);
  final songPositions = StreamController<Duration>.broadcast(sync: true);
  final currentTrack = ValueNotifier<Track?>(_track);
  MusicVideoLink? link;
  bool consent = true;
  bool songWasPlaying = true;
  int pauses = 0;
  Duration songPosition = const Duration(seconds: 20);

  MusicVideoSupport support() => MusicVideoSupport(
    linkFor: (_) => link,
    saveLink: (_, next) async {
      link = next;
      saved.add(next);
    },
    ensureConsent: () async => consent,
    canSearch: () => false,
    search: (_) async => const [],
    openExternal: (uri) async {
      opened.add(uri);
      return true;
    },
    pauseSong: () async {
      pauses++;
      return songWasPlaying;
    },
    resumeSong: (position, {required play}) async =>
        resumed.add((position, play)),
    songPosition: () => songPosition,
    songPlayingStream: songPlaying.stream,
    playerFactory: ({required videoId, required start, required autoPlay}) {
      final video = _FakeVideo(
        videoId: videoId,
        start: start,
        autoPlay: autoPlay,
      );
      videos.add(video);
      return video;
    },
    embeddedPlayerAvailable: true,
  );

  Widget page() => MaterialApp(
    theme: ThemeData.dark(),
    home: LyricsPage(
      currentTrackListenable: currentTrack,
      positionStream: songPositions.stream,
      initialPosition: songPosition,
      onSeek: (_) async {},
      loadLyrics: (_) async => Lyrics.tryParse(
        '[00:10.00]First line\n[00:20.00]Second line\n[00:30.00]Third line',
      ),
      onImportLyrics: (_) async => null,
      onRemoveLyrics: (_) async {},
      onlineLyricsListenable: ValueNotifier(false),
      onEnableOnlineLyrics: () async => false,
      musicVideos: support(),
    ),
  );
}

Color? _lineColor(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style.color;

Future<void> _pumpPage(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.page());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'opening the video pauses the song and starts at the same moment',
    (tester) async {
      final harness = _Harness()
        ..link = const MusicVideoLink(
          videoId: 'dQw4w9WgXcQ',
          offset: Duration(seconds: 15),
        );
      await _pumpPage(tester, harness);

      await tester.tap(find.byTooltip('Watch the music video'));
      await tester.pump();

      expect(harness.pauses, 1);
      final video = harness.videos.single;
      expect(video.videoId, 'dQw4w9WgXcQ');
      expect(video.start, const Duration(seconds: 35)); // 20 s + 15 s intro
      expect(video.autoPlay, isTrue);
      expect(find.byKey(const ValueKey('fake_video')), findsOneWidget);
      expect(find.text('Lyrics timing +15.0 s'), findsOneWidget);
    },
  );

  testWidgets('lyrics follow the video, and the song never plays alongside', (
    tester,
  ) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(
        videoId: 'dQw4w9WgXcQ',
        offset: Duration(seconds: 15),
      );
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();
    final video = harness.videos.single;
    final accent = Theme.of(
      tester.element(find.text('Third line')),
    ).colorScheme.primary;

    // 46 s into the video = 31 s into the song: the third line.
    video.emit(const Duration(seconds: 46));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lineColor(tester, 'Third line'), accent);

    // Song positions are ignored while the video drives the lyrics.
    harness.songPositions.add(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lineColor(tester, 'Third line'), accent);

    // The song starting from elsewhere (lock screen) closes the video.
    harness.songPlaying.add(true);
    await tester.pump();
    expect(video.disposed, isTrue);
    expect(harness.resumed, isEmpty);
    expect(find.byKey(const ValueKey('fake_video')), findsNothing);
  });

  testWidgets('closing the video continues the song at the matching moment', (
    tester,
  ) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(
        videoId: 'dQw4w9WgXcQ',
        offset: Duration(seconds: 15),
      );
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();
    harness.videos.single.emit(const Duration(seconds: 50));

    await tester.tap(find.byTooltip('Close music video').first);
    await tester.pump();

    expect(harness.resumed, [(const Duration(seconds: 35), true)]);
    expect(harness.videos.single.disposed, isTrue);
  });

  testWidgets('when the video ends the song takes over', (tester) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(videoId: 'dQw4w9WgXcQ');
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();
    final video = harness.videos.single
      ..emit(const Duration(minutes: 4))
      ..setStatus(MusicVideoStatus.ended);
    await tester.pump();
    expect(video.disposed, isTrue);
    expect(harness.resumed, [(const Duration(minutes: 4), true)]);
  });

  testWidgets('sync controls and long-press line up the lyrics', (
    tester,
  ) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(videoId: 'dQw4w9WgXcQ');
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();

    await tester.tap(find.byTooltip('Show lyrics later'));
    await tester.pump();
    expect(harness.saved.last!.offset, const Duration(milliseconds: 500));
    expect(find.text('Lyrics timing +0.5 s'), findsOneWidget);

    // "Second line" (20 s in the song) is being sung 32 s into the video.
    harness.videos.single.emit(const Duration(seconds: 32));
    await tester.longPress(find.text('Second line'));
    await tester.pump();
    expect(harness.saved.last!.offset, const Duration(seconds: 12));

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(harness.saved.last!.offset, Duration.zero);
  });

  testWidgets('tapping a line seeks the video, not the song', (tester) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(
        videoId: 'dQw4w9WgXcQ',
        offset: Duration(seconds: 15),
      );
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();
    await tester.tap(find.text('Third line'));
    await tester.pump();
    expect(harness.videos.single.seeks, [const Duration(seconds: 45)]);
  });

  testWidgets('with no video yet, a pasted link is used', (tester) async {
    final harness = _Harness();
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pumpAndSettle();

    expect(find.text('Find videos automatically'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not a link');
    await tester.tap(find.text('Use link'));
    await tester.pump();
    expect(find.text("That doesn't look like a YouTube link."), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/dQw4w9WgXcQ?si=x',
    );
    await tester.tap(find.text('Use link'));
    await tester.pumpAndSettle();
    expect(harness.saved.single!.videoId, 'dQw4w9WgXcQ');
    expect(harness.videos.single.videoId, 'dQw4w9WgXcQ');
  });

  testWidgets('pasting from the clipboard uses a copied link in one tap', (
    tester,
  ) async {
    final harness = _Harness();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpAndSettle();
    expect(harness.saved.single!.videoId, 'dQw4w9WgXcQ');
  });

  testWidgets('nothing happens without consent', (tester) async {
    final harness = _Harness()
      ..consent = false
      ..link = const MusicVideoLink(videoId: 'dQw4w9WgXcQ');
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pumpAndSettle();
    expect(harness.pauses, 0);
    expect(harness.videos, isEmpty);
  });

  testWidgets('changing songs closes the video without resuming', (
    tester,
  ) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(videoId: 'dQw4w9WgXcQ');
    await _pumpPage(tester, harness);
    await tester.tap(find.byTooltip('Watch the music video'));
    await tester.pump();

    harness.currentTrack.value = const Track(
      id: 't2',
      title: 'Wet Dreamz',
      artist: 'J. Cole',
      filePath: '/wet.mp3',
    );
    await tester.pump();
    expect(harness.videos.single.disposed, isTrue);
    expect(harness.resumed, isEmpty);
  });

  testWidgets('without an embedded player the video opens on YouTube', (
    tester,
  ) async {
    final harness = _Harness()
      ..link = const MusicVideoLink(videoId: 'dQw4w9WgXcQ');
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final support = harness.support();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LyricsPage(
          currentTrackListenable: harness.currentTrack,
          positionStream: harness.songPositions.stream,
          initialPosition: Duration.zero,
          onSeek: (_) async {},
          loadLyrics: (_) async => null,
          onImportLyrics: (_) async => null,
          onRemoveLyrics: (_) async {},
          onlineLyricsListenable: ValueNotifier(false),
          onEnableOnlineLyrics: () async => false,
          musicVideos: MusicVideoSupport(
            linkFor: support.linkFor,
            saveLink: support.saveLink,
            ensureConsent: support.ensureConsent,
            canSearch: support.canSearch,
            search: support.search,
            openExternal: support.openExternal,
            pauseSong: support.pauseSong,
            resumeSong: support.resumeSong,
            songPosition: support.songPosition,
            songPlayingStream: support.songPlayingStream,
            playerFactory: support.playerFactory,
            embeddedPlayerAvailable: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Watch the music video on YouTube'));
    await tester.pump();
    expect(harness.opened.single.toString(), contains('watch?v=dQw4w9WgXcQ'));
    expect(harness.pauses, 0);
  });
}
