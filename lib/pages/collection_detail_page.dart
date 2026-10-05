import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../services/play_queue.dart';
import '../theme/card_shapes.dart';
import '../ui/collection_type_ui.dart';
import '../ui/formatting.dart';
import '../widgets/artwork_card.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/song_row.dart';
import '../widgets/track_actions_sheet.dart';

/// One album, single, feature or playlist: cover and Play/Shuffle up top,
/// then the songs, then the story behind it.
class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.entry,
    required this.currentTrackListenable,
    required this.playerStateStream,
    required this.pendingTrackIdListenable,
    required this.queueListenable,
    required this.onToggleTrack,
    required this.onPlayCollection,
    required this.onAttachFile,
    required this.onPlayNext,
    required this.onAddToQueue,
    required this.onAddToPlaylist,
    required this.onShowTrackDetails,
    required this.onReorderTracks,
    required this.onDeleteTrack,
    required this.onMenuAction,
    required this.resolveEntry,
    required this.likedTrackIdsListenable,
    required this.onToggleLike,
  });

  final CollectionEntry entry;
  final ValueListenable<Track?> currentTrackListenable;
  final Stream<PlayerState> playerStateStream;
  final ValueListenable<String?> pendingTrackIdListenable;
  final ValueListenable<PlayQueueView> queueListenable;

  /// Plays a song from this collection, or pauses/resumes it if current.
  final Future<void> Function(Track track, CollectionEntry entry) onToggleTrack;

  /// Plays the collection from the top, or shuffled.
  final Future<void> Function(CollectionEntry entry, {required bool shuffle})
  onPlayCollection;

  /// Lets the user pick an audio file for a song (adds or replaces it).
  final Future<void> Function(Track track, CollectionEntry entry) onAttachFile;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayNext;
  final Future<void> Function(Track track, CollectionEntry entry) onAddToQueue;
  final Future<void> Function(Track track, CollectionEntry entry)
  onAddToPlaylist;
  final Future<void> Function(Track track, CollectionEntry entry)
  onShowTrackDetails;
  final Future<void> Function(String entryId, int oldIndex, int newIndex)
  onReorderTracks;
  final Future<void> Function(String entryId, Track track) onDeleteTrack;
  final Future<void> Function(CollectionEntry entry, EntryMenuAction action)
  onMenuAction;
  final CollectionEntry? Function(String id) resolveEntry;
  final ValueListenable<Set<String>> likedTrackIdsListenable;
  final ValueChanged<Track> onToggleLike;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late CollectionEntry _entry =
      widget.resolveEntry(widget.entry.id) ?? widget.entry;
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInBar = false;

  /// Past this scroll offset the big title has left the screen, so the app
  /// bar shows it instead.
  static const double _titleScrollThreshold = 300;

  /// Smart playlists are computed from other collections, so their songs
  /// can't be reordered or deleted from here.
  bool get _isReadOnly => _entry.isSmart;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > _titleScrollThreshold;
      if (show != _showTitleInBar) {
        setState(() => _showTitleInBar = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromSource() async {
    if (!mounted) {
      return;
    }
    final fresh = widget.resolveEntry(_entry.id);
    if (fresh == null) {
      // The collection was deleted; there is nothing left to show here.
      Navigator.of(context).maybePop();
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

  Future<void> _onSongTap(Track track) async {
    if (!track.hasFile) {
      await widget.onAttachFile(track, _entry);
      await _refreshFromSource();
      return;
    }
    await widget.onToggleTrack(track, _entry);
  }

  Future<void> _showSongActions(Track track) async {
    final liked = widget.likedTrackIdsListenable.value.contains(track.id);
    await showTrackActionsSheet(
      context,
      track: track,
      artwork: artworkImageProvider(
        entry: _entry,
        imagePath: track.artworkPath,
      ),
      actions: [
        if (track.hasFile) ...[
          TrackAction(
            icon: Icons.queue_play_next,
            label: 'Play next',
            onSelected: () => widget.onPlayNext(track, _entry),
          ),
          TrackAction(
            icon: Icons.add_to_queue,
            label: 'Add to queue',
            onSelected: () => widget.onAddToQueue(track, _entry),
          ),
        ],
        TrackAction(
          icon: Icons.playlist_add,
          label: 'Add to playlist…',
          onSelected: () async {
            await widget.onAddToPlaylist(track, _entry);
            await _refreshFromSource();
          },
        ),
        TrackAction(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
          onSelected: () {
            widget.onToggleLike(track);
            // Unliking from Liked Songs removes the row.
            _refreshFromSource();
          },
        ),
        TrackAction(
          icon: track.hasFile ? Icons.swap_horiz : Icons.audio_file_outlined,
          label: track.hasFile ? 'Replace audio file' : 'Add audio file',
          onSelected: () async {
            await widget.onAttachFile(track, _entry);
            await _refreshFromSource();
          },
        ),
        TrackAction(
          icon: Icons.info_outline,
          label: 'Details',
          onSelected: () => widget.onShowTrackDetails(track, _entry),
        ),
        if (!_isReadOnly)
          TrackAction(
            icon: Icons.delete_outline,
            label: 'Remove from ${_entry.type.label.toLowerCase()}',
            destructive: true,
            onSelected: () async {
              await widget.onDeleteTrack(_entry.id, track);
              await _refreshFromSource();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GraffitiScaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _showTitleInBar
                ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.95)
                : Colors.transparent,
            title: AnimatedOpacity(
              opacity: _showTitleInBar ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            actions: [
              if (!_isReadOnly)
                _CollectionMenu(entry: _entry, onSelected: _handleMenu),
            ],
          ),
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (_entry.tracks.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _EmptySongs(
                  isPlaylist:
                      _entry.type == CollectionType.playlist && !_isReadOnly,
                  onAddFromLibrary: () =>
                      _handleMenu(EntryMenuAction.addFromLibrary),
                  onUpload: _isReadOnly
                      ? null
                      : () => _handleMenu(EntryMenuAction.uploadSongs),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: _buildSongList(),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverToBoxAdapter(child: _AboutSection(entry: _entry)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = totalDuration(_entry.tracks);
    final meta = [
      _entry.isSmart ? 'Auto playlist' : _entry.type.label,
      songCount(_entry.tracks.length),
      if (total != null) formatTotalLength(total),
    ].join(' · ');
    final featured = _entry.featuredArtists
        .where((name) => !name.toLowerCase().startsWith('no official'))
        .toList();
    final hasPlayable = _entry.tracks.any((track) => track.hasFile);

    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = (constraints.maxWidth * 0.62).clamp(160.0, 280.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox.square(
                  dimension: coverSize,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: CardShapes.of(context).artwork(20),
                      shadows: const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ArtworkCard(
                      entry: _entry,
                      borderRadius: BorderRadius.circular(20),
                      heroTag: 'cover_${_entry.id}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _entry.title,
                style: theme.textTheme.headlineMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(meta, style: theme.textTheme.bodySmall),
              if (featured.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'With ${featured.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: hasPlayable
                        ? () => widget.onPlayCollection(_entry, shuffle: true)
                        : null,
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                  const Spacer(),
                  _PlayCollectionButton(
                    entry: _entry,
                    enabled: hasPlayable,
                    queueListenable: widget.queueListenable,
                    playerStateStream: widget.playerStateStream,
                    onPlay: () =>
                        widget.onPlayCollection(_entry, shuffle: false),
                    onTogglePlayback: () {
                      final current = widget.currentTrackListenable.value;
                      if (current != null) {
                        widget.onToggleTrack(current, _entry);
                      }
                    },
                    color: scheme.primary,
                    onColor: scheme.onPrimary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongList() {
    return ValueListenableBuilder<Track?>(
      valueListenable: widget.currentTrackListenable,
      builder: (context, currentTrack, _) {
        return StreamBuilder<PlayerState>(
          stream: widget.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return ValueListenableBuilder<String?>(
              valueListenable: widget.pendingTrackIdListenable,
              builder: (context, pendingTrackId, _) {
                Widget rowFor(int index, {Widget? dragHandle}) {
                  final track = _entry.tracks[index];
                  final isActive = currentTrack?.id == track.id;
                  return SongRow(
                    key: ValueKey('${_entry.id}_${track.id}_$index'),
                    track: track,
                    number: index + 1,
                    isActive: isActive,
                    isPlaying: isActive && playing,
                    isLoading: pendingTrackId == track.id,
                    onTap: () => _onSongTap(track),
                    onShowActions: () => _showSongActions(track),
                    onSwipeToQueue: () => widget.onAddToQueue(track, _entry),
                    trailing: dragHandle,
                  );
                }

                if (_entry.type == CollectionType.playlist && !_isReadOnly) {
                  return SliverReorderableList(
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
                      return KeyedSubtree(
                        key: ValueKey('reorder_${track.id}_$index'),
                        child: rowFor(
                          index,
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(0, 8, 12, 8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return SliverList.builder(
                  itemCount: _entry.tracks.length,
                  itemBuilder: (context, index) => rowFor(index),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Big round Play button; shows Pause while this collection is playing.
class _PlayCollectionButton extends StatelessWidget {
  const _PlayCollectionButton({
    required this.entry,
    required this.enabled,
    required this.queueListenable,
    required this.playerStateStream,
    required this.onPlay,
    required this.onTogglePlayback,
    required this.color,
    required this.onColor,
  });

  final CollectionEntry entry;
  final bool enabled;
  final ValueListenable<PlayQueueView> queueListenable;
  final Stream<PlayerState> playerStateStream;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayback;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayQueueView>(
      valueListenable: queueListenable,
      builder: (context, queue, _) {
        return StreamBuilder<PlayerState>(
          stream: playerStateStream,
          builder: (context, snapshot) {
            final isThisCollection =
                queue.contextEntryId == entry.id && queue.current != null;
            final playing =
                isThisCollection && (snapshot.data?.playing ?? false);
            return SizedBox.square(
              dimension: 60,
              child: IconButton.filled(
                tooltip: playing
                    ? 'Pause'
                    : 'Play ${entry.type.label.toLowerCase()}',
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: onColor,
                ),
                onPressed: !enabled
                    ? null
                    : isThisCollection
                    ? onTogglePlayback
                    : onPlay,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 34,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CollectionMenu extends StatelessWidget {
  const _CollectionMenu({required this.entry, required this.onSelected});

  final CollectionEntry entry;
  final ValueChanged<EntryMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EntryMenuAction>(
      tooltip: '${entry.type.label} options',
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
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
          PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: EntryMenuAction.deleteCollection,
          child: Text('Delete ${entry.type.label}'),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = entry.history.trim();
    if (history.isEmpty && entry.featuredArtists.isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.85),
      shape: CardShapes.of(
        context,
      ).card(16, side: BorderSide(color: theme.colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          entry.isSmart
              ? 'About this playlist'
              : 'About this ${entry.type.label.toLowerCase()}',
          style: theme.textTheme.titleMedium,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history.isNotEmpty) Text(history),
          if (entry.featuredArtists.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Featured artists', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final artist in entry.featuredArtists)
                  Chip(label: Text(artist)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySongs extends StatelessWidget {
  const _EmptySongs({
    required this.isPlaylist,
    required this.onAddFromLibrary,
    required this.onUpload,
  });

  final bool isPlaylist;
  final VoidCallback onAddFromLibrary;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        shape: CardShapes.of(
          context,
        ).card(18, side: BorderSide(color: theme.colorScheme.outlineVariant)),
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.6),
      ),
      child: Column(
        children: [
          Icon(
            isPlaylist ? Icons.queue_music : Icons.music_off_outlined,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            isPlaylist ? 'This playlist is empty' : 'No songs yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            isPlaylist
                ? 'Add songs from your albums, singles and features, or '
                      'upload new ones.'
                : 'Upload audio files to start listening.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (isPlaylist)
                FilledButton.icon(
                  onPressed: onAddFromLibrary,
                  icon: const Icon(Icons.library_music),
                  label: const Text('Add From Library'),
                ),
              if (onUpload != null)
                OutlinedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Songs'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
