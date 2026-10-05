import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/collection_models.dart';
import '../theme/card_shapes.dart';
import '../theme/graffiti_surfaces.dart';
import '../ui/formatting.dart';
import 'now_playing_equalizer.dart';

/// One song in an album or playlist: number (or equalizer while playing),
/// title, artist and length. Long-press or ⋮ for actions; swipe right to
/// add to the queue.
class SongRow extends StatefulWidget {
  const SongRow({
    super.key,
    required this.track,
    required this.number,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.onShowActions,
    this.onSwipeToQueue,
    this.trailing,
    this.animateIn = true,
  });

  final Track track;

  /// 1-based position shown when the song isn't playing.
  final int number;

  /// The song is the current one (playing or paused).
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onShowActions;
  final VoidCallback? onSwipeToQueue;

  /// Extra trailing widget, e.g. a drag handle in playlists.
  final Widget? trailing;
  final bool animateIn;

  /// Only the first rows get the entrance animation; later ones would
  /// otherwise appear seconds after the page opens.
  static const int animatedRows = 8;

  @override
  State<SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<SongRow> {
  late bool _visible =
      !widget.animateIn || widget.number > SongRow.animatedRows;

  @override
  void initState() {
    super.initState();
    if (!_visible) {
      Future.delayed(Duration(milliseconds: 40 * widget.number), () {
        if (mounted) {
          setState(() => _visible = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final track = widget.track;
    final unavailable = !track.hasFile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visible = _visible || reduceMotion;

    final Widget leading;
    if (widget.isLoading) {
      leading = const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    } else if (widget.isActive && widget.isPlaying) {
      leading = NowPlayingEqualizer(size: 18, color: scheme.primary);
    } else if (unavailable) {
      leading = Icon(
        Icons.add_circle_outline,
        size: 20,
        color: scheme.onSurfaceVariant,
      );
    } else {
      leading = Text(
        '${widget.number}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: widget.isActive ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final subtitle = unavailable
        ? 'No audio file · tap to add'
        : [
            if (track.artist.isNotEmpty) track.artist,
            if (track.duration != null) formatTrackDuration(track.duration!),
          ].join(' · ');

    final shape = CardShapes.of(context).card(14);
    Widget row = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: shape,
        onTap: widget.onTap,
        onLongPress: widget.onShowActions == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onShowActions!();
              },
        child: Ink(
          decoration: ShapeDecoration(
            shape: shape.copyWith(
              side: BorderSide(
                color: widget.isActive ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            gradient: scheme.cardGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
            child: Row(
              children: [
                SizedBox(width: 40, child: Center(child: leading)),
                Expanded(
                  child: Opacity(
                    opacity: unavailable ? 0.55 : 1,
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
                            color: widget.isActive ? scheme.primary : null,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.onShowActions != null)
                  IconButton(
                    tooltip: 'Song options',
                    onPressed: widget.onShowActions,
                    icon: const Icon(Icons.more_vert),
                  ),
                ?widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onSwipeToQueue != null && !unavailable) {
      row = Dismissible(
        key: ValueKey('queue_swipe_${track.id}_${widget.number}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.3},
        confirmDismiss: (_) async {
          HapticFeedback.selectionClick();
          widget.onSwipeToQueue!();
          return false; // the row stays; the song is queued
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 18),
          decoration: ShapeDecoration(
            shape: shape,
            color: scheme.primary.withValues(alpha: 0.25),
          ),
          child: Row(
            children: [
              Icon(Icons.add_to_queue, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                'Add to queue',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0.12, 0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          child: row,
        ),
      ),
    );
  }
}
