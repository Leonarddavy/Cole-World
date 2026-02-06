import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/staggered_song_tile.dart';

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.entry,
    required this.currentTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onReorderTracks,
    required this.onMenuAction,
    required this.resolveEntry,
  });

  final CollectionEntry entry;
  final String? currentTrackId;
  final bool isPlaying;
  final Future<void> Function(Track track) onPlayTrack;
  final Future<void> Function(String entryId, int oldIndex, int newIndex)
  onReorderTracks;
  final Future<void> Function(CollectionEntry entry, EntryMenuAction action)
  onMenuAction;
  final CollectionEntry? Function(String id) resolveEntry;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late CollectionEntry _entry =
      widget.resolveEntry(widget.entry.id) ?? widget.entry;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.title),
        actions: [
          if (_entry.type.supportsMenuEdit)
            PopupMenuButton<EntryMenuAction>(
              icon: const Icon(Icons.menu_rounded),
              onSelected: _handleMenu,
              itemBuilder: (context) => const [
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SizedBox(
            height: 300,
            child: ArtworkCard(
              entry: _entry,
              borderRadius: BorderRadius.circular(22),
              heroTag: 'cover_${_entry.id}',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _entry.type.label,
            style: Theme.of(context).textTheme.labelLarge,
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
                return Card(
                  key: ValueKey(track.id),
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(track.title),
                    subtitle: Text(track.artist),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.currentTrackId == track.id && widget.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
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
                onTap: () => widget.onPlayTrack(_entry.tracks[i]),
              ),
        ],
      ),
    );
  }
}
