import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/collection_models.dart';
import '../theme/graffiti_surfaces.dart';
import 'artwork_card.dart';
import 'now_playing_equalizer.dart';

/// Shared with Now Playing so the cover flies between the two.
const String nowPlayingCoverHeroTag = 'now_playing_cover';

/// A slim player pinned above the navigation: cover, song, like, play/pause
/// and a thin progress line. Tap to open Now Playing; swipe sideways to skip.
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
    required this.onPrevious,
    required this.onNext,
    required this.isLiked,
    required this.onToggleLike,
    this.onOpenNowPlaying,
  });

  final Track track;
  final CollectionEntry? entry;
  final bool isPlaying;
  final bool isLoading;
  final bool isBuffering;
  final ValueListenable<Duration> durationListenable;
  final ValueListenable<Duration> positionListenable;
  final VoidCallback onToggle;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final bool isLiked;
  final VoidCallback onToggleLike;
  final VoidCallback? onOpenNowPlaying;

  /// A flick faster than this (logical px/s) skips a song.
  static const double _skipVelocity = 300;

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _skipVelocity) {
      return;
    }
    HapticFeedback.selectionClick();
    if (velocity < 0) {
      onNext();
    } else {
      onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = isLoading || isBuffering;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Semantics(
        container: true,
        button: true,
        label: 'Now playing: ${track.title}, ${track.artist}',
        hint: 'Opens the player',
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Next song'): () => onNext(),
          const CustomSemanticsAction(label: 'Previous song'): () =>
              onPrevious(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpenNowPlaying,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: scheme.raisedGradient,
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 44,
                          child: entry == null
                              ? Center(
                                  child: NowPlayingEqualizer(
                                    isActive: isPlaying && !busy,
                                  ),
                                )
                              : ArtworkCard(
                                  entry: entry!,
                                  imagePath: track.artworkPath,
                                  borderRadius: BorderRadius.circular(10),
                                  heroTag: nowPlayingCoverHeroTag,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            child: ExcludeSemantics(
                              key: ValueKey(track.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isLiked
                              ? 'Remove from Liked Songs'
                              : 'Add to Liked Songs',
                          color: isLiked
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onToggleLike();
                          },
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                        ),
                        IconButton(
                          tooltip: isPlaying ? 'Pause' : 'Play',
                          onPressed: isLoading
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  onToggle();
                                },
                          icon: busy
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 32,
                                ),
                        ),
                      ],
                    ),
                  ),
                  _ProgressLine(
                    durationListenable: durationListenable,
                    positionListenable: positionListenable,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.durationListenable,
    required this.positionListenable,
    required this.color,
  });

  final ValueListenable<Duration> durationListenable;
  final ValueListenable<Duration> positionListenable;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: durationListenable,
      builder: (context, duration, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: positionListenable,
          builder: (context, position, _) {
            final total = duration.inMilliseconds;
            final progress = total <= 0
                ? 0.0
                : (position.inMilliseconds / total).clamp(0.0, 1.0);
            return LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              color: color,
              backgroundColor: Colors.white12,
            );
          },
        );
      },
    );
  }
}
