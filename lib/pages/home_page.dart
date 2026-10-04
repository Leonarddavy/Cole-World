import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../services/smart_playlists.dart' show likedSongsEntryId;
import '../theme/graffiti_surfaces.dart';
import '../ui/collection_type_ui.dart';
import '../ui/formatting.dart';
import '../widgets/artwork_card.dart';
import '../widgets/now_playing_equalizer.dart';
import 'library_page.dart' show RecentTrackShortcut;

/// The landing tab: pick up where you left off and jump to what you play
/// most. On a fresh install it leads with importing music.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.entries,
    required this.smartPlaylists,
    required this.recentTracks,
    required this.nowPlaying,
    required this.isPlaying,
    required this.onOpenCollection,
    required this.onPlayTrack,
    required this.onTogglePlayback,
    required this.onOpenNowPlaying,
    required this.onSeeAll,
    required this.onImportMusic,
    this.now,
  });

  /// Stored collections (albums, singles, features, playlists).
  final List<CollectionEntry> entries;

  /// Liked Songs / On Repeat, when they have songs.
  final List<CollectionEntry> smartPlaylists;
  final List<RecentTrackShortcut> recentTracks;

  /// The loaded song, playing or paused.
  final RecentTrackShortcut? nowPlaying;
  final bool isPlaying;
  final ValueChanged<CollectionEntry> onOpenCollection;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;
  final VoidCallback onTogglePlayback;
  final VoidCallback onOpenNowPlaying;
  final ValueChanged<CollectionType> onSeeAll;
  final VoidCallback onImportMusic;

  /// For tests; defaults to the current time.
  final DateTime? now;

  String _greeting() {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 5) {
      return 'Late night';
    }
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  /// Liked Songs, On Repeat, then collections you played recently, then the
  /// rest — up to six, without repeats.
  List<CollectionEntry> _quickPicks() {
    final picks = <CollectionEntry>[];
    void add(CollectionEntry entry) {
      if (picks.length < 6 && picks.every((pick) => pick.id != entry.id)) {
        picks.add(entry);
      }
    }

    smartPlaylists.forEach(add);
    for (final recent in recentTracks) {
      if (!recent.entry.isSmart) {
        add(recent.entry);
      }
    }
    for (final entry in entries) {
      if (entry.tracks.any((track) => track.hasFile)) {
        add(entry);
      }
    }
    return picks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPlayableMusic = entries.any(
      (entry) => entry.tracks.any((track) => track.hasFile),
    );
    final picks = _quickPicks();
    final nowPlaying = this.nowPlaying;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(_greeting(), style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (!hasPlayableMusic) ...[
          _ImportMusicCard(onImport: onImportMusic),
          const SizedBox(height: 20),
        ],
        if (nowPlaying != null) ...[
          _ContinueListeningCard(
            item: nowPlaying,
            isPlaying: isPlaying,
            onOpen: onOpenNowPlaying,
            onToggle: onTogglePlayback,
          ),
          const SizedBox(height: 20),
        ],
        if (picks.isNotEmpty) ...[
          _QuickPicksGrid(picks: picks, onOpen: onOpenCollection),
          const SizedBox(height: 24),
        ],
        if (recentTracks.isNotEmpty) ...[
          _SectionHeader(title: 'Recently played'),
          const SizedBox(height: 10),
          _RecentSongsRail(items: recentTracks, onPlay: onPlayTrack),
          const SizedBox(height: 24),
        ],
        for (final type in const [
          CollectionType.playlist,
          CollectionType.album,
          CollectionType.single,
          CollectionType.feature,
        ])
          ..._collectionRail(type),
      ],
    );
  }

  List<Widget> _collectionRail(CollectionType type) {
    final items = [
      if (type == CollectionType.playlist) ...smartPlaylists,
      ...entries.where((entry) => entry.type == type),
    ];
    if (items.isEmpty) {
      return const [];
    }
    return [
      _SectionHeader(
        title: type == CollectionType.playlist
            ? 'Your playlists'
            : '${type.label}s',
        onSeeAll: () => onSeeAll(type),
      ),
      const SizedBox(height: 10),
      _CollectionRail(items: items, onOpen: onOpenCollection),
      const SizedBox(height: 24),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _ImportMusicCard extends StatelessWidget {
  const _ImportMusicCard({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(scheme.surfaceContainerHighest, scheme.primary, 0.3)!,
            scheme.surfaceContainer,
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.library_music_rounded, size: 36, color: scheme.primary),
            const SizedBox(height: 12),
            Text('Bring your music in', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'II.VI plays the music files on this device. Import a folder '
              'and it becomes an album, with titles, artists and covers read '
              'from the files.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Import music'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  const _ContinueListeningCard({
    required this.item,
    required this.isPlaying,
    required this.onOpen,
    required this.onToggle,
  });

  final RecentTrackShortcut item;
  final bool isPlaying;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: scheme.raisedGradient,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: ArtworkCard(
                    entry: item.entry,
                    imagePath: item.track.artworkPath,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPlaying) ...[
                            NowPlayingEqualizer(
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isPlaying ? 'NOW PLAYING' : 'CONTINUE LISTENING',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${item.track.artist} · ${item.entry.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: isPlaying ? 'Pause' : 'Resume',
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  onPressed: onToggle,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPicksGrid extends StatelessWidget {
  const _QuickPicksGrid({required this.picks, required this.onOpen});

  final List<CollectionEntry> picks;
  final ValueChanged<CollectionEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tileHeight = 16 + MediaQuery.textScalerOf(context).scale(40);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in picks)
              SizedBox(
                width: width,
                height: tileHeight.clamp(56.0, 96.0),
                child: Material(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(entry),
                    child: Row(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: entry.isSmart
                              ? _SmartPlaylistIcon(entry: entry)
                              : ArtworkCard(
                                  entry: entry,
                                  borderRadius: BorderRadius.zero,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Liked Songs and On Repeat get a recognizable icon tile rather than
/// whichever song cover happens to come first.
class _SmartPlaylistIcon extends StatelessWidget {
  const _SmartPlaylistIcon({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liked = entry.id == likedSongsEntryId;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: scheme.accentGradient),
      child: Icon(
        liked ? Icons.favorite_rounded : Icons.repeat_rounded,
        color: scheme.onPrimary,
      ),
    );
  }
}

class _RecentSongsRail extends StatelessWidget {
  const _RecentSongsRail({required this.items, required this.onPlay});

  final List<RecentTrackShortcut> items;
  final Future<void> Function(Track track, CollectionEntry entry) onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    const cover = 128.0;
    return SizedBox(
      height: cover + 12 + textScaler.scale(42),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: cover,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPlay(item.track, item.entry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: cover,
                    child: ArtworkCard(
                      entry: item.entry,
                      imagePath: item.track.artworkPath,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionRail extends StatelessWidget {
  const _CollectionRail({required this.items, required this.onOpen});

  final List<CollectionEntry> items;
  final ValueChanged<CollectionEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    const cover = 140.0;
    return SizedBox(
      height: cover + 12 + textScaler.scale(42),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final entry = items[index];
          return SizedBox(
            width: cover,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(entry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: cover,
                    child: entry.isSmart
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _SmartPlaylistIcon(entry: entry),
                          )
                        : ArtworkCard(
                            entry: entry,
                            borderRadius: BorderRadius.circular(12),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    entry.isSmart
                        ? 'Auto playlist'
                        : songCount(entry.tracks.length),
                    maxLines: 1,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
