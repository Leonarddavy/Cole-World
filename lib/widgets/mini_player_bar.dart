import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import 'artwork_card.dart';
import 'now_playing_equalizer.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.track,
    this.entry,
    required this.isPlaying,
    required this.isLoading,
    required this.isBuffering,
    required this.durationListenable,
    required this.positionListenable,
    required this.onToggle,
    required this.onSeek,
    required this.onSkipBack,
    required this.onSkipForward,
    this.onOpenNowPlaying,
    this.isExpanded = true,
    this.onToggleSize,
  });

  final Track track;
  final CollectionEntry? entry;
  final bool isPlaying;
  final bool isLoading;
  final bool isBuffering;
  final ValueListenable<Duration> durationListenable;
  final ValueListenable<Duration> positionListenable;
  final VoidCallback onToggle;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function() onSkipBack;
  final Future<void> Function() onSkipForward;
  final VoidCallback? onOpenNowPlaying;
  final bool isExpanded;
  final VoidCallback? onToggleSize;

  @override
  Widget build(BuildContext context) {
    final busy = isLoading || isBuffering;

    return ValueListenableBuilder<Duration>(
      valueListenable: durationListenable,
      builder: (context, duration, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: positionListenable,
          builder: (context, position, _) {
            final maxMillis = duration.inMilliseconds <= 0
                ? 1
                : duration.inMilliseconds;
            final clampedMillis =
                min(position.inMilliseconds, maxMillis).toDouble();
            final progress = duration.inMilliseconds <= 0
                ? 0.0
                : position.inMilliseconds / duration.inMilliseconds;

            return AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F1812), Color(0xFF17110D)],
                  ),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 12,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (entry != null)
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: ArtworkCard(
                              entry: entry!,
                              borderRadius: BorderRadius.circular(12),
                              heroTag: 'now_playing_${entry!.id}',
                            ),
                          )
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: isPlaying && !isLoading
                                ? NowPlayingEqualizer(
                                    key: const ValueKey('eq'),
                                    isActive: !isBuffering,
                                  )
                                : const Icon(
                                    Icons.graphic_eq,
                                    key: ValueKey('eq_icon'),
                                    size: 20,
                                  ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onOpenNowPlaying,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isExpanded)
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isExpanded ? 'Collapse' : 'Expand',
                          onPressed: onToggleSize,
                          icon: Icon(
                            isExpanded ? Icons.expand_more : Icons.expand_less,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading ? null : onToggle,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: busy
                                ? const SizedBox(
                                    key: ValueKey('busy'),
                                    width: 26,
                                    height: 26,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2.6),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    key: ValueKey(isPlaying ? 'pause' : 'play'),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 4),
                      WaveformStrip(progress: progress.clamp(0.0, 1.0)),
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
                          onChanged: duration.inMilliseconds <= 0
                              ? null
                              : (value) =>
                                    onSeek(Duration(milliseconds: value.round())),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => onSkipBack(),
                            icon: const Icon(Icons.replay_10),
                          ),
                          IconButton(
                            onPressed: () => onSkipForward(),
                            icon: const Icon(Icons.forward_10),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class WaveformStrip extends StatelessWidget {
  const WaveformStrip({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const barHeights = [
      8.0,
      14.0,
      10.0,
      18.0,
      11.0,
      16.0,
      9.0,
      15.0,
      12.0,
      19.0,
      10.0,
      14.0,
    ];

    return SizedBox(
      height: 20,
      child: Row(
        children: [
          for (int i = 0; i < barHeights.length; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: barHeights[i],
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i / (barHeights.length - 1) <= progress
                      ? const Color(0xFF2EE6D6)
                      : Colors.white24,
                ),
              ),
            ),
        ],
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
