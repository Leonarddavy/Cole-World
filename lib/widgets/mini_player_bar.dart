import 'dart:math';

import 'package:flutter/material.dart';

import '../models/collection_models.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.duration,
    required this.position,
    required this.onToggle,
    required this.onSeek,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  final Track track;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final VoidCallback onToggle;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function() onSkipBack;
  final Future<void> Function() onSkipForward;

  @override
  Widget build(BuildContext context) {
    final maxMillis = duration.inMilliseconds <= 0
        ? 1
        : duration.inMilliseconds;
    final clampedMillis = min(position.inMilliseconds, maxMillis).toDouble();
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xEE1A1917),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          WaveformStrip(progress: progress.clamp(0.0, 1.0)),
          Slider(
            min: 0,
            max: maxMillis.toDouble(),
            value: clampedMillis,
            onChanged: duration.inMilliseconds <= 0
                ? null
                : (value) => onSeek(Duration(milliseconds: value.round())),
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
      ),
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
                      ? const Color(0xFFE5B65E)
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
