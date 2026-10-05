import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'online_lyrics.dart' show cleanSearchArtist, cleanSearchTitle;

final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// A YouTube music video linked to a song.
///
/// [offset] is how far the video runs ahead of the song at the same musical
/// moment: music videos often open with an intro, so a lyric sung 20 s into
/// the song may come 35 s into the video (offset +15 s).
class MusicVideoLink {
  const MusicVideoLink({
    required this.videoId,
    this.title,
    this.offset = Duration.zero,
  });

  final String videoId;
  final String? title;
  final Duration offset;

  Uri get watchUri => Uri.https('www.youtube.com', '/watch', {'v': videoId});

  /// Where the video should be when the song is at [songPosition].
  Duration videoTimeFor(Duration songPosition) =>
      _notNegative(songPosition + offset);

  /// Where the song is when the video is at [videoPosition].
  Duration songTimeFor(Duration videoPosition) =>
      _notNegative(videoPosition - offset);

  MusicVideoLink copyWith({Duration? offset}) => MusicVideoLink(
    videoId: videoId,
    title: title,
    offset: offset ?? this.offset,
  );

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    if (title != null) 'title': title,
    'offsetMs': offset.inMilliseconds,
  };

  static MusicVideoLink? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final videoId = raw['videoId'];
    if (videoId is! String || !_videoIdPattern.hasMatch(videoId)) {
      return null;
    }
    final offsetMs = raw['offsetMs'];
    final title = raw['title'];
    return MusicVideoLink(
      videoId: videoId,
      title: title is String && title.isNotEmpty ? title : null,
      offset: Duration(milliseconds: offsetMs is num ? offsetMs.toInt() : 0),
    );
  }

  static Duration _notNegative(Duration value) =>
      value.isNegative ? Duration.zero : value;
}

