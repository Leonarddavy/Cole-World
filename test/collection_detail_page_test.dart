import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/pages/collection_detail_page.dart';
import 'package:jcole_player/services/play_queue.dart';

Track _t(String id, {String file = '/x.mp3', int seconds = 240}) => Track(
  id: id,
  title: 'Song $id',
  artist: 'J. Cole',
  filePath: file,
  duration: Duration(seconds: seconds),
);

void main() {
  late List<String> calls;
  late CollectionEntry album;

  setUp(() {
    calls = [];
    album = CollectionEntry(
      id: 'fhd',
      type: CollectionType.album,
      title: 'Forest Hills Drive',
      history: 'Released in 2014.',
      featuredArtists: const ['No official guest verses'],
      tracks: [
        _t('1'),
        _t('2', file: ''),
        _t('3', seconds: 300),
      ],
    );
  });

  Future<void> pumpPage(WidgetTester tester, CollectionEntry entry) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CollectionDetailPage(
          entry: entry,
          currentTrackListenable: ValueNotifier<Track?>(null),
          playerStateStream: const Stream<PlayerState>.empty(),
          pendingTrackIdListenable: ValueNotifier<String?>(null),
          queueListenable: ValueNotifier(PlayQueueView.empty),
          onToggleTrack: (track, _) async => calls.add('toggle ${track.id}'),
          onPlayCollection: (_, {required shuffle}) async =>
              calls.add(shuffle ? 'shuffle' : 'play'),
          onAttachFile: (track, _) async => calls.add('attach ${track.id}'),
          onPlayNext: (track, _) async => calls.add('next ${track.id}'),
          onAddToQueue: (track, _) async => calls.add('queue ${track.id}'),
          onAddToPlaylist: (track, _) async =>
              calls.add('playlist ${track.id}'),
          onShowTrackDetails: (track, _) async =>
              calls.add('details ${track.id}'),
          onReorderTracks: (_, _, _) async {},
          onDeleteTrack: (_, track) async => calls.add('delete ${track.id}'),
          onMenuAction: (_, _) async {},
          resolveEntry: (id) => id == entry.id ? entry : null,
          likedTrackIdsListenable: ValueNotifier(<String>{}),
          onToggleLike: (track) => calls.add('like ${track.id}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header sums up the album', (tester) async {
    await pumpPage(tester, album);
    expect(find.text('Album · 3 songs · 13 min'), findsOneWidget);
    // "No official guest verses" isn't a featured artist.
    expect(find.textContaining('With '), findsNothing);
  });

  testWidgets('songs come before the story', (tester) async {
    await pumpPage(tester, album);
    final firstSong = tester.getTopLeft(find.text('Song 1')).dy;
    final about = tester.getTopLeft(find.text('About this album')).dy;
    expect(firstSong, lessThan(about));
    // The story is tucked away until expanded.
    expect(find.text('Released in 2014.'), findsNothing);
    await tester.tap(find.text('About this album'));
    await tester.pumpAndSettle();
    expect(find.text('Released in 2014.'), findsOneWidget);
  });

  testWidgets('play and shuffle the whole album', (tester) async {
    await pumpPage(tester, album);
    await tester.tap(find.byTooltip('Play album'));
    await tester.tap(find.text('Shuffle'));
    expect(calls, ['play', 'shuffle']);
  });

  testWidgets('tapping plays in place; songs without audio ask for a file', (
    tester,
  ) async {
    await pumpPage(tester, album);
    await tester.tap(find.text('Song 1'));
    await tester.tap(find.text('Song 2'));
    await tester.pumpAndSettle();
    expect(calls, ['toggle 1', 'attach 2']);
  });

  testWidgets('the song sheet has queue, playlist and remove actions', (
    tester,
  ) async {
    await pumpPage(tester, album);
    await tester.longPress(find.text('Song 3'));
    await tester.pumpAndSettle();
    for (final label in [
      'Play next',
      'Add to queue',
      'Add to playlist…',
      'Add to Liked Songs',
      'Replace audio file',
      'Details',
      'Remove from album',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Play next'));
    await tester.pumpAndSettle();
    expect(calls, ['next 3']);
  });

  testWidgets('smart playlists are read-only', (tester) async {
    final liked = CollectionEntry(
      id: 'smart_liked',
      type: CollectionType.playlist,
      title: 'Liked Songs',
      history: '',
      featuredArtists: const [],
      tracks: [_t('1')],
    );
    await pumpPage(tester, liked);
    expect(find.text('Auto playlist · 1 song · 4 min'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    await tester.longPress(find.text('Song 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove from'), findsNothing);
  });
}
