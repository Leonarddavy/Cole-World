import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import 'track_actions_sheet.dart';

/// A "⋮" button opening a song's actions: "Play next", "Add to queue" and
/// (optionally) "Add to playlist…".
class TrackQueueMenuButton extends StatelessWidget {
  const TrackQueueMenuButton({
    super.key,
    required this.track,
    required this.onPlayNext,
    required this.onAddToQueue,
    this.onAddToPlaylist,
    this.subtitle,
  });

  final Track track;
  final VoidCallback onPlayNext;
  final VoidCallback onAddToQueue;
  final VoidCallback? onAddToPlaylist;

  /// Shown under the title in the sheet, e.g. the collection name.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Song options',
      icon: const Icon(Icons.more_vert),
      onPressed: () => showTrackActionsSheet(
        context,
        track: track,
        subtitle: subtitle,
        actions: [
          TrackAction(
            icon: Icons.queue_play_next,
            label: 'Play next',
            onSelected: onPlayNext,
          ),
          TrackAction(
            icon: Icons.add_to_queue,
            label: 'Add to queue',
            onSelected: onAddToQueue,
          ),
          if (onAddToPlaylist != null)
            TrackAction(
              icon: Icons.playlist_add,
              label: 'Add to playlist…',
              onSelected: onAddToPlaylist!,
            ),
        ],
      ),
    );
  }
}