/// A search result the user can pick.
class MusicVideoCandidate {
  const MusicVideoCandidate({
    required this.videoId,
    required this.title,
    required this.channel,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String channel;
  final String? thumbnailUrl;

  MusicVideoLink toLink() => MusicVideoLink(videoId: videoId, title: title);
}

/// Pulls the video id out of anything people paste: a bare id, youtu.be
/// short links, watch / embed / shorts / live URLs, YouTube Music links.
String? parseYouTubeVideoId(String input) {
  final text = input.trim();
  if (_videoIdPattern.hasMatch(text)) {
    return text;
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null) {
    return null;
  }
  final host = uri.host.toLowerCase().replaceFirst(
    RegExp(r'^(www|m|music)\.'),
    '',
  );
  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    candidate = uri.queryParameters['v'];
    final segments = uri.pathSegments;
    if (candidate == null &&
        segments.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(segments.first)) {
      candidate = segments[1];
    }
  }
  return candidate != null && _videoIdPattern.hasMatch(candidate)
      ? candidate
      : null;
}

String _searchQuery(String title, String artist) => [
  cleanSearchArtist(artist),
  cleanSearchTitle(title),
  'official music video',
].where((part) => part.isNotEmpty).join(' ');

/// Opens YouTube's own search, for picking a video without an API key.
Uri youtubeSearchUri({required String title, required String artist}) =>
    Uri.https('www.youtube.com', '/results', {
      'search_query': _searchQuery(title, artist),
    });

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _unescapeHtml(String text) => text
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Uploads that aren't the music video itself.
final RegExp _notTheVideo = RegExp(
  r'\b(lyrics?|lyric video|audio|cover|react\w*|live|remix|slowed|'
  r'sped up|8d|karaoke|instrumental|nightcore|reverb|visualizer)\b',
);

/// Orders YouTube search results so the official music video comes first:
/// rewards the song title, "official (music) video" and the artist's own
/// (or VEVO) channel; demotes lyric, audio, live, cover and reaction uploads.
List<MusicVideoCandidate> rankMusicVideoCandidates(
  List<Map<String, dynamic>> items, {
  required String title,
  required String artist,
}) {
  final wantedTitle = _normalize(cleanSearchTitle(title));
  final wantedArtist = _normalize(
    cleanSearchArtist(artist),
  ).replaceAll(' ', '');
  final scored = <({MusicVideoCandidate candidate, int score, int index})>[];

  for (final (index, item) in items.indexed) {
    final id = item['id'];
    final videoId = id is Map ? id['videoId'] : null;
    if (videoId is! String || !_videoIdPattern.hasMatch(videoId)) {
      continue;
    }
    final snippet = item['snippet'] is Map ? item['snippet'] as Map : const {};
    final videoTitle = _unescapeHtml((snippet['title'] ?? '').toString());
    final channel = _unescapeHtml((snippet['channelTitle'] ?? '').toString());
    final thumbnails = snippet['thumbnails'];
    final medium = thumbnails is Map ? thumbnails['medium'] : null;
    final thumbnailUrl = medium is Map ? medium['url']?.toString() : null;

    final normalizedTitle = _normalize(videoTitle);
    final normalizedChannel = _normalize(channel).replaceAll(' ', '');
    var score = 0;
    if (wantedTitle.isNotEmpty && normalizedTitle.contains(wantedTitle)) {
      score += 4;
    }
    if (RegExp(r'official (music )?video').hasMatch(normalizedTitle)) {
      score += 3;
    }
    if (wantedArtist.isNotEmpty && normalizedChannel.contains(wantedArtist)) {
      score += 2;
    }
    if (normalizedChannel.contains('vevo')) {
      score += 1;
    }
    for (final match in _notTheVideo.allMatches(normalizedTitle)) {
      // A song may legitimately be called e.g. "Live"; only penalize words
      // that aren't part of the song title itself.
      if (!wantedTitle.contains(match.group(0)!)) {
        score -= 4;
      }
    }
    scored.add((
      candidate: MusicVideoCandidate(
        videoId: videoId,
        title: videoTitle,
        channel: channel,
        thumbnailUrl: thumbnailUrl,
      ),
      score: score,
      index: index,
    ));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [for (final item in scored) item.candidate];
}

class MusicVideoSearchException implements Exception {
  const MusicVideoSearchException(this.message);

  /// A sentence suitable for showing to the user.
  final String message;

  @override
  String toString() => 'MusicVideoSearchException: $message';
}

/// Finds music videos with the YouTube Data API (needs the user's own free
/// API key; each search costs 100 of the default 10,000 daily quota units).
class YoutubeVideoSearch {
  YoutubeVideoSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 10);

  Future<List<MusicVideoCandidate>> search({
    required String apiKey,
    required String title,
    required String artist,
  }) async {
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'type': 'video',
      // Only videos the owner allows to play inside other apps.
      'videoEmbeddable': 'true',
      'maxResults': '8',
      'q': _searchQuery(title, artist),
      'key': apiKey,
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } catch (error) {
      debugPrint('[YoutubeVideoSearch] $error');
      throw const MusicVideoSearchException(
        "Couldn't reach YouTube. Check your connection and try again.",
      );
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MusicVideoSearchException(
        'YouTube sent an unexpected reply. Try again later.',
      );
    }

    if (response.statusCode != 200) {
      throw MusicVideoSearchException(_messageForError(body));
    }
    final items = body is Map ? body['items'] : null;
    if (items is! List) {
      return const [];
    }
    return rankMusicVideoCandidates(
      [
        for (final item in items.whereType<Map>())
          Map<String, dynamic>.from(item),
      ],
      title: title,
      artist: artist,
    );
  }

  static String _messageForError(Object? body) {
    final error = body is Map ? body['error'] : null;
    final reasons = <String>{
      if (error is Map && error['errors'] is List)
        for (final item in (error['errors'] as List).whereType<Map>())
          '${item['reason']}',
      if (error is Map && error['status'] != null) '${error['status']}',
    };
    final message = error is Map ? '${error['message'] ?? ''}' : '';
    if (reasons.contains('quotaExceeded') ||
        reasons.contains('dailyLimitExceeded')) {
      return "Today's YouTube search limit is used up. Try again tomorrow, "
          'or paste a link.';
    }
    if (reasons.contains('accessNotConfigured') ||
        reasons.contains('SERVICE_DISABLED')) {
      return 'Turn on "YouTube Data API v3" for your key in Google Cloud '
          'Console, then try again.';
    }
    if (reasons.contains('keyInvalid') ||
        message.toLowerCase().contains('api key not valid')) {
      return "That YouTube API key isn't valid. Check it in Settings.";
    }
    return "YouTube couldn't search right now. Try again, or paste a link.";
  }
}
