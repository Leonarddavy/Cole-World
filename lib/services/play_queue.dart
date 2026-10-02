import '../models/collection_models.dart';

/// One slot in the play queue. The player's playlist mirrors the queue's
/// items one-to-one, so an item's index is also its index in the player.
class QueueItem {
  QueueItem({
    required this.track,
    required this.entryId,
    this.userQueued = false,
    String? uid,
  }) : uid = uid ?? 'q${_nextUid++}';

  static int _nextUid = 0;

  final Track track;

  /// The collection the track belongs to (for artwork and "Playing from").
  final String entryId;

  /// True for songs added with "Play next" / "Add to queue"; false for songs
  /// that come from the collection playback was started from.
  final bool userQueued;

  /// Distinguishes two slots holding the same track.
  final String uid;

  QueueItem withTrack(Track updated) => QueueItem(
    track: updated,
    entryId: entryId,
    userQueued: userQueued,
    uid: uid,
  );
}

class PlayQueueView {
  const PlayQueueView({
    this.items = const [],
    this.currentIndex = -1,
    this.contextEntryId,
  });

  static const PlayQueueView empty = PlayQueueView();

  final List<QueueItem> items;
  final int currentIndex;

  /// The collection playback was started from.
  final String? contextEntryId;

  bool get isEmpty => items.isEmpty;

  QueueItem? get current => currentIndex >= 0 && currentIndex < items.length
      ? items[currentIndex]
      : null;

  /// Index just past the songs the user queued after the current one. User
  /// queued songs always sit in one block right after the current song.
  int get userBlockEnd {
    var index = currentIndex + 1;
    while (index < items.length && items[index].userQueued) {
      index++;
    }
    return index;
  }

  /// Upcoming songs the user queued ("Next in queue").
  List<int> get upNextUserIndices => [
    for (var i = currentIndex + 1; i < userBlockEnd; i++) i,
  ];

  /// Upcoming songs from the collection ("Next from ...").
  List<int> get upNextContextIndices => [
    for (var i = userBlockEnd; i < items.length; i++) i,
  ];

  int indexOfUid(String uid) => items.indexWhere((item) => item.uid == uid);

  PlayQueueView copyWith({List<QueueItem>? items, int? currentIndex}) {
    return PlayQueueView(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      contextEntryId: contextEntryId,
    );
  }
}

/// Where "Play next" puts a song: straight after the current one.
int playNextInsertIndex(PlayQueueView queue) =>
    queue.current == null ? queue.items.length : queue.currentIndex + 1;

/// Where "Add to queue" puts a song: after songs the user already queued, but
/// ahead of the rest of the collection.
int addToQueueInsertIndex(PlayQueueView queue) =>
    queue.current == null ? queue.items.length : queue.userBlockEnd;

/// Rebuilds the queue around the current song after the collection being
/// played changes (shuffle toggled, songs added, reordered or removed).
///
/// [context] is the collection's new play order. The current song and the
/// songs the user queued are kept; songs the user queued that already played
/// are dropped.
PlayQueueView recomposeQueue(
  PlayQueueView queue, {
  required List<Track> context,
  required String contextEntryId,
}) {
  final current = queue.current;
  if (current == null) {
    return PlayQueueView(
      items: [
        for (final track in context)
          QueueItem(track: track, entryId: contextEntryId),
      ],
      currentIndex: context.isEmpty ? -1 : 0,
      contextEntryId: contextEntryId,
    );
  }

  final pendingUser = [
    for (final index in queue.upNextUserIndices) queue.items[index],
  ];

  // The collection song the listener has most recently reached: the current
  // song itself, or the one playing before a queued song interrupted.
  String? anchorId;
  if (!current.userQueued) {
    anchorId = current.track.id;
  } else {
    for (var i = queue.currentIndex - 1; i >= 0; i--) {
      if (!queue.items[i].userQueued) {
        anchorId = queue.items[i].track.id;
        break;
      }
    }
  }
  final anchorIndex = anchorId == null
      ? -1
      : context.indexWhere((track) => track.id == anchorId);

  QueueItem fromContext(Track track) =>
      QueueItem(track: track, entryId: contextEntryId);

  final List<Track> before;
  final List<Track> after;
  if (anchorIndex < 0) {
    before = const [];
    after = [
      for (final track in context)
        if (track.id != current.track.id) track,
    ];
  } else if (current.userQueued) {
    // The anchor already played, so it belongs to the history.
    before = context.sublist(0, anchorIndex + 1);
    after = context.sublist(anchorIndex + 1);
  } else {
    // The anchor is the current item itself, kept as-is below.
    before = context.sublist(0, anchorIndex);
    after = context.sublist(anchorIndex + 1);
  }

  return PlayQueueView(
    items: [
      ...before.map(fromContext),
      current,
      ...pendingUser,
      ...after.map(fromContext),
    ],
    currentIndex: before.length,
    contextEntryId: contextEntryId,
  );
}

