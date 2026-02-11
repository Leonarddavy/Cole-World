import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../ui/collection_type_ui.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/graffiti_tag.dart';
import '../widgets/now_playing_equalizer.dart';
import '../widgets/staggered_song_tile.dart';

enum _TrackMenuAction { details }

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.entry,
    required this.currentTrackListenable,
    required this.playerStateStream,
    required this.pendingTrackIdListenable,
    required this.onPlayTrack,
    required this.onToggleTrack,
    required this.onOpenNowPlaying,
    required this.onOpenQueuedNowPlaying,
    required this.queueListenable,
    required this.currentEntryId,
    required this.onShowTrackDetails,
    required this.onReorderTracks,
    required this.onDeleteTrack,
    required this.onMenuAction,
    required this.resolveEntry,
  });

  final CollectionEntry entry;
  final ValueListenable<Track?> currentTrackListenable;
  final Stream<PlayerState> playerStateStream;
  final ValueListenable<String?> pendingTrackIdListenable;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;
  final Future<void> Function(Track track, CollectionEntry entry) onToggleTrack;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenQueuedNowPlaying;
  final ValueListenable<List<Track>> queueListenable;
  final String? currentEntryId;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;
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

  List<Track> _upNextQueue({
    required List<Track> queue,
    Track? currentTrack,
  }) {
    if (queue.isEmpty) {
      return const [];
    }
    if (currentTrack == null) {
      return queue;
    }
    final index = queue.indexWhere((track) => track.id == currentTrack.id);
    if (index < 0 || index >= queue.length - 1) {
      return const [];
    }
    return queue.sublist(index + 1);
  }

  Widget _buildQueueSection(BuildContext context, Track? currentTrack) {
    final theme = Theme.of(context);
    final isCurrentEntry = widget.currentEntryId == _entry.id;
    final supportsQueue = _entry.type == CollectionType.album ||
        _entry.type == CollectionType.playlist;
    if (!isCurrentEntry || !supportsQueue) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<List<Track>>(
      valueListenable: widget.queueListenable,
      builder: (context, queue, _) {
        final upNext = _upNextQueue(queue: queue, currentTrack: currentTrack);
        if (queue.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (upNext.isEmpty)
              Text(
                'You\'re at the end of the queue.',
                style: theme.textTheme.bodySmall,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upNext.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = upNext[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.queue_music),
                    title: Text(track.title),
                    subtitle: Text(track.artist),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      await widget.onPlayTrack(track, _entry);
                      if (context.mounted) {
                        widget.onOpenQueuedNowPlaying();
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

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
    return ValueListenableBuilder<Track?>(
      valueListenable: widget.currentTrackListenable,
      builder: (context, currentTrack, _) {
        return StreamBuilder<PlayerState>(
          stream: widget.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final processing = state?.processingState ?? ProcessingState.idle;
            final busy = processing == ProcessingState.loading ||
                processing == ProcessingState.buffering;
            final currentTrackId = currentTrack?.id;

            return ValueListenableBuilder<String?>(
              valueListenable: widget.pendingTrackIdListenable,
              builder: (context, pendingTrackId, _) {
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
                      _buildQueueSection(context, currentTrack),
                      Row(
                        children: [
                          Text(
                            'Songs',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if ((busy && currentTrackId != null) ||
                              pendingTrackId != null)
                            Row(
                              children: const [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Loading...'),
                              ],
                            ),
                        ],
                      ),
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
                            await widget.onReorderTracks(
                              _entry.id,
                              oldIndex,
                              newIndex,
                            );
                            await _refreshFromSource();
                          },
                          itemBuilder: (context, index) {
                            final track = _entry.tracks[index];
                            final isActive = currentTrackId == track.id;
                            final isPlaying = isActive && playing;
                            final isLoadingThis = pendingTrackId == track.id;

                            final leading = isLoadingThis
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : (isPlaying
                                      ? const NowPlayingEqualizer(size: 20)
                                      : const Icon(Icons.music_note));

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
                                leading: leading,
                                title: Text(track.title),
                                subtitle: Text(track.artist),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isLoadingThis)
                                      IconButton(
                                        tooltip:
                                            isPlaying ? 'Pause' : 'Play',
                                        onPressed: () =>
                                            widget.onToggleTrack(track, _entry),
                                        icon: Icon(
                                          isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_fill,
                                        ),
                                      ),
                                    PopupMenuButton<_TrackMenuAction>(
                                      tooltip: 'Track options',
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (action) {
                                        if (action ==
                                            _TrackMenuAction.details) {
                                          widget.onShowTrackDetails(
                                            track,
                                            _entry,
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: _TrackMenuAction.details,
                                          child: Text('Details'),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: 'Delete song',
                                      onPressed: () =>
                                          widget.onDeleteTrack(_entry.id, track),
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
                                onTap: () async {
                                  await widget.onPlayTrack(track, _entry);
                                  if (context.mounted) {
                                    widget.onOpenNowPlaying();
                                  }
                                },
                              ),
                            );
                          },
                        )
                      else
                        for (int i = 0; i < _entry.tracks.length; i++)
                          Builder(
                            builder: (context) {
                              final track = _entry.tracks[i];
                              final isActive = currentTrackId == track.id;
                              final isPlaying = isActive && playing;
                              final isLoadingThis = pendingTrackId == track.id;

                              final leading = isLoadingThis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : (isPlaying
                                        ? const NowPlayingEqualizer(size: 20)
                                        : const Icon(Icons.music_note));

                              return StaggeredSongTile(
                                key: ValueKey('${_entry.id}_${track.id}'),
                                track: track,
                                index: i,
                                showPlaying: isPlaying,
                                leading: leading,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isLoadingThis)
                                      IconButton(
                                        tooltip:
                                            isPlaying ? 'Pause' : 'Play',
                                        onPressed: () =>
                                            widget.onToggleTrack(track, _entry),
                                        icon: Icon(
                                          isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_fill,
                                        ),
                                      ),
                                    PopupMenuButton<_TrackMenuAction>(
                                      tooltip: 'Track options',
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (action) {
                                        if (action ==
                                            _TrackMenuAction.details) {
                                          widget.onShowTrackDetails(
                                            track,
                                            _entry,
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: _TrackMenuAction.details,
                                          child: Text('Details'),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: 'Delete song',
                                      onPressed: () =>
                                          widget.onDeleteTrack(_entry.id, track),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await widget.onPlayTrack(track, _entry);
                                  if (context.mounted) {
                                    widget.onOpenNowPlaying();
                                  }
                                },
                              );
                            },
                          ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
