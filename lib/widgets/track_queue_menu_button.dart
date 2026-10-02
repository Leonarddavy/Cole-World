import 'package:flutter/material.dart';

enum _QueueMenuAction { playNext, addToQueue }

/// A "⋮" button offering "Play next" and "Add to queue" for one song.
class TrackQueueMenuButton extends StatelessWidget {
  const TrackQueueMenuButton({
    super.key,
    required this.onPlayNext,
    required this.onAddToQueue,
  });

  final VoidCallback onPlayNext;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_QueueMenuAction>(
      tooltip: 'Queue options',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _QueueMenuAction.playNext:
            onPlayNext();
          case _QueueMenuAction.addToQueue:
            onAddToQueue();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _QueueMenuAction.playNext,
          child: ListTile(
            leading: Icon(Icons.queue_play_next),
            title: Text('Play next'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _QueueMenuAction.addToQueue,
          child: ListTile(
            leading: Icon(Icons.add_to_queue),
            title: Text('Add to queue'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
