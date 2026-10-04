import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../ui/collection_type_ui.dart';

/// Lets the user pick songs from across the library (albums, singles,
/// features), grouped by collection and searchable. Returns the picked songs
/// in the order they were ticked, or null if cancelled.
///
/// Songs in [alreadyIncluded] (e.g. already in the playlist) are shown
/// ticked and can't be picked again.
Future<List<Track>?> showLibraryTrackPicker(
  BuildContext context, {
  required List<CollectionEntry> sources,
  Set<String> alreadyIncluded = const {},
  Set<String> initiallySelected = const {},
  String title = 'Add songs',
}) {
  return showModalBottomSheet<List<Track>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _LibraryTrackPicker(
        sources: [
          for (final entry in sources)
            if (entry.tracks.isNotEmpty) entry,
        ],
        alreadyIncluded: alreadyIncluded,
        initiallySelected: initiallySelected,
        title: title,
      ),
    ),
  );
}

class _LibraryTrackPicker extends StatefulWidget {
  const _LibraryTrackPicker({
    required this.sources,
    required this.alreadyIncluded,
    required this.initiallySelected,
    required this.title,
  });

  final List<CollectionEntry> sources;
  final Set<String> alreadyIncluded;
  final Set<String> initiallySelected;
  final String title;

  @override
  State<_LibraryTrackPicker> createState() => _LibraryTrackPickerState();
}

class _LibraryTrackPickerState extends State<_LibraryTrackPicker> {
  // Insertion-ordered, so songs keep the order they were ticked in.
  late final Set<String> _selected = {...widget.initiallySelected};
  late final Map<String, Track> _tracksById = {
    for (final entry in widget.sources)
      for (final track in entry.tracks) track.id: track,
  };
  String _query = '';

  bool _matches(CollectionEntry entry, Track track) {
    if (_query.isEmpty) {
      return true;
    }
    final haystack = '${track.title} ${track.artist} ${entry.title}'
        .toLowerCase();
    return haystack.contains(_query);
  }

  void _toggle(Track track, bool picked) {
    setState(() {
      if (picked) {
        _selected.add(track.id);
      } else {
        _selected.remove(track.id);
      }
    });
  }

  void _toggleAll(List<Track> tracks, bool picked) {
    setState(() {
      for (final track in tracks) {
        if (widget.alreadyIncluded.contains(track.id)) {
          continue;
        }
        if (picked) {
          _selected.add(track.id);
        } else {
          _selected.remove(track.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <(CollectionEntry, List<Track>)>[
      for (final entry in widget.sources)
        (
          entry,
          [
            for (final track in entry.tracks)
              if (_matches(entry, track)) track,
          ],
        ),
    ].where((section) => section.$2.isNotEmpty).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${_selected.length} selected',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search songs, artists, albums',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.sources.isEmpty
                ? const _PickerMessage(
                    icon: Icons.library_music_outlined,
                    text:
                        'No songs in your library yet. Upload songs to an '
                        'album, single or feature first.',
                  )
                : sections.isEmpty
                ? const _PickerMessage(
                    icon: Icons.search_off,
                    text: 'No songs match your search.',
                  )
                : ListView(
                    children: [
                      for (final (entry, tracks) in sections) ...[
                        _SectionHeader(
                          entry: entry,
                          tracks: tracks,
                          selected: _selected,
                          alreadyIncluded: widget.alreadyIncluded,
                          onToggleAll: (picked) => _toggleAll(tracks, picked),
                        ),
                        for (final track in tracks)
                          Builder(
                            builder: (context) {
                              final included = widget.alreadyIncluded.contains(
                                track.id,
                              );
                              return CheckboxListTile(
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: included || _selected.contains(track.id),
                                onChanged: included
                                    ? null
                                    : (value) => _toggle(track, value ?? false),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  included
                                      ? 'Already in this playlist'
                                      : track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, [
                          for (final id in _selected)
                            if (_tracksById[id] != null) _tracksById[id]!,
                        ]),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(
                    _selected.isEmpty ? 'Add' : 'Add ${_selected.length}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.entry,
    required this.tracks,
    required this.selected,
    required this.alreadyIncluded,
    required this.onToggleAll,
  });

  final CollectionEntry entry;
  final List<Track> tracks;
  final Set<String> selected;
  final Set<String> alreadyIncluded;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickable = tracks.where((t) => !alreadyIncluded.contains(t.id));
    final allPicked =
        pickable.isNotEmpty && pickable.every((t) => selected.contains(t.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 2),
      child: Row(
        children: [
          Icon(entry.type.icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.title} · ${entry.type.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (pickable.isNotEmpty)
            TextButton(
              onPressed: () => onToggleAll(!allPicked),
              child: Text(allPicked ? 'Clear' : 'Select all'),
            ),
        ],
      ),
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
