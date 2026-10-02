import '../models/collection_models.dart';

const String likedSongsEntryId = '${CollectionEntry.smartIdPrefix}liked';
const String onRepeatEntryId = '${CollectionEntry.smartIdPrefix}on_repeat';

/// Songs need at least this many plays before they count as "on repeat".
const int onRepeatMinPlays = 2;
const int onRepeatMaxTracks = 30;

/// Every stored track by id. A song added to a playlist from Singles shares
/// its id with the original, so the first occurrence wins.
Map<String, Track> tracksById(List<CollectionEntry> entries) {
  final byId = <String, Track>{};
  for (final entry in entries) {
    if (entry.isSmart) {
      continue;
    }
    for (final track in entry.tracks) {
      byId.putIfAbsent(track.id, () => track);
    }
  }
  return byId;
}

/// Liked tracks in [likedTrackIds] order (newest like first), skipping songs
/// that have since been deleted.
List<Track> likedTracks(
  List<CollectionEntry> entries,
  List<String> likedTrackIds,
) {
  final byId = tracksById(entries);
  return [
    for (final id in likedTrackIds)
      if (byId[id] != null) byId[id]!,
  ];
}

/// The most-played tracks, highest count first; ties keep library order.
List<Track> onRepeatTracks(
  List<CollectionEntry> entries,
  Map<String, int> playCounts,
) {
  final byId = tracksById(entries);
  final order = {for (final (i, id) in byId.keys.indexed) id: i};
  final ranked =
      playCounts.entries
          .where(
            (item) => item.value >= onRepeatMinPlays && byId[item.key] != null,
          )
          .toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0
              ? byCount
              : order[a.key]!.compareTo(order[b.key]!);
        });
  return [for (final item in ranked.take(onRepeatMaxTracks)) byId[item.key]!];
}

/// Builds the smart playlist for [id], or null if [id] isn't one.
CollectionEntry? buildSmartEntry(
  String id, {
  required List<CollectionEntry> entries,
  required List<String> likedTrackIds,
  required Map<String, int> playCounts,
}) {
  switch (id) {
    case likedSongsEntryId:
      return _smartEntry(
        id: id,
        title: 'Liked Songs',
        history:
            'Every song you hearted, newest first. Tap the heart on any song '
            'to add it here.',
        tracks: likedTracks(entries, likedTrackIds),
      );
    case onRepeatEntryId:
      return _smartEntry(
        id: id,
        title: 'On Repeat',
        history:
            'The songs you keep coming back to, ranked by how often you play '
            'them. Updates as you listen.',
        tracks: onRepeatTracks(entries, playCounts),
      );
  }
  return null;
}

CollectionEntry _smartEntry({
  required String id,
  required String title,
  required String history,
  required List<Track> tracks,
}) {
  String? cover;
  for (final track in tracks) {
    if (track.artworkPath?.isNotEmpty ?? false) {
      cover = track.artworkPath;
      break;
    }
  }
  return CollectionEntry(
    id: id,
    type: CollectionType.playlist,
    title: title,
    history: history,
    featuredArtists: const [],
    tracks: tracks,
    thumbnailPath: cover,
  );
}
