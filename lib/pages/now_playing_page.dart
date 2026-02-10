import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/collection_models.dart';
import '../models/playback_models.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/now_playing_equalizer.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    this.title = 'Now Playing',
    required this.entry,
    required this.currentTrackListenable,
    required this.playerStateStream,
    required this.positionStream,
    required this.durationStream,
    required this.onPlayTrack,
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
  });

  final String title;
  final CollectionEntry? entry;
  final ValueListenable<Track?> currentTrackListenable;
  final Stream<PlayerState> playerStateStream;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final ValueListenable<List<Track>> queueListenable;
  final ValueListenable<bool> shuffleEnabledListenable;
  final ValueListenable<RepeatMode> repeatModeListenable;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GraffitiScaffold(
      appBar: AppBar(
        title: Text(title),
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
                  final busy = processing == ProcessingState.loading ||
                      processing == ProcessingState.buffering;
                  final isLoading = busy;

                  return ValueListenableBuilder<bool>(
                    valueListenable: shuffleEnabledListenable,
                    builder: (context, shuffleEnabled, _) {
                      return ValueListenableBuilder<RepeatMode>(
                        valueListenable: repeatModeListenable,
                        builder: (context, repeatMode, _) {
                          return ValueListenableBuilder<List<Track>>(
                            valueListenable: queueListenable,
                            builder: (context, queue, _) {
                              final currentIndex = currentTrack == null
                                  ? -1
                                  : queue.indexWhere(
                                      (track) =>
                                          track.id == currentTrack.id,
                                    );
                              final upNext = currentIndex >= 0 &&
                                      currentIndex < queue.length - 1
                                  ? queue.sublist(currentIndex + 1)
                                  : <Track>[];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NowPlayingHero(
                                    entry: entry,
                                    track: currentTrack,
                                  ),
                                  const SizedBox(height: 16),
                                  if (currentTrack != null) ...[
                                    Text(
                                      currentTrack.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                    Text(
                                      currentTrack.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ] else
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
                                        onPressed:
                                            isLoading ? null : onTogglePlayback,
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
                                        color: repeatMode == RepeatMode.off
                                            ? Colors.white70
                                            : theme.colorScheme.secondary,
                                        icon: Icon(
                                          repeatMode == RepeatMode.one
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
                                        const Icon(
                                          Icons.queue_music,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  if (shuffleEnabled)
                                    Text(
                                      'Shuffle is on',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final activeEntry = entry;
                                        if (activeEntry == null) {
                                          return Center(
                                            child: Text(
                                              'No queue available.',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          );
                                        }
                                        final entryValue = activeEntry;
                                        if (currentTrack != null &&
                                            upNext.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'You\'re at the end of the queue.',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          );
                                        }

                                        final showingFullQueue =
                                            upNext.isEmpty &&
                                                currentTrack == null;
                                        final visibleQueue =
                                            showingFullQueue ? queue : upNext;

                                        return ListView.separated(
                                          itemCount: visibleQueue.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(height: 6),
                                          itemBuilder: (context, index) {
                                            final track = visibleQueue[index];
                                            final isActive =
                                                track.id == currentTrack?.id;
                                            return _QueueTile(
                                              track: track,
                                              isActive: isActive,
                                              onTap: () =>
                                                  onPlayTrack(track, entryValue),
                                              onDetails: () =>
                                                  onShowTrackDetails(
                                                track,
                                                entryValue,
                                              ),
                                            );
                                          },
                                        );
                                      },
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

class _NowPlayingHero extends StatelessWidget {
  const _NowPlayingHero({
    required this.entry,
    required this.track,
  });

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
              child: const Center(
                child: Icon(Icons.album, size: 64),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium,
          ),
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
                    Text(
                      _formatDuration(position),
                      style: textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(duration),
                      style: textTheme.bodySmall,
                    ),
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

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.track,
    required this.isActive,
    required this.onTap,
    required this.onDetails,
  });

  final Track track;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;

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
                isActive ? Icons.music_note : Icons.queue_music,
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
              IconButton(
                tooltip: 'Track details',
                onPressed: onDetails,
                icon: const Icon(Icons.more_vert),
              ),
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
