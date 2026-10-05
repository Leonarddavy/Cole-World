import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jcole_player/services/music_video.dart';

Map<String, dynamic> _item(
  String id,
  String title, {
  String channel = 'Someone',
}) => {
  'id': {'kind': 'youtube#video', 'videoId': id},
  'snippet': {
    'title': title,
    'channelTitle': channel,
    'thumbnails': {
      'medium': {'url': 'https://i.ytimg.com/vi/$id/mqdefault.jpg'},
    },
  },
};

void main() {
  group('parseYouTubeVideoId', () {
    test('reads every common link format', () {
      const id = 'dQw4w9WgXcQ';
      for (final input in [
        id,
        'https://www.youtube.com/watch?v=$id',
        'https://youtube.com/watch?v=$id&t=42s',
        'https://m.youtube.com/watch?v=$id',
        'https://music.youtube.com/watch?v=$id&si=abc',
        'https://youtu.be/$id',
        'https://youtu.be/$id?si=share',
        'youtu.be/$id',
        'https://www.youtube.com/embed/$id',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/live/$id',
        'https://www.youtube-nocookie.com/embed/$id',
        '  https://youtu.be/$id  ',
      ]) {
        expect(parseYouTubeVideoId(input), id, reason: input);
      }
    });

    test('rejects other sites and malformed ids', () {
      for (final input in [
        '',
        'not a link',
        'https://vimeo.com/123456789',
        'https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/channel/UC123',
      ]) {
        expect(parseYouTubeVideoId(input), isNull, reason: input);
      }
    });
  });

  group('MusicVideoLink', () {
    test('maps between song time and video time', () {
      const link = MusicVideoLink(
        videoId: 'dQw4w9WgXcQ',
        offset: Duration(seconds: 15),
      );
      expect(
        link.videoTimeFor(const Duration(seconds: 20)),
        const Duration(seconds: 35),
      );
      expect(
        link.songTimeFor(const Duration(seconds: 35)),
        const Duration(seconds: 20),
      );
      // During the video's intro the song hasn't started yet.
      expect(link.songTimeFor(const Duration(seconds: 5)), Duration.zero);
    });

    test('round-trips through JSON and rejects bad ids', () {
      const link = MusicVideoLink(
        videoId: 'dQw4w9WgXcQ',
        title: 'Love Yourz',
        offset: Duration(milliseconds: -1500),
      );
      final restored = MusicVideoLink.fromJson(link.toJson())!;
      expect(restored.videoId, link.videoId);
      expect(restored.title, 'Love Yourz');
      expect(restored.offset, const Duration(milliseconds: -1500));
      expect(MusicVideoLink.fromJson({'videoId': 'bad'}), isNull);
      expect(MusicVideoLink.fromJson('nope'), isNull);
    });

    test('links to the video on YouTube', () {
      expect(
        const MusicVideoLink(videoId: 'dQw4w9WgXcQ').watchUri.toString(),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });
  });

  test('ranks the official video above lyric, audio and live uploads', () {
    final ranked = rankMusicVideoCandidates(
      [
        _item('aaaaaaaaaaa', 'J. Cole - Love Yourz (Lyrics)'),
        _item(
          'bbbbbbbbbbb',
          'J. Cole - Love Yourz (Official Audio)',
          channel: 'J. Cole',
        ),
        _item(
          'ccccccccccc',
          'J. Cole - Love Yourz (Official Music Video)',
          channel: 'JColeVEVO',
        ),
        _item('ddddddddddd', 'J. Cole - Love Yourz LIVE in Fayetteville'),
        _item('eeeeeeeeeee', 'Reacting to Love Yourz'),
        {
          'id': {'kind': 'youtube#channel'},
          'snippet': {'title': 'not a video'},
        },
      ],
      title: 'Love Yourz',
      artist: 'J. Cole',
    );
    expect(ranked.first.videoId, 'ccccccccccc');
    expect(ranked.length, 5); // the channel result is skipped
    expect(ranked.last.videoId, 'eeeeeeeeeee');
  });

  test('does not penalise words that are part of the song title', () {
    final ranked = rankMusicVideoCandidates(
      [
        _item('aaaaaaaaaaa', 'Some Song (Lyrics)'),
        _item(
          'bbbbbbbbbbb',
          'Artist - Live (Official Video)',
          channel: 'Artist',
        ),
      ],
      title: 'Live',
      artist: 'Artist',
    );
    expect(ranked.first.videoId, 'bbbbbbbbbbb');
  });

  test('unescapes titles from the API', () {
    final ranked = rankMusicVideoCandidates(
      [_item('aaaaaaaaaaa', 'Johnny P&#39;s Caddy &amp; more')],
      title: "Johnny P's Caddy",
      artist: 'Benny the Butcher',
    );
    expect(ranked.single.title, "Johnny P's Caddy & more");
  });

  group('YoutubeVideoSearch', () {
    test('asks for embeddable videos with the cleaned song name', () async {
      late Uri requested;
      final search = YoutubeVideoSearch(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'items': [_item('ccccccccccc', 'Power Trip (Official Video)')],
            }),
            200,
          );
        }),
      );
      final results = await search.search(
        apiKey: 'KEY',
        title: 'Power Trip (feat. Miguel)',
        artist: 'J. Cole ft. Miguel',
      );
      expect(requested.host, 'www.googleapis.com');
      expect(requested.path, '/youtube/v3/search');
      expect(
        requested.queryParameters['q'],
        'J. Cole Power Trip official music video',
      );
      expect(requested.queryParameters['videoEmbeddable'], 'true');
      expect(requested.queryParameters['type'], 'video');
      expect(requested.queryParameters['key'], 'KEY');
      expect(results.single.videoId, 'ccccccccccc');
    });

    Future<String> failureMessage(int status, Map<String, dynamic> body) async {
      final search = YoutubeVideoSearch(
        client: MockClient(
          (_) async => http.Response(jsonEncode(body), status),
        ),
      );
      try {
        await search.search(apiKey: 'KEY', title: 'Song', artist: 'Artist');
      } on MusicVideoSearchException catch (error) {
        return error.message;
      }
      fail('expected a MusicVideoSearchException');
    }

    test('explains quota, key and API-disabled errors', () async {
      expect(
        await failureMessage(403, {
          'error': {
            'errors': [
              {'reason': 'quotaExceeded'},
            ],
          },
        }),
        contains('limit'),
      );
      expect(
        await failureMessage(400, {
          'error': {
            'message': 'API key not valid. Please pass a valid API key.',
            'errors': [
              {'reason': 'badRequest'},
            ],
          },
        }),
        contains("isn't valid"),
      );
      expect(
        await failureMessage(403, {
          'error': {
            'errors': [
              {'reason': 'accessNotConfigured'},
            ],
          },
        }),
        contains('YouTube Data API v3'),
      );
    });

    test('reports network failures', () async {
      final search = YoutubeVideoSearch(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        search.search(apiKey: 'KEY', title: 'Song', artist: 'Artist'),
        throwsA(isA<MusicVideoSearchException>()),
      );
    });
  });

  test('builds a YouTube search link for picking a video by hand', () {
    final uri = youtubeSearchUri(title: 'No Role Modelz', artist: 'J. Cole');
    expect(uri.host, 'www.youtube.com');
    expect(
      uri.queryParameters['search_query'],
      'J. Cole No Role Modelz official music video',
    );
  });
}
