import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jcole_player/models/lyrics.dart';
import 'package:jcole_player/services/online_lyrics.dart';

Map<String, dynamic> _result({
  String? synced,
  String? plain,
  num duration = 200,
  bool instrumental = false,
}) => {
  'syncedLyrics': synced,
  'plainLyrics': plain,
  'duration': duration,
  'instrumental': instrumental,
};

void main() {
  group('cleaning search terms', () {
    test('drops featured artists and track numbers from titles', () {
      expect(cleanSearchTitle('Power Trip (feat. Miguel)'), 'Power Trip');
      expect(cleanSearchTitle('01 - Intro'), 'Intro');
      expect(cleanSearchTitle('a lot ft. J. Cole'), 'a lot');
      expect(cleanSearchTitle('m y . l i f e'), 'm y . l i f e');
    });

    test('keeps the lead artist', () {
      expect(cleanSearchArtist('J. Cole ft. 21 Savage & Morray'), 'J. Cole');
      expect(cleanSearchArtist('J. Cole featuring Miguel'), 'J. Cole');
      expect(cleanSearchArtist('Benny the Butcher'), 'Benny the Butcher');
    });
  });

  group('pickBestLrclibLyrics', () {
    test('prefers synced lyrics over plain ones', () {
      expect(
        pickBestLrclibLyrics([
          _result(plain: 'plain'),
          _result(synced: '[00:01.00]synced', plain: 'plain'),
        ]),
        '[00:01.00]synced',
      );
    });

    test('prefers the closest length and skips other versions', () {
      final results = [
        _result(synced: '[00:01]live', duration: 260),
        _result(synced: '[00:01]radio', duration: 205),
        _result(synced: '[00:01]album', duration: 201),
      ];
      expect(
        pickBestLrclibLyrics(results, duration: const Duration(seconds: 200)),
        '[00:01]album',
      );
      expect(
        pickBestLrclibLyrics([
          _result(synced: '[00:01]live', duration: 260),
        ], duration: const Duration(seconds: 200)),
        isNull,
      );
    });

    test('ranks results with an unknown length behind matching ones', () {
      final results = [
        {'syncedLyrics': '[00:01]unknown', 'duration': null},
        _result(synced: '[00:01]close', duration: 207),
      ];
      expect(
        pickBestLrclibLyrics(results, duration: const Duration(seconds: 200)),
        '[00:01]close',
      );
      expect(
        pickBestLrclibLyrics(results.sublist(0, 1), duration: Duration.zero),
        '[00:01]unknown',
      );
    });

    test('ignores instrumentals and empty results', () {
      expect(
        pickBestLrclibLyrics([
          _result(instrumental: true, plain: 'x'),
          _result(synced: '  ', plain: ''),
        ]),
        isNull,
      );
    });
  });

  group('LrclibClient', () {
    test('searches by cleaned title and artist and tags the source', () async {
      late Uri requested;
      final client = LrclibClient(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([_result(synced: '[00:12.00]No role modelz')]),
            ),
            200,
          );
        }),
      );

      final text = await client.fetch(
        title: 'No Role Modelz (feat. Someone)',
        artist: 'J. Cole ft. Someone',
      );

      expect(requested.host, 'lrclib.net');
      expect(requested.path, '/api/search');
      expect(requested.queryParameters, {
        'track_name': 'No Role Modelz',
        'artist_name': 'J. Cole',
      });
      final lyrics = Lyrics.tryParse(text)!;
      expect(lyrics.source, lrclibSourceName);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'No role modelz');
    });

    test('returns null when LRCLIB has no lyrics for the song', () async {
      for (final handler in <MockClientHandler>[
        (_) async => http.Response('[]', 200),
        (_) async => http.Response('{"message": "not found"}', 404),
      ]) {
        final client = LrclibClient(client: MockClient(handler));
        expect(await client.fetch(title: 'Song', artist: 'Artist'), isNull);
      }
    });

    test('throws when LRCLIB is unreachable or misbehaving', () async {
      for (final handler in <MockClientHandler>[
        (_) async => http.Response('busy', 503),
        (_) async => http.Response('<html>', 200),
        (_) async => http.Response('{"not": "a list"}', 200),
        (_) async => throw http.ClientException('offline'),
      ]) {
        final client = LrclibClient(client: MockClient(handler));
        await expectLater(
          client.fetch(title: 'Song', artist: 'Artist'),
          throwsA(isA<LrclibUnavailableException>()),
        );
      }
    });

    test('does not search without a title', () async {
      var calls = 0;
      final client = LrclibClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );
      expect(await client.fetch(title: '  ', artist: 'J. Cole'), isNull);
      expect(calls, 0);
    });
  });
}
