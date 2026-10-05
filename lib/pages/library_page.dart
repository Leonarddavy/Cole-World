import 'dart:math';

import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../theme/card_shapes.dart';
import '../theme/graffiti_surfaces.dart';
import '../ui/collection_type_ui.dart';
import '../ui/formatting.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_tag.dart';
import '../widgets/track_queue_menu_button.dart';

/// A song shortcut with the collection it was played from.
class RecentTrackShortcut {
  const RecentTrackShortcut({required this.entry, required this.track});

  final CollectionEntry entry;
  final Track track;
}

/// One collection type (albums, singles, …): Play/Shuffle, recently played,
/// and a grid of square covers.
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.tabType,
    required this.entries,
    required this.recentTracks,
    required this.onOpen,
    required this.onPlayRecentTrack,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
    required this.onCreateCollection,
    required this.onUploadToCollection,
    this.onPlayAll,
    this.onShufflePlay,
    required this.onMenuAction,
  });

  final CollectionType tabType;
  final List<CollectionEntry> entries;
  final List<RecentTrackShortcut> recentTracks;
  final void Function(CollectionEntry entry) onOpen;
  final Future<void> Function(Track track, CollectionEntry entry)
  onPlayRecentTrack;
  final Future<void> Function(Track track, CollectionEntry entry)? onPlayNext;
  final Future<void> Function(Track track, CollectionEntry entry)? onAddToQueue;
  final Future<void> Function(Track track, CollectionEntry entry)?
  onAddToPlaylist;
  final VoidCallback onCreateCollection;
  final VoidCallback onUploadToCollection;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShufflePlay;
  final void Function(CollectionEntry entry, EntryMenuAction action)?
  onMenuAction;

  void _showAddSheet(BuildContext context) {
    final label = tabType.label.toLowerCase();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void choose(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.library_add),
                title: Text('New $label'),
                subtitle: Text('Name it, add a cover and songs'),
                onTap: () => choose(onCreateCollection),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text('Upload songs to a $label'),
                subtitle: const Text('Pick audio files or a whole folder'),
                onTap: () => choose(onUploadToCollection),
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
    final label = tabType.label;
    final stored = entries.where((entry) => !entry.isSmart);
    final songTotal = stored.fold<int>(
      0,
      (sum, entry) => sum + entry.tracks.length,
    );
    final summary = entries.isEmpty
        ? 'Nothing here yet'
        : '${stored.length} ${label.toLowerCase()}${stored.length == 1 ? '' : 's'}'
              ' · ${songCount(songTotal)}';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GraffitiTag(label: '$label Vault'),
                const SizedBox(height: 10),
                Text('${label}s', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(summary, style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (onPlayAll != null)
                      FilledButton.icon(
                        onPressed: onPlayAll,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    if (onPlayAll != null && onShufflePlay != null)
                      const SizedBox(width: 8),
                    if (onShufflePlay != null)
                      FilledButton.tonalIcon(
                        onPressed: onShufflePlay,
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Add or upload',
                      onPressed: () => _showAddSheet(context),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (recentTracks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _RecentlyPlayedRail(
                recentTracks: recentTracks,
                onPlayTrack: onPlayRecentTrack,
                onPlayNext: onPlayNext,
                onAddToQueue: onAddToQueue,
                onAddToPlaylist: onAddToPlaylist,
              ),
            ),
          ),
        if (entries.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyLibrary(label: label, onCreate: onCreateCollection),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final width = constraints.crossAxisExtent;
                // Two columns on phones, more as the screen widens.
                final columns = max(2, (width / 190).floor());
                final tileWidth = (width - spacing * (columns - 1)) / columns;
                final textScaler = MediaQuery.textScalerOf(context);
                final captionHeight =
                    10 + textScaler.scale(22) + 2 + textScaler.scale(16) + 6;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: spacing,
                    mainAxisExtent: tileWidth + captionHeight,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = entries[index];
                    return _CollectionCard(
                      entry: entry,
                      onOpen: () => onOpen(entry),
                      onMenuAction: onMenuAction == null || entry.isSmart
                          ? null
                          : (action) => onMenuAction!(entry, action),
                    );
                  }, childCount: entries.length),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.entry,
    required this.onOpen,
    required this.onMenuAction,
  });

  final CollectionEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<EntryMenuAction>? onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = entry.featuredArtists
        .where((name) => !name.toLowerCase().startsWith('no official'))
        .toList();
    final subtitle = entry.isSmart
        ? 'Auto playlist · ${songCount(entry.tracks.length)}'
        : featured.isNotEmpty
        ? featured.join(', ')
        : songCount(entry.tracks.length);

    return Semantics(
      button: true,
      label: '${entry.title}, ${entry.type.label}, $subtitle',
      excludeSemantics: onMenuAction == null,
      child: InkWell(
        onTap: onOpen,
        customBorder: CardShapes.of(context).card(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArtworkCard(
                    entry: entry,
                    borderRadius: BorderRadius.circular(14),
                    heroTag: 'cover_${entry.id}',
                  ),
                  if (onMenuAction != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _CardMenuButton(
                        entry: entry,
                        onSelected: onMenuAction!,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMenuButton extends StatelessWidget {
  const _CardMenuButton({required this.entry, required this.onSelected});

  final CollectionEntry entry;
  final ValueChanged<EntryMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: PopupMenuButton<EntryMenuAction>(
        tooltip: '${entry.type.label} options',
        icon: const Icon(Icons.more_vert, size: 20, color: Colors.white),
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        itemBuilder: (context) => [
          const PopupMenuItem(value: EntryMenuAction.open, child: Text('Open')),
          if (entry.type == CollectionType.playlist)
            const PopupMenuItem(
              value: EntryMenuAction.addFromLibrary,
              child: Text('Add Songs From Library'),
            ),
          if (entry.type.supportsMenuEdit) ...const [
            PopupMenuItem(
              value: EntryMenuAction.uploadSongs,
              child: Text('Upload Songs'),
            ),
            PopupMenuItem(
              value: EntryMenuAction.editThumbnail,
              child: Text('Edit Thumbnail'),
            ),
          ],
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: EntryMenuAction.deleteCollection,
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.label, required this.onCreate});

  final String label;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No ${label.toLowerCase()}s yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Create one and add songs from your device.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.library_add),
            label: Text('New ${label.toLowerCase()}'),
          ),
        ],
      ),
    );
  }
}

