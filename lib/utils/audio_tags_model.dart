import 'dart:typed_data';

/// The subset of an audio file's embedded tags the app uses.
class AudioTags {
  const AudioTags({
    this.title,
    this.artist,
    this.coverBytes,
    this.coverMimeType,
    this.lyrics,
    this.duration,
  });

  final String? title;
  final String? artist;
  final Uint8List? coverBytes;
  final String? coverMimeType;

  /// Embedded lyrics: plain text or LRC.
  final String? lyrics;

  /// Playing time, when the container reports it.
  final Duration? duration;

  bool get hasCover => coverBytes != null && coverBytes!.isNotEmpty;

  String get coverExtension {
    switch (coverMimeType?.toLowerCase()) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      default:
        return '.jpg';
    }
  }
}
