import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';

import 'audio_tags_model.dart';

export 'audio_tags_model.dart';

/// Reads title, artist and cover art from [filePath]. Returns null when the
/// file is missing, unsupported, or has no usable tags.
Future<AudioTags?> readAudioTags(String filePath) async {
  try {
    return await Isolate.run(() => _readAudioTagsSync(filePath));
  } catch (error) {
    debugPrint('[readAudioTags] $filePath: $error');
    return null;
  }
}

AudioTags? _readAudioTagsSync(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return null;
  }
  final metadata = readMetadata(file, getImage: true);
  final pictures = metadata.pictures;
  Picture? cover;
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) {
      cover = picture;
      break;
    }
  }
  cover ??= pictures.isEmpty ? null : pictures.first;

  final tags = AudioTags(
    title: _clean(metadata.title),
    artist: _clean(metadata.artist),
    coverBytes: cover?.bytes,
    coverMimeType: cover?.mimetype,
    lyrics: metadata.lyrics?.trim().isEmpty ?? true ? null : metadata.lyrics,
    duration: metadata.duration == null || metadata.duration! <= Duration.zero
        ? null
        : metadata.duration,
  );
  if (tags.title == null &&
      tags.artist == null &&
      !tags.hasCover &&
      tags.lyrics == null &&
      tags.duration == null) {
    return null;
  }
  return tags;
}

String? _clean(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
