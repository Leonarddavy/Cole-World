import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.tabType,
    required this.entries,
    required this.onOpen,
    required this.onCreateCollection,
    required this.onUploadToCollection,
    required this.onMenuAction,
  });

  final CollectionType tabType;
  final List<CollectionEntry> entries;
  final void Function(CollectionEntry entry) onOpen;
  final VoidCallback onCreateCollection;
  final VoidCallback onUploadToCollection;
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
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${tabType.label}s',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (entries.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No entries yet')),
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
          color: Colors.white.withValues(alpha: 0.05),
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
                  if (onMenuAction != null && entry.type.supportsMenuEdit)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: PopupMenuButton<EntryMenuAction>(
                        tooltip: 'Collection actions',
                        icon: const Icon(Icons.menu_rounded),
                        color: const Color(0xFF2A231B),
                        onSelected: onMenuAction,
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: EntryMenuAction.open,
                            child: Text('Open'),
                          ),
                          PopupMenuItem(
                            value: EntryMenuAction.uploadSongs,
                            child: Text('Upload Songs'),
                          ),
                          PopupMenuItem(
                            value: EntryMenuAction.editThumbnail,
                            child: Text('Edit Thumbnail'),
                          ),
                        ],
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
