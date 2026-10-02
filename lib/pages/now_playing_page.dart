import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/collection_models.dart';
import '../models/playback_models.dart';
import '../services/play_queue.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/now_playing_equalizer.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    this.title = 'Now Playing',
    required this.resolveEntry,
    required this.currentTrackListenable,
    required this.playerStateStream,
    required this.positionStream,
    required this.durationStream,
    required this.onJumpToQueueItem,
    required this.onRemoveFromQueue,
    required this.onMoveQueueItem,
    required this.onOpenLyrics,
    required this.onSeek,
    required this.onTogglePlayback,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.queueListenable,
    required this.shuffleEnabledListenable,
    required this.repeatModeListenable,
    required this.onShowTrackDetails,
    required this.likedTrackIdsListenable,
    required this.onToggleLike,
    required this.sleepTimerListenable,
    required this.onSetSleepTimer,
    required this.onSleepAtEndOfTrack,
  });

  final String title;
  final CollectionEntry? Function(String id) resolveEntry;
  final ValueListenable<Track?> currentTrackListenable;
  final Stream<PlayerState> playerStateStream;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final ValueChanged<String> onJumpToQueueItem;
  final ValueChanged<String> onRemoveFromQueue;

  /// Moves a song (by queue uid) to a position among the upcoming songs.
  final void Function(String uid, int upcomingOffset) onMoveQueueItem;
  final VoidCallback onOpenLyrics;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final ValueListenable<PlayQueueView> queueListenable;
  final ValueListenable<bool> shuffleEnabledListenable;
  final ValueListenable<PlaybackRepeatMode> repeatModeListenable;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;
  final ValueListenable<Set<String>> likedTrackIdsListenable;
  final ValueChanged<Track> onToggleLike;
  final ValueListenable<SleepTimerState?> sleepTimerListenable;

  /// Starts a sleep timer for the given duration, or cancels it with null.
  final ValueChanged<Duration?> onSetSleepTimer;
  final VoidCallback onSleepAtEndOfTrack;

  Future<void> _openSleepTimerSheet(BuildContext context) async {
    final active = sleepTimerListenable.value;
    final remaining = active?.remaining();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void choose(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Sleep timer'),
                subtitle: Text(
                  active == null
                      ? 'Stop the music after a while.'
                      : active.endOfTrack
                      ? 'Stopping at the end of this song.'
                      : 'Stopping in ${_formatRemaining(remaining!)}.',
                ),
              ),
              for (final minutes in const [15, 30, 45, 60])
                ListTile(
                  title: Text('$minutes minutes'),
                  onTap: () =>
                      choose(() => onSetSleepTimer(Duration(minutes: minutes))),
                ),
              ListTile(
                title: const Text('End of this song'),
                onTap: () => choose(onSleepAtEndOfTrack),
              ),
              if (active != null)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Turn off timer'),
                  onTap: () => choose(() => onSetSleepTimer(null)),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GraffitiScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Lyrics',
            onPressed: onOpenLyrics,
            icon: const Icon(Icons.lyrics_outlined),
          ),
          ValueListenableBuilder<SleepTimerState?>(
            valueListenable: sleepTimerListenable,
            builder: (context, sleepTimer, _) {
              return IconButton(
                tooltip: sleepTimer == null
                    ? 'Sleep timer'
                    : 'Sleep timer (on)',
                color: sleepTimer == null
                    ? null
                    : Theme.of(context).colorScheme.secondary,
                onPressed: () => _openSleepTimerSheet(context),
                icon: Icon(
                  sleepTimer == null ? Icons.bedtime_outlined : Icons.bedtime,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: ValueListenableBuilder<Track?>(
            valueListenable: currentTrackListenable,
            builder: (context, currentTrack, _) {
              return StreamBuilder<PlayerState>(
                stream: playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing = state?.playing ?? false;
                  final processing =
                      state?.processingState ?? ProcessingState.idle;
                  final busy =
                      processing == ProcessingState.loading ||
                      processing == ProcessingState.buffering;
                  final isLoading = busy;

                  return ValueListenableBuilder<bool>(
                    valueListenable: shuffleEnabledListenable,
                    builder: (context, shuffleEnabled, _) {
                      return ValueListenableBuilder<PlaybackRepeatMode>(
                        valueListenable: repeatModeListenable,
                        builder: (context, repeatMode, _) {
                          return ValueListenableBuilder<PlayQueueView>(
                            valueListenable: queueListenable,
                            builder: (context, queue, _) {
                              final currentEntryId = queue.current?.entryId;
                              final entry = currentEntryId == null
                                  ? null
                                  : resolveEntry(currentEntryId);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NowPlayingHero(
                                    entry: entry,
                                    track: currentTrack,
                                  ),
                                  const SizedBox(height: 16),
                                  if (currentTrack != null)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                currentTrack.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                              Text(
                                                currentTrack.artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        _LikeButton(
                                          track: currentTrack,
                                          likedTrackIdsListenable:
                                              likedTrackIdsListenable,
                                          onToggleLike: onToggleLike,
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      'No track selected.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  const SizedBox(height: 12),
                                  _PlaybackScrubber(
                                    positionStream: positionStream,
                                    durationStream: durationStream,
                                    onSeek: onSeek,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        tooltip: 'Shuffle',
                                        iconSize: 22,
                                        onPressed: onToggleShuffle,
                                        color: shuffleEnabled
                                            ? theme.colorScheme.secondary
                                            : Colors.white70,
                                        icon: const Icon(Icons.shuffle),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Previous',
                                        iconSize: 36,
                                        onPressed: onSkipPrevious,
                                        icon: const Icon(
                                          Icons.skip_previous_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: playing ? 'Pause' : 'Play',
                                        iconSize: 58,
                                        onPressed: isLoading
                                            ? null
                                            : onTogglePlayback,
                                        icon: isLoading
                                            ? const SizedBox(
                                                width: 44,
                                                height: 44,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 3,
                                                    ),
                                              )
                                            : Icon(
                                                playing
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                              ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: 'Next',
                                        iconSize: 36,
                                        onPressed: onSkipNext,
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Repeat',
                                        iconSize: 22,
                                        onPressed: onCycleRepeat,
                                        color:
                                            repeatMode == PlaybackRepeatMode.off
                                            ? Colors.white70
                                            : theme.colorScheme.secondary,
                                        icon: Icon(
                                          repeatMode == PlaybackRepeatMode.one
                                              ? Icons.repeat_one
                                              : Icons.repeat,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Up Next',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const Spacer(),
                                      if (playing)
                                        const NowPlayingEqualizer(size: 18)
                                      else
                                        const Icon(Icons.queue_music, size: 18),
                                    ],
                                  ),
                                  if (shuffleEnabled)
                                    Text(
                                      'Shuffle is on',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _UpNextList(
                                      queue: queue,
                                      resolveEntry: resolveEntry,
                                      onJump: onJumpToQueueItem,
                                      onRemove: onRemoveFromQueue,
                                      onMove: onMoveQueueItem,
                                      onShowTrackDetails: onShowTrackDetails,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.track,
    required this.likedTrackIdsListenable,
    required this.onToggleLike,
  });

  final Track track;
  final ValueListenable<Set<String>> likedTrackIdsListenable;
  final ValueChanged<Track> onToggleLike;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: likedTrackIdsListenable,
      builder: (context, likedIds, _) {
        final liked = likedIds.contains(track.id);
        return IconButton(
          tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
          iconSize: 28,
          color: liked ? const Color(0xFFFFB547) : Colors.white70,
          onPressed: () => onToggleLike(track),
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
        );
      },
    );
  }
}

class _NowPlayingHero extends StatelessWidget {
  const _NowPlayingHero({required this.entry, required this.track});

  final CollectionEntry? entry;
  final Track? track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = entry == null
        ? 'Unknown Collection'
        : '${entry!.title} (${entry!.type.label})';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A12), Color(0xFF0F0B09)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry != null)
            SizedBox(
              height: 240,
              child: ArtworkCard(
                entry: entry!,
                imagePath: track?.artworkPath,
                borderRadius: BorderRadius.circular(22),
                heroTag: 'now_playing_${entry!.id}',
              ),
            )
          else
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A2A17), Color(0xFF15110E)],
                ),
              ),
              child: const Center(child: Icon(Icons.album, size: 64)),
            ),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.titleMedium),
          if (track != null) ...[
            const SizedBox(height: 4),
            Text(
              track!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaybackScrubber extends StatelessWidget {
  const _PlaybackScrubber({
    required this.positionStream,
    required this.durationStream,
    required this.onSeek,
  });

  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final Future<void> Function(Duration position) onSeek;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<Duration?>(
      stream: durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMillis = duration.inMilliseconds <= 0
                ? 1
                : duration.inMilliseconds;
            final clampedMillis = position.inMilliseconds
                .clamp(0, maxMillis)
                .toDouble();
            final enableSeek = duration.inMilliseconds > 0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFB547),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFF2EE6D6),
                    overlayColor: const Color(0x332EE6D6),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMillis.toDouble(),
                    value: clampedMillis,
                    onChanged: enableSeek
                        ? (value) =>
                              onSeek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Text(_formatDuration(position), style: textTheme.bodySmall),
                    const Spacer(),
                    Text(_formatDuration(duration), style: textTheme.bodySmall),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

enum _QueueTileAction { remove, details }

class _UpNextList extends StatelessWidget {
  const _UpNextList({
    required this.queue,
    required this.resolveEntry,
    required this.onJump,
    required this.onRemove,
    required this.onMove,
    required this.onShowTrackDetails,
  });

  final PlayQueueView queue;
  final CollectionEntry? Function(String id) resolveEntry;
  final ValueChanged<String> onJump;
  final ValueChanged<String> onRemove;
  final void Function(String uid, int upcomingOffset) onMove;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (queue.current == null) {
      return Center(
        child: Text('No queue available.', style: theme.textTheme.bodySmall),
      );
    }
    final userIndices = queue.upNextUserIndices;
    final contextIndices = queue.upNextContextIndices;
    if (userIndices.isEmpty && contextIndices.isEmpty) {
      return Center(
        child: Text(
          'You\'re at the end of the queue.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final contextId = queue.contextEntryId;
    final contextTitle = contextId == null
        ? null
        : resolveEntry(contextId)?.title;

    final upcoming = [...userIndices, ...contextIndices];

    Widget header(String label) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(label, style: theme.textTheme.labelLarge),
    );

    // Section headers ride along with the first song of each section, since
    // a reorderable list can only contain draggable items.
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: upcoming.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        onMove(queue.items[upcoming[oldIndex]].uid, newIndex);
      },
      itemBuilder: (context, position) {
        final index = upcoming[position];
        final item = queue.items[index];
        final entry = resolveEntry(item.entryId);
        final String? sectionLabel;
        if (position == 0 && item.userQueued) {
          sectionLabel = 'Next in queue';
        } else if (!item.userQueued &&
            (position == 0 || queue.items[upcoming[position - 1]].userQueued)) {
          sectionLabel = contextTitle == null
              ? 'Next up'
              : 'Next from: $contextTitle';
        } else {
          sectionLabel = null;
        }
        return Padding(
          key: ValueKey(item.uid),
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sectionLabel != null) header(sectionLabel),
              _QueueTile(
                track: item.track,
                isActive: false,
                isUserQueued: item.userQueued,
                onTap: () => onJump(item.uid),
                onRemove: () => onRemove(item.uid),
                onDetails: entry == null
                    ? null
                    : () => onShowTrackDetails(item.track, entry),
                dragHandle: ReorderableDragStartListener(
                  index: position,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.track,
    required this.isActive,
    required this.onTap,
    required this.onDetails,
    this.isUserQueued = false,
    this.onRemove,
    this.dragHandle,
  });

  final Track track;
  final bool isActive;
  final bool isUserQueued;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;
  final VoidCallback? onRemove;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFFFB547) : Colors.white12;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1511), Color(0xFF120E0B)],
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.music_note
                    : isUserQueued
                    ? Icons.playlist_add_check
                    : Icons.queue_music,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isActive) const NowPlayingEqualizer(size: 16),
              PopupMenuButton<_QueueTileAction>(
                tooltip: 'Queue options',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case _QueueTileAction.remove:
                      onRemove?.call();
                    case _QueueTileAction.details:
                      onDetails?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onRemove != null)
                    const PopupMenuItem(
                      value: _QueueTileAction.remove,
                      child: Text('Remove from queue'),
                    ),
                  if (onDetails != null)
                    const PopupMenuItem(
                      value: _QueueTileAction.details,
                      child: Text('Details'),
                    ),
                ],
              ),
              ?dragHandle,
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration == Duration.zero) {
    return '0:00';
  }
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatRemaining(Duration remaining) {
  final minutes = remaining.inMinutes;
  if (minutes >= 1) {
    return '$minutes min';
  }
  return '${remaining.inSeconds} sec';
}
