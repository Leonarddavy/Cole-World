import 'package:flutter/material.dart';

import '../models/collection_models.dart';

extension CollectionTypeUi on CollectionType {
  String get label {
    switch (this) {
      case CollectionType.album:
        return 'Album';
      case CollectionType.single:
        return 'Single';
      case CollectionType.feature:
        return 'Feature';
      case CollectionType.playlist:
        return 'Playlist';
    }
  }

  IconData get icon {
    switch (this) {
      case CollectionType.album:
        return Icons.album;
      case CollectionType.single:
        return Icons.music_note;
      case CollectionType.feature:
        return Icons.mic;
      case CollectionType.playlist:
        return Icons.queue_music;
    }
  }

  bool get supportsMenuEdit {
    return this == CollectionType.album ||
        this == CollectionType.single ||
        this == CollectionType.playlist;
  }
}
