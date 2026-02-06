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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'history': history,
      'featuredArtists': featuredArtists,
      'thumbnailPath': thumbnailPath,
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
      thumbnailPath: json['thumbnailPath']?.toString(),
      thumbnailDataBase64: json['thumbnailDataBase64']?.toString(),
    );
  }

  static CollectionType _typeFromName(String name) {
    return CollectionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => CollectionType.album,
    );
  }
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
  });

  final String id;
  final String title;
  final String artist;
  final String filePath;

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'artist': artist, 'filePath': filePath};
  }

  static Track fromJson(Map<String, dynamic> json) {
    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      filePath: (json['filePath'] ?? '').toString(),
    );
  }
}
