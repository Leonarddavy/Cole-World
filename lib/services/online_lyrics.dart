import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Marks lyrics that came from LRCLIB (an LRC "re:" tag, so the credit
/// survives being saved and re-read).
const String lrclibSourceName = 'LRCLIB';

/// LRCLIB couldn't be reached or had a problem; worth trying again later
/// (unlike a song it simply has no lyrics for).
class LrclibUnavailableException implements Exception {
  const LrclibUnavailableException(this.reason);

  final String reason;

  @override
  String toString() => 'LrclibUnavailableException: $reason';
}

/// Looks up lyrics on LRCLIB (https://lrclib.net), a free, community-run
/// lyrics database. Only the song title, artist and length are sent.
class LrclibClient {
  LrclibClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);
  static const Map<String, String> _headers = {
    // LRCLIB asks clients to identify themselves.
    'User-Agent': 'II.VI music player',
  };

  /// Returns LRC or plain lyrics text tagged with [lrclibSourceName], or
  /// null if LRCLIB has nothing suitable. Throws
  /// [LrclibUnavailableException] when the lookup itself fails.
  Future<String?> fetch({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final trackName = cleanSearchTitle(title);
    final artistName = cleanSearchArtist(artist);
    if (trackName.isEmpty) {
      return null;
    }
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': trackName,
      if (artistName.isNotEmpty) 'artist_name': artistName,
    });
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: kIsWeb ? null : _headers)
          .timeout(_timeout);
    } catch (error) {
      debugPrint('[LrclibClient.fetch] $error');
      throw LrclibUnavailableException('$error');
    }
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw LrclibUnavailableException('HTTP ${response.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw LrclibUnavailableException('Bad response: $error');
    }
    if (decoded is! List) {
      throw const LrclibUnavailableException('Unexpected response');
    }
    final lyrics = pickBestLrclibLyrics(
      decoded.whereType<Map>().map(Map<String, dynamic>.from).toList(),
      duration: duration,
    );
    return lyrics == null ? null : '[re:$lrclibSourceName]\n$lyrics';
  }
}

final RegExp _featuring = RegExp(
  r'\s*[\(\[]?\s*\b(feat\.?|ft\.?|featuring)\s.*$',
  caseSensitive: false,
);

/// "Power Trip (feat. Miguel)" -> "Power Trip". Filename leftovers like
/// "01 - " track numbers are dropped too.
String cleanSearchTitle(String title) {
  return title
      .replaceFirst(RegExp(r'^\s*\d{1,3}\s*[-._)]\s*'), '')
      .replaceFirst(_featuring, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// "J. Cole ft. Miguel" -> "J. Cole"; "J. Cole & Kendrick" stays as-is.
String cleanSearchArtist(String artist) {
  return artist.replaceFirst(_featuring, '').trim();
}

/// Picks the best search result: synced lyrics win over plain ones, then
/// the closest length to [duration]. Results more than 10 seconds off are
/// likely a different version (live, remix) and skipped when the length is
/// known. Instrumentals have no lyrics to show.
String? pickBestLrclibLyrics(
  List<Map<String, dynamic>> results, {
  Duration? duration,
}) {
  String? text(Object? value) {
    final string = value?.toString().trim();
    return string == null || string.isEmpty ? null : string;
  }

  ({String lyrics, bool synced, double gap})? best;
  for (final result in results) {
    if (result['instrumental'] == true) {
      continue;
    }
    final synced = text(result['syncedLyrics']);
    final lyrics = synced ?? text(result['plainLyrics']);
    if (lyrics == null) {
      continue;
    }
    var gap = 0.0;
    final seconds = result['duration'];
    if (duration != null && duration > Duration.zero) {
      if (seconds is num) {
        gap = (seconds - duration.inMilliseconds / 1000).abs().toDouble();
        if (gap > 10) {
          continue;
        }
      } else {
        // Unknown length: usable, but behind any result that matches.
        gap = 10;
      }
    }
    final isSynced = synced != null;
    final better =
        best == null ||
        (isSynced && !best.synced) ||
        (isSynced == best.synced && gap < best.gap);
    if (better) {
      best = (lyrics: lyrics, synced: isSynced, gap: gap);
    }
  }
  return best?.lyrics;
}
