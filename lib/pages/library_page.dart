import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_tag.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.tabType,
    required this.entries,
    required this.recentTracks,
    required this.onOpen,
    required this.onPlayRecentTrack,
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
  final VoidCallback onCreateCollection;
  final VoidCallback onUploadToCollection;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShufflePlay;
  final void Function(CollectionEntry entry, EntryMenuAction action)?
  onMenuAction;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateCollection,
                  icon: const Icon(Icons.library_add),
                  label: Text('Add ${tabType.label}'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onUploadToCollection,
                  icon: const Icon(Icons.upload_file),
                  label: Text('Upload To ${tabType.label}'),
                ),
                if (onPlayAll != null)
                  FilledButton.tonalIcon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play All'),
                  ),
                if (onShufflePlay != null)
                  FilledButton.tonalIcon(
                    onPressed: onShufflePlay,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Shuffle'),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GraffitiTag(label: '${tabType.label} Vault'),
                const SizedBox(height: 12),
                Text(
                  '${tabType.label}s',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Curate, upload, and hit play on every drop.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (recentTracks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _RecentlyPlayedRail(
                recentTracks: recentTracks,
                onPlayTrack: onPlayRecentTrack,
              ),
            ),
          ),
        if (entries.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No entries yet. Add one to start.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = entries[index];
                return _PortraitCollectionCard(
                  entry: entry,
                  onOpen: () => onOpen(entry),
                  onMenuAction: onMenuAction == null
                      ? null
                      : (action) => onMenuAction!(entry, action),
                );
              }, childCount: entries.length),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class RecentTrackShortcut {
  const RecentTrackShortcut({
    required this.entry,
    required this.track,
  });

  final CollectionEntry entry;
  final Track track;
}

class _PortraitCollectionCard extends StatelessWidget {
  const _PortraitCollectionCard({
    required this.entry,
    required this.onOpen,
    required this.onMenuAction,
  });

  final CollectionEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<EntryMenuAction>? onMenuAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1812), Color(0xFF15100C)],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ArtworkCard(
                      entry: entry,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      heroTag: 'cover_${entry.id}',
                    ),
                  ),
                  if (onMenuAction != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: PopupMenuButton<EntryMenuAction>(
                        tooltip: 'Collection actions',
                        icon: const Icon(Icons.menu_rounded),
                        color: const Color(0xFF251D15),
                        onSelected: onMenuAction,
                        itemBuilder: (context) {
                          final items = <PopupMenuEntry<EntryMenuAction>>[
                            const PopupMenuItem(
                              value: EntryMenuAction.open,
                              child: Text('Open'),
                            ),
                          ];
                          if (entry.type.supportsMenuEdit) {
                            items.addAll(const [
                              PopupMenuItem(
                                value: EntryMenuAction.uploadSongs,
                                child: Text('Upload Songs'),
                              ),
                              PopupMenuItem(
                                value: EntryMenuAction.editThumbnail,
                                child: Text('Edit Thumbnail'),
                              ),
                              PopupMenuDivider(),
                            ]);
                          } else {
                            items.add(const PopupMenuDivider());
                          }
                          items.add(
                            const PopupMenuItem(
                              value: EntryMenuAction.deleteCollection,
                              child: Text('Delete'),
                            ),
                          );
                          return items;
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.featuredArtists.isEmpty
                        ? entry.type.label
                        : entry.featuredArtists.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _RecentlyPlayedRail extends StatelessWidget {
  const _RecentlyPlayedRail({
    required this.recentTracks,
    required this.onPlayTrack,
  });

  final List<RecentTrackShortcut> recentTracks;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const GraffitiTag(label: 'Recently Played'),
            const Spacer(),
            Text(
              '${recentTracks.length} track(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentTracks.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = recentTracks[index];
              return SizedBox(
                width: 240,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onPlayTrack(item.track, item.entry),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF201812), Color(0xFF17110D)],
                        ),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 20),
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
                                ),
                                Text(
                                  '${item.entry.title} • ${item.entry.type.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Play',
                            onPressed: () => onPlayTrack(item.track, item.entry),
                            icon: const Icon(Icons.play_arrow),
                          ),
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
