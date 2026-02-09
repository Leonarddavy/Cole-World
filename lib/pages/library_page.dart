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
