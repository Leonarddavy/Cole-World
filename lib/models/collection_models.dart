enum CollectionType { album, single, feature, playlist }

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.history,
    required this.featuredArtists,
    required this.tracks,
    this.thumbnailPath,
    this.thumbnailDataBase64,
  });

  final String id;
  final CollectionType type;
  final String title;
  final String history;
  final List<String> featuredArtists;
  final List<Track> tracks;
  final String? thumbnailPath;
  final String? thumbnailDataBase64;

  /// Smart playlists (Liked Songs, On Repeat) are generated from listening
  /// data rather than stored, so they are read-only and never persisted.
  static const String smartIdPrefix = 'smart_';

  static bool isSmartId(String id) => id.startsWith(smartIdPrefix);

  bool get isSmart => isSmartId(id);

  CollectionEntry copyWith({
    String? title,
    String? history,
    List<String>? featuredArtists,
    List<Track>? tracks,
    String? thumbnailPath,
    String? thumbnailDataBase64,
  }) {
    return CollectionEntry(
      id: id,
      type: type,
      title: title ?? this.title,
      history: history ?? this.history,
      featuredArtists: featuredArtists ?? this.featuredArtists,
      tracks: tracks ?? this.tracks,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailDataBase64: thumbnailDataBase64 ?? this.thumbnailDataBase64,
    );
  }

  /// Replaces both thumbnail fields at once so a stale value from the
  /// previous thumbnail (which [copyWith] would keep) can't take precedence.
  CollectionEntry withThumbnail({
    String? thumbnailPath,
    String? thumbnailDataBase64,
  }) {
    return CollectionEntry(
      id: id,
      type: type,
      title: title,
      history: history,
      featuredArtists: featuredArtists,
      tracks: tracks,
      thumbnailPath: thumbnailPath,
      thumbnailDataBase64: thumbnailDataBase64,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'history': history,
      'featuredArtists': featuredArtists,
      'thumbnailPath': _sanitizePersistedPath(thumbnailPath),
      'thumbnailDataBase64': thumbnailDataBase64,
      'tracks': tracks.map((track) => track.toJson()).toList(),
    };
  }

  static CollectionEntry fromJson(Map<String, dynamic> json) {
    return CollectionEntry(
      id: (json['id'] ?? '').toString(),
      type: _typeFromName((json['type'] ?? '').toString()),
      title: (json['title'] ?? '').toString(),
      history: (json['history'] ?? '').toString(),
      featuredArtists: (json['featuredArtists'] as List? ?? [])
          .map((artist) => artist.toString())
          .toList(),
      tracks: (json['tracks'] as List? ?? [])
          .whereType<Map>()
          .map((track) => Track.fromJson(Map<String, dynamic>.from(track)))
          .toList(),
      thumbnailPath: _sanitizePersistedPath(json['thumbnailPath']?.toString()),
      thumbnailDataBase64: json['thumbnailDataBase64']?.toString(),
    );
  }

  static CollectionType _typeFromName(String name) {
    return CollectionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => CollectionType.album,
    );
  }

  static String? _sanitizePersistedPath(String? rawPath) {
    if (rawPath == null) {
      return null;
    }
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) {
      return null;
    }
    return trimmed.isEmpty ? null : trimmed;
  }
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.artworkPath,
  });

  final String id;
  final String title;
  final String artist;
  final String filePath;

  /// Cover art extracted from the audio file's tags, stored in app storage.
  final String? artworkPath;

  Track copyWith({String? title, String? artist, String? artworkPath}) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  bool hasSameInfoAs(Track other) {
    return title == other.title &&
        artist == other.artist &&
        artworkPath == other.artworkPath;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filePath': _sanitizePersistedFilePath(filePath),
      if (artworkPath != null) 'artworkPath': artworkPath,
    };
  }

  static Track fromJson(Map<String, dynamic> json) {
    final rawPath = (json['filePath'] ?? '').toString();
    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      filePath: _sanitizePersistedFilePath(rawPath),
      artworkPath: CollectionEntry._sanitizePersistedPath(
        json['artworkPath']?.toString(),
      ),
    );
  }

  static String _sanitizePersistedFilePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) {
      return '';
    }
    return trimmed;
  }
}