class _RecentlyPlayedRail extends StatelessWidget {
  const _RecentlyPlayedRail({
    required this.recentTracks,
    required this.onPlayTrack,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
  });

  final List<RecentTrackShortcut> recentTracks;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;
  final Future<void> Function(Track track, CollectionEntry entry)? onPlayNext;
  final Future<void> Function(Track track, CollectionEntry entry)? onAddToQueue;
  final Future<void> Function(Track track, CollectionEntry entry)?
  onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Grows with the user's text size instead of clipping.
    final railHeight = max(
      72.0,
      24 + MediaQuery.textScalerOf(context).scale(44),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recently played', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentTracks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = recentTracks[index];
              return SizedBox(
                width: 260,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: CardShapes.of(context).card(14),
                    onTap: () => onPlayTrack(item.track, item.entry),
                    child: Ink(
                      decoration: ShapeDecoration(
                        shape: CardShapes.of(context).card(
                          14,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        gradient: scheme.cardGradient,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          SizedBox.square(
                            dimension: 48,
                            child: ArtworkCard(
                              entry: item.entry,
                              imagePath: item.track.artworkPath,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (onPlayNext != null && onAddToQueue != null)
                            TrackQueueMenuButton(
                              track: item.track,
                              subtitle: item.entry.title,
                              onPlayNext: () =>
                                  onPlayNext!(item.track, item.entry),
                              onAddToQueue: () =>
                                  onAddToQueue!(item.track, item.entry),
                              onAddToPlaylist: onAddToPlaylist == null
                                  ? null
                                  : () => onAddToPlaylist!(
                                      item.track,
                                      item.entry,
                                    ),
                            )
                          else
                            const SizedBox(width: 8),
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
    );
  }
}