/// Starts playing [startTrack] from [context], keeping songs the user had
/// queued (Spotify keeps your queue when you start a new album or playlist).
PlayQueueView startQueue(
  PlayQueueView previous, {
  required Track startTrack,
  required List<Track> context,
  required String contextEntryId,
}) {
  final items = [
    for (final track in context)
      QueueItem(track: track, entryId: contextEntryId),
  ];
  var index = items.indexWhere((item) => item.track.id == startTrack.id);
  if (index < 0) {
    items.insert(0, QueueItem(track: startTrack, entryId: contextEntryId));
    index = 0;
  }
  items.insertAll(index + 1, [
    for (final i in previous.upNextUserIndices) previous.items[i],
  ]);
  return PlayQueueView(
    items: items,
    currentIndex: index,
    contextEntryId: contextEntryId,
  );
}

/// Moves the upcoming item at [from] to [to] (both after the current item;
/// [to] is its index once moved, matching `List.insert` after `removeAt`).
///
/// Songs the user queued must stay in one block right after the current
/// song, so a song dropped inside that block becomes queued, one dropped
/// past it becomes part of the regular order, and one dropped on the
/// boundary keeps what it was.
PlayQueueView moveQueueItem(PlayQueueView queue, int from, int to) {
  final current = queue.currentIndex;
  if (from <= current ||
      to <= current ||
      from >= queue.items.length ||
      to >= queue.items.length) {
    return queue;
  }
  final items = [...queue.items];
  final moved = items.removeAt(from);
  final blockEnd = PlayQueueView(
    items: items,
    currentIndex: current,
  ).userBlockEnd;
  final userQueued = to < blockEnd
      ? true
      : to > blockEnd
      ? false
      : moved.userQueued;
  items.insert(
    to,
    QueueItem(
      track: moved.track,
      entryId: moved.entryId,
      userQueued: userQueued,
      uid: moved.uid,
    ),
  );
  return queue.copyWith(items: items);
}

Map<String, dynamic> queueToJson(PlayQueueView queue) {
  return {
    'contextEntryId': queue.contextEntryId,
    'currentIndex': queue.currentIndex,
    'items': [
      for (final item in queue.items)
        {
          'trackId': item.track.id,
          'entryId': item.entryId,
          if (item.userQueued) 'userQueued': true,
        },
    ],
  };
}

/// Restores a saved queue. Songs [resolveTrack] can't find (deleted, or
/// their file is gone) are skipped, as are queued songs that already played.
/// Returns null if the saved current song can't be restored.
PlayQueueView? queueFromJson(
  Object? raw, {
  required Track? Function(String trackId) resolveTrack,
}) {
  if (raw is! Map) {
    return null;
  }
  final rawItems = raw['items'];
  final savedCurrent = raw['currentIndex'];
  if (rawItems is! List || savedCurrent is! num) {
    return null;
  }
  final items = <QueueItem>[];
  var currentIndex = -1;
  for (final (i, rawItem) in rawItems.indexed) {
    if (rawItem is! Map) {
      continue;
    }
    final trackId = (rawItem['trackId'] ?? '').toString();
    final track = resolveTrack(trackId);
    if (track == null) {
      continue;
    }
    final userQueued = rawItem['userQueued'] == true;
    if (userQueued && i < savedCurrent) {
      continue;
    }
    if (i == savedCurrent) {
      currentIndex = items.length;
    }
    items.add(
      QueueItem(
        track: track,
        entryId: (rawItem['entryId'] ?? '').toString(),
        userQueued: userQueued && i > savedCurrent,
      ),
    );
  }
  if (currentIndex < 0) {
    return null;
  }
  final contextEntryId = raw['contextEntryId']?.toString();
  return PlayQueueView(
    items: items,
    currentIndex: currentIndex,
    contextEntryId: contextEntryId == null || contextEntryId.isEmpty
        ? null
        : contextEntryId,
  );
}
