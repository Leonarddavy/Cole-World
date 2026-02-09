import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/graffiti_tag.dart';
import '../widgets/staggered_song_tile.dart';

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.entry,
    required this.currentTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onReorderTracks,
    required this.onDeleteTrack,
    required this.onMenuAction,
    required this.resolveEntry,
  });

  final CollectionEntry entry;
  final String? currentTrackId;
  final bool isPlaying;
  final Future<void> Function(Track track) onPlayTrack;
  final Future<void> Function(String entryId, int oldIndex, int newIndex)
  onReorderTracks;
  final Future<void> Function(String entryId, Track track) onDeleteTrack;
  final Future<void> Function(CollectionEntry entry, EntryMenuAction action)
  onMenuAction;
  final CollectionEntry? Function(String id) resolveEntry;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late CollectionEntry _entry =
      widget.resolveEntry(widget.entry.id) ?? widget.entry;

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final trackCount = _entry.tracks.length;

    return Stack(
      children: [
        SizedBox(
          height: 320,
          child: ArtworkCard(
            entry: _entry,
            borderRadius: BorderRadius.circular(26),
            heroTag: 'cover_${_entry.id}',
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0C0A09).withValues(alpha: 0.9),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GraffitiTag(label: _entry.type.label),
              const SizedBox(height: 10),
              Text(
                _entry.title,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '$trackCount ${trackCount == 1 ? 'song' : 'songs'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _refreshFromSource() async {
    final fresh = widget.resolveEntry(_entry.id);
    if (!mounted || fresh == null) {
      return;
    }
    setState(() {
      _entry = fresh;
    });
  }

  Future<void> _handleMenu(EntryMenuAction action) async {
    await widget.onMenuAction(_entry, action);
    await _refreshFromSource();
  }

  @override
  Widget build(BuildContext context) {
    return GraffitiScaffold(
      appBar: AppBar(
        title: Text(
          _entry.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          PopupMenuButton<EntryMenuAction>(
            icon: const Icon(Icons.menu_rounded),
            onSelected: _handleMenu,
            itemBuilder: (context) {
              final items = <PopupMenuEntry<EntryMenuAction>>[];
              if (_entry.type.supportsMenuEdit) {
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
              }
              items.add(
                const PopupMenuItem(
                  value: EntryMenuAction.deleteCollection,
                  child: Text('Delete Collection'),
                ),
              );
              return items;
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHero(context),
          const SizedBox(height: 18),
          Text(
            'Story',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _entry.history.isEmpty
                ? 'No history yet. Add context in the library page.'
                : _entry.history,
          ),
          const SizedBox(height: 14),
          if (_entry.featuredArtists.isNotEmpty) ...[
            Text(
              'Featured artists',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _entry.featuredArtists
                  .map((artist) => Chip(label: Text(artist)))
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],
          Text('Songs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_entry.tracks.isEmpty)
            const Text('No songs uploaded yet.')
          else if (_entry.type == CollectionType.playlist)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _entry.tracks.length,
              onReorder: (oldIndex, newIndex) async {
                await widget.onReorderTracks(_entry.id, oldIndex, newIndex);
                await _refreshFromSource();
              },
              itemBuilder: (context, index) {
                final track = _entry.tracks[index];
                final isActive =
                    widget.currentTrackId == track.id && widget.isPlaying;
                return Container(
                  key: ValueKey(track.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF201812), Color(0xFF17110D)],
                    ),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFFFB547)
                          : Colors.white12,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(track.title),
                    subtitle: Text(track.artist),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                        IconButton(
                          tooltip: 'Delete song',
                          onPressed: () => widget.onDeleteTrack(_entry.id, track),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => widget.onPlayTrack(track),
                  ),
                );
              },
            )
          else
            for (int i = 0; i < _entry.tracks.length; i++)
              StaggeredSongTile(
                key: ValueKey('${_entry.id}_${_entry.tracks[i].id}'),
                track: _entry.tracks[i],
                index: i,
                showPlaying:
                    widget.currentTrackId == _entry.tracks[i].id &&
                    widget.isPlaying,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.currentTrackId == _entry.tracks[i].id &&
                              widget.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                    IconButton(
                      tooltip: 'Delete song',
                      onPressed: () => widget.onDeleteTrack(
                        _entry.id,
                        _entry.tracks[i],
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                onTap: () => widget.onPlayTrack(_entry.tracks[i]),
              ),
        ],
      ),
    );
  }
}
