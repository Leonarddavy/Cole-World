import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/collection_models.dart';
import '../models/playback_models.dart';
import '../services/play_queue.dart';
import '../theme/graffiti_surfaces.dart';
import '../ui/collection_type_ui.dart';
import '../ui/formatting.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_backdrop.dart';
import '../widgets/mini_player_bar.dart' show nowPlayingCoverHeroTag;

/// The full player: cover sized to the screen, song, scrubber, controls and
/// an "Up next" strip that opens the queue as a pull-up sheet. Colors are
/// taken from the cover; swipe down to close.
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

  /// Shown when the song doesn't belong to a known collection.
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

  /// A downward flick faster than this (logical px/s) closes the player.
  static const double _dismissVelocity = 700;

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

  void _openQueueSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Theme(
        // Keep the cover-derived colors inside the sheet too.
        data: theme,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ValueListenableBuilder<PlayQueueView>(
              valueListenable: queueListenable,
              builder: (context, queue, _) => _QueueSheet(
                queue: queue,
                scrollController: scrollController,
                resolveEntry: resolveEntry,
                onJump: onJumpToQueueItem,
                onRemove: onRemoveFromQueue,
                onMove: onMoveQueueItem,
                onShowTrackDetails: onShowTrackDetails,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayQueueView>(
      valueListenable: queueListenable,
      builder: (context, queue, _) {
        return ValueListenableBuilder<Track?>(
          valueListenable: currentTrackListenable,
          builder: (context, track, _) {
            final current = queue.current;
            final entry = current == null
                ? null
                : resolveEntry(current.entryId);
            final contextId = queue.contextEntryId;
            final contextEntry = contextId == null
                ? null
                : resolveEntry(contextId);
            final artwork = artworkImageProvider(
              entry: entry,
              imagePath: track?.artworkPath,
            );
            return _ArtworkColors(
              artwork: artwork,
              child: Builder(
                builder: (context) => _buildPage(
                  context,
                  queue: queue,
                  track: track,
                  entry: entry,
                  contextEntry: contextEntry ?? entry,
                  artwork: artwork,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required PlayQueueView queue,
    required Track? track,
    required CollectionEntry? entry,
    required CollectionEntry? contextEntry,
    required ImageProvider? artwork,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > _dismissVelocity) {
            Navigator.maybePop(context);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: _NowPlayingBackdrop(artwork: artwork)),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    contextEntry: contextEntry,
                    fallbackTitle: title,
                    sleepTimerListenable: sleepTimerListenable,
                    onOpenLyrics: onOpenLyrics,
                    onOpenSleepTimer: () => _openSleepTimerSheet(context),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const sidePadding = 24.0;
                        // The cover takes what the controls leave over,
                        // so everything fits without scrolling on normal
                        // phones; very large text scrolls instead of
                        // cutting controls off.
                        final coverSize = min(
                          constraints.maxWidth - sidePadding * 2,
                          constraints.maxHeight * 0.44,
                        ).clamp(120.0, 560.0);
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: sidePadding,
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    SizedBox.square(
                                      dimension: coverSize,
                                      child: _Cover(entry: entry, track: track),
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 16),
                                    if (track != null)
                                      _TitleRow(
                                        track: track,
                                        likedTrackIdsListenable:
                                            likedTrackIdsListenable,
                                        onToggleLike: onToggleLike,
                                      )
                                    else
                                      Text(
                                        'Nothing is playing.',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    const SizedBox(height: 4),
                                    _PlaybackScrubber(
                                      positionStream: positionStream,
                                      durationStream: durationStream,
                                      onSeek: onSeek,
                                    ),
                                    _TransportControls(
                                      playerStateStream: playerStateStream,
                                      shuffleEnabledListenable:
                                          shuffleEnabledListenable,
                                      repeatModeListenable:
                                          repeatModeListenable,
                                      onTogglePlayback: onTogglePlayback,
                                      onSkipNext: onSkipNext,
                                      onSkipPrevious: onSkipPrevious,
                                      onToggleShuffle: onToggleShuffle,
                                      onCycleRepeat: onCycleRepeat,
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 8),
                                    _UpNextPeek(
                                      queue: queue,
                                      onOpen: () => _openQueueSheet(context),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Re-colors the player with accents taken from the current cover.
class _ArtworkColors extends StatefulWidget {
  const _ArtworkColors({required this.artwork, required this.child});

  final ImageProvider? artwork;
  final Widget child;

  @override
  State<_ArtworkColors> createState() => _ArtworkColorsState();
}

class _ArtworkColorsState extends State<_ArtworkColors> {
  ColorScheme? _fromArtwork;
  ImageProvider? _resolvedFor;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ArtworkColors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork != widget.artwork) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final artwork = widget.artwork;
    _resolvedFor = artwork;
    if (artwork == null) {
      if (_fromArtwork != null) {
        setState(() => _fromArtwork = null);
      }
      return;
    }
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: artwork,
        brightness: Brightness.dark,
      );
      if (mounted && _resolvedFor == artwork) {
        setState(() => _fromArtwork = scheme);
      }
    } catch (_) {
      // Unreadable cover: keep the app's own colors.
      if (mounted && _resolvedFor == artwork) {
        setState(() => _fromArtwork = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromArtwork = _fromArtwork;
    if (fromArtwork == null) {
      return widget.child;
    }
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: fromArtwork.primary,
          onPrimary: fromArtwork.onPrimary,
          secondary: fromArtwork.tertiary,
          onSecondary: fromArtwork.onTertiary,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A heavily blurred copy of the cover behind the player, or the regular
/// backdrop when there's no cover.
class _NowPlayingBackdrop extends StatelessWidget {
  const _NowPlayingBackdrop({required this.artwork});

  final ImageProvider? artwork;

  @override
  Widget build(BuildContext context) {
    final artwork = this.artwork;
    if (artwork == null) {
      return const GraffitiBackdrop();
    }
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 600),
      child: Stack(
        key: ValueKey(artwork),
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              // Blurred anyway, so a tiny decode is plenty.
              child: Image(
                image: ResizeImage(artwork, width: 96),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    scheme.primary.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.35),
                  ),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.contextEntry,
    required this.fallbackTitle,
    required this.sleepTimerListenable,
    required this.onOpenLyrics,
    required this.onOpenSleepTimer,
  });

  final CollectionEntry? contextEntry;
  final String fallbackTitle;
  final ValueListenable<SleepTimerState?> sleepTimerListenable;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contextEntry = this.contextEntry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close player',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  Text(
                    contextEntry == null
                        ? fallbackTitle.toUpperCase()
                        : 'PLAYING FROM ${contextEntry.type.label.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (contextEntry != null)
                    Text(
                      contextEntry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
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
                color: sleepTimer == null ? null : scheme.primary,
                onPressed: onOpenSleepTimer,
                icon: Icon(
                  sleepTimer == null ? Icons.bedtime_outlined : Icons.bedtime,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.entry, required this.track});

  final CollectionEntry? entry;
  final Track? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = this.entry;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: entry == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: scheme.artworkPlaceholderGradient,
              ),
              child: const Center(child: Icon(Icons.album, size: 72)),
            )
          : ArtworkCard(
              entry: entry,
              imagePath: track?.artworkPath,
              borderRadius: BorderRadius.circular(20),
              heroTag: nowPlayingCoverHeroTag,
            ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.track,
    required this.likedTrackIdsListenable,
    required this.onToggleLike,
  });

  final Track track;
  final ValueListenable<Set<String>> likedTrackIdsListenable;
  final ValueChanged<Track> onToggleLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(track.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        _LikeButton(
          track: track,
          likedTrackIdsListenable: likedTrackIdsListenable,
          onToggleLike: onToggleLike,
        ),
      ],
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
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: likedTrackIdsListenable,
      builder: (context, likedIds, _) {
        final liked = likedIds.contains(track.id);
        return IconButton(
          tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
          iconSize: 28,
          color: liked ? scheme.primary : scheme.onSurfaceVariant,
          onPressed: () {
            HapticFeedback.selectionClick();
            onToggleLike(track);
          },
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
        );
      },
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                    activeTrackColor: scheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: scheme.primary,
                    overlayColor: scheme.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMillis.toDouble(),
                    value: clampedMillis,
                    semanticFormatterCallback: (value) => formatTrackDuration(
                      Duration(milliseconds: value.round()),
                    ),
                    onChanged: enableSeek
                        ? (value) =>
                              onSeek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        formatTrackDuration(position),
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        formatTrackDuration(duration),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.playerStateStream,
    required this.shuffleEnabledListenable,
    required this.repeatModeListenable,
    required this.onTogglePlayback,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
  });

  final Stream<PlayerState> playerStateStream;
  final ValueListenable<bool> shuffleEnabledListenable;
  final ValueListenable<PlaybackRepeatMode> repeatModeListenable;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<PlayerState>(
      stream: playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState ?? ProcessingState.idle;
        final busy =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: shuffleEnabledListenable,
              builder: (context, shuffleEnabled, _) => IconButton(
                tooltip: shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
                isSelected: shuffleEnabled,
                color: shuffleEnabled
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onToggleShuffle();
                },
                icon: const Icon(Icons.shuffle_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Previous',
              iconSize: 40,
              onPressed: onSkipPrevious,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            SizedBox.square(
              dimension: 72,
              child: IconButton.filled(
                tooltip: playing ? 'Pause' : 'Play',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: busy
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onTogglePlayback();
                      },
                icon: busy
                    ? SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 40,
                      ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              iconSize: 40,
              onPressed: onSkipNext,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            ValueListenableBuilder<PlaybackRepeatMode>(
              valueListenable: repeatModeListenable,
              builder: (context, repeatMode, _) => IconButton(
                tooltip: switch (repeatMode) {
                  PlaybackRepeatMode.off => 'Repeat off',
                  PlaybackRepeatMode.all => 'Repeat all',
                  PlaybackRepeatMode.one => 'Repeat one',
                },
                isSelected: repeatMode != PlaybackRepeatMode.off,
                color: repeatMode == PlaybackRepeatMode.off
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onCycleRepeat();
                },
                icon: Icon(
                  repeatMode == PlaybackRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The "Next: song" strip that opens the full queue.
class _UpNextPeek extends StatelessWidget {
  const _UpNextPeek({required this.queue, required this.onOpen});

  final PlayQueueView queue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = [
      ...queue.upNextUserIndices,
      ...queue.upNextContextIndices,
    ];
    final next = upcoming.isEmpty ? null : queue.items[upcoming.first];

    return Semantics(
      button: true,
      label: next == null
          ? 'Open queue'
          : 'Open queue. Next: ${next.track.title}',
      excludeSemantics: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        next == null ? 'Queue' : 'Next: ${next.track.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        next == null
                            ? 'Nothing up next'
                            : '${upcoming.length} up next',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_up_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({
    required this.queue,
    required this.scrollController,
    required this.resolveEntry,
    required this.onJump,
    required this.onRemove,
    required this.onMove,
    required this.onShowTrackDetails,
  });

  final PlayQueueView queue;
  final ScrollController scrollController;
  final CollectionEntry? Function(String id) resolveEntry;
  final ValueChanged<String> onJump;
  final ValueChanged<String> onRemove;
  final void Function(String uid, int upcomingOffset) onMove;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = queue.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Queue', style: theme.textTheme.titleLarge),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _QueueTile(
              track: current.track,
              isActive: true,
              label: 'Now playing',
              onTap: null,
              onDetails: null,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _UpNextList(
              queue: queue,
              scrollController: scrollController,
              resolveEntry: resolveEntry,
              onJump: onJump,
              onRemove: onRemove,
              onMove: onMove,
              onShowTrackDetails: onShowTrackDetails,
            ),
          ),
        ),
      ],
    );
  }
}

enum _QueueTileAction { remove, details }

class _UpNextList extends StatelessWidget {
  const _UpNextList({
    required this.queue,
    required this.scrollController,
    required this.resolveEntry,
    required this.onJump,
    required this.onRemove,
    required this.onMove,
    required this.onShowTrackDetails,
  });

  final PlayQueueView queue;
  final ScrollController? scrollController;
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
      return ListView(
        controller: scrollController,
        children: [
          Text('No queue available.', style: theme.textTheme.bodySmall),
        ],
      );
    }
    final userIndices = queue.upNextUserIndices;
    final contextIndices = queue.upNextContextIndices;
    if (userIndices.isEmpty && contextIndices.isEmpty) {
      return ListView(
        controller: scrollController,
        children: [
          Text(
            'You\'re at the end of the queue.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    final contextId = queue.contextEntryId;
    final contextTitle = contextId == null
        ? null
        : resolveEntry(contextId)?.title;

    final upcoming = [...userIndices, ...contextIndices];

    Widget header(String label) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(label, style: theme.textTheme.labelLarge),
    );

    // Section headers ride along with the first song of each section, since
    // a reorderable list can only contain draggable items.
    return ReorderableListView.builder(
      scrollController: scrollController,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 24),
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
    this.label,
  });

  final Track track;
  final bool isActive;
  final bool isUserQueued;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;
  final VoidCallback? onRemove;
  final Widget? dragHandle;

  /// Small caption above the title, e.g. "Now playing".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? scheme.primary : scheme.outlineVariant,
            ),
            gradient: scheme.cardGradient,
          ),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.graphic_eq_rounded
                    : isUserQueued
                    ? Icons.playlist_add_check
                    : Icons.queue_music,
                size: 18,
                color: isActive ? scheme.primary : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null)
                      Text(
                        label!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
              if (onRemove != null || onDetails != null)
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

String _formatRemaining(Duration remaining) {
  final minutes = remaining.inMinutes;
  if (minutes >= 1) {
    return '$minutes min';
  }
  return '${remaining.inSeconds} sec';
}
