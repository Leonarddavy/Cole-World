import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/models/playback_models.dart';
import 'package:jcole_player/services/smart_playlists.dart';

Track _track(String id, {String? artwork}) => Track(
  id: id,
  title: 'Song $id',
  artist: 'J. Cole',
  filePath: '/$id.mp3',
  artworkPath: artwork,
);

CollectionEntry _entry(String id, List<Track> tracks) => CollectionEntry(
  id: id,
  type: CollectionType.album,
  title: id,
  history: '',
  featuredArtists: const [],
  tracks: tracks,
);

void main() {
  final shared = _track('b', artwork: '/b.jpg');
  final entries = [
    _entry('album1', [_track('a'), shared]),
    // A playlist built from Singles reuses the same track id.
    _entry('playlist1', [shared, _track('c')]),
  ];

  group('Liked Songs', () {
    test('keeps like order and drops deleted songs', () {
      final tracks = likedTracks(entries, ['c', 'gone', 'a']);
      expect(tracks.map((t) => t.id), ['c', 'a']);
    });

    test('is a read-only smart playlist using the first available cover', () {
      final entry = buildSmartEntry(
        likedSongsEntryId,
        entries: entries,
        likedTrackIds: ['a', 'b'],
        playCounts: const {},
      )!;
      expect(entry.isSmart, isTrue);
      expect(entry.title, 'Liked Songs');
      expect(entry.type, CollectionType.playlist);
      expect(entry.tracks.map((t) => t.id), ['a', 'b']);
      expect(entry.thumbnailPath, '/b.jpg');
    });
  });

  group('On Repeat', () {
    test('ranks by play count and ignores songs played once', () {
      final tracks = onRepeatTracks(entries, {'a': 2, 'b': 5, 'c': 1});
      expect(tracks.map((t) => t.id), ['b', 'a']);
    });

    test('breaks ties by library order and skips deleted songs', () {
      final tracks = onRepeatTracks(entries, {'c': 3, 'a': 3, 'gone': 9});
      expect(tracks.map((t) => t.id), ['a', 'c']);
    });

    test('caps the playlist length', () {
      final many = [
        _entry('big', [for (var i = 0; i < 50; i++) _track('t$i')]),
      ];
      final counts = {for (var i = 0; i < 50; i++) 't$i': 2 + i};
      expect(onRepeatTracks(many, counts), hasLength(onRepeatMaxTracks));
      expect(onRepeatTracks(many, counts).first.id, 't49');
    });
  });

  test('buildSmartEntry ignores ordinary ids', () {
    expect(
      buildSmartEntry(
        'album1',
        entries: entries,
        likedTrackIds: const [],
        playCounts: const {},
      ),
      isNull,
    );
  });

  group('SleepTimerState', () {
    test('reports time remaining and never goes negative', () {
      final now = DateTime(2026, 1, 1, 22);
      final timer = SleepTimerState.at(now.add(const Duration(minutes: 30)));
      expect(timer.remaining(now), const Duration(minutes: 30));
      expect(timer.remaining(now.add(const Duration(hours: 1))), Duration.zero);
      expect(const SleepTimerState.endOfTrack().remaining(now), isNull);
    });
  });

  test('Track.copyWith keeps unchanged info', () {
    final updated = shared.copyWith(title: 'New');
    expect(updated.title, 'New');
    expect(updated.artworkPath, '/b.jpg');
    expect(updated.hasSameInfoAs(shared), isFalse);
    expect(shared.copyWith().hasSameInfoAs(shared), isTrue);
  });
}
