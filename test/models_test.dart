import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/models/story_content.dart';
import 'package:jcole_player/theme/app_theme.dart';

void main() {
  group('CollectionEntry', () {
    const entry = CollectionEntry(
      id: 'a1',
      type: CollectionType.single,
      title: 'Middle Child',
      history: 'history',
      featuredArtists: ['X'],
      tracks: [
        Track(id: 't1', title: 'Song', artist: 'J. Cole', filePath: '/a.mp3'),
      ],
      thumbnailPath: '/thumb.jpg',
    );

    test('round-trips through JSON', () {
      final restored = CollectionEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.type, CollectionType.single);
      expect(restored.featuredArtists, ['X']);
      expect(restored.tracks.single.filePath, '/a.mp3');
      expect(restored.thumbnailPath, '/thumb.jpg');
    });

    test('drops non-persistable blob/data paths', () {
      final json = entry.toJson()
        ..['thumbnailPath'] = 'blob:http://x/1'
        ..['tracks'] = [
          {'id': 't', 'title': 'T', 'artist': 'A', 'filePath': 'data:x'},
        ];
      final restored = CollectionEntry.fromJson(json);
      expect(restored.thumbnailPath, isNull);
      expect(restored.tracks.single.filePath, isEmpty);
    });

    test('persists track artwork and tolerates its absence', () {
      const track = Track(
        id: 't',
        title: 'T',
        artist: 'A',
        filePath: '/t.mp3',
        artworkPath: '/art.jpg',
      );
      expect(Track.fromJson(track.toJson()).artworkPath, '/art.jpg');
      expect(entry.tracks.single.toJson().containsKey('artworkPath'), isFalse);
      expect(Track.fromJson(entry.tracks.single.toJson()).artworkPath, isNull);
    });

    test('unknown type falls back to album', () {
      final json = entry.toJson()..['type'] = 'mixtape';
      expect(CollectionEntry.fromJson(json).type, CollectionType.album);
    });

    test('withThumbnail clears the stale thumbnail field', () {
      final withData = entry.withThumbnail(thumbnailDataBase64: 'AAAA');
      expect(withData.thumbnailPath, isNull);
      final withPath = withData.withThumbnail(thumbnailPath: '/new.jpg');
      expect(withPath.thumbnailDataBase64, isNull);
      expect(withPath.thumbnailPath, '/new.jpg');
      expect(withPath.tracks, entry.tracks);
    });
  });

  group('StoryContent', () {
    test('falls back to defaults for invalid input', () {
      final content = StoryContent.fromJson('not a map');
      expect(content.heroTitle, StoryContent.defaults().heroTitle);
    });

    test('round-trips through JSON', () {
      final custom = StoryContent.defaults().copyWith(heroTitle: 'Custom');
      final restored = StoryContent.fromJson(custom.toJson());
      expect(restored.heroTitle, 'Custom');
      expect(restored.timelineEvents.length, custom.timelineEvents.length);
    });
  });

  group('AppThemeSettings', () {
    test('has value equality', () {
      const a = AppThemeSettings();
      final b = AppThemeSettings.fromJson(a.toJson());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(bodyFontKey: 'lato'), isFalse);
    });
  });
}
