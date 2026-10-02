import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/services/play_queue.dart';

Track _t(String id) =>
    Track(id: id, title: id, artist: 'J. Cole', filePath: '/$id.mp3');

List<Track> _tracks(String ids) => [for (final id in ids.split('')) _t(id)];

/// Renders a queue as e.g. "a [b] +x c": brackets mark the current item and
/// "+" marks songs the user queued.
String _layout(PlayQueueView queue) => [
  for (final (i, item) in queue.items.indexed)
    '${item.userQueued ? '+' : ''}'
        '${i == queue.currentIndex ? '[${item.track.id}]' : item.track.id}',
].join(' ');

PlayQueueView _insert(PlayQueueView queue, int index, String id) {
  return queue.copyWith(
    items: [...queue.items]
      ..insert(
        index,
        QueueItem(track: _t(id), entryId: 'other', userQueued: true),
      ),
  );
}

void main() {
  final album = _tracks('abcd');

  PlayQueueView start(String trackId, [PlayQueueView? previous]) => startQueue(
    previous ?? PlayQueueView.empty,
    startTrack: _t(trackId),
    context: album,
    contextEntryId: 'album',
  );

  test('startQueue begins at the chosen song', () {
    final queue = start('b');
    expect(_layout(queue), 'a [b] c d');
    expect(queue.contextEntryId, 'album');
  });

  group('inserting', () {
    test('"Play next" goes straight after the current song', () {
      var queue = start('b');
      queue = _insert(queue, playNextInsertIndex(queue), 'x');
      queue = _insert(queue, playNextInsertIndex(queue), 'y');
      expect(_layout(queue), 'a [b] +y +x c d');
    });

    test(
      '"Add to queue" goes after earlier queued songs, before the album',
      () {
        var queue = start('b');
        queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
        queue = _insert(queue, addToQueueInsertIndex(queue), 'y');
        expect(_layout(queue), 'a [b] +x +y c d');
        expect(queue.upNextUserIndices, [2, 3]);
        expect(queue.upNextContextIndices, [4, 5]);
      },
    );

    test('an empty queue appends', () {
      expect(playNextInsertIndex(PlayQueueView.empty), 0);
      expect(addToQueueInsertIndex(PlayQueueView.empty), 0);
    });
  });

  test('starting a new album keeps songs the user queued', () {
    var queue = start('b');
    queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
    final next = startQueue(
      queue,
      startTrack: _t('f'),
      context: _tracks('efg'),
      contextEntryId: 'album2',
    );
    expect(_layout(next), 'e [f] +x g');
    expect(next.contextEntryId, 'album2');
  });

  group('recomposeQueue', () {
    test('reorders the album around the current song, keeping the queue', () {
      var queue = start('b');
      queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
      final current = queue.current!;

      final next = recomposeQueue(
        queue,
        context: _tracks('dcba'), // e.g. shuffle turned on
        contextEntryId: 'album',
      );
      expect(_layout(next), 'd c [b] +x a');
      expect(identical(next.current, current), isTrue);
    });

    test('a queued song playing keeps the album position it interrupted', () {
      var queue = start('b');
      queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
      queue = _insert(queue, addToQueueInsertIndex(queue), 'y');
      queue = queue.copyWith(currentIndex: 2); // now playing x

      final next = recomposeQueue(
        queue,
        context: _tracks('abcde'), // a song was added to the album
        contextEntryId: 'album',
      );
      expect(_layout(next), 'a b +[x] +y c d e');
    });

    test('drops queued songs that already played', () {
      var queue = start('a');
      queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
      queue = queue.copyWith(currentIndex: 2); // x played, now on b

      final next = recomposeQueue(
        queue,
        context: album,
        contextEntryId: 'album',
      );
      expect(_layout(next), 'a [b] c d');
    });

    test('keeps playing when the album no longer has the current song', () {
      final next = recomposeQueue(
        start('b'),
        context: _tracks('acd'),
        contextEntryId: 'album',
      );
      expect(_layout(next), '[b] a c d');
    });

    test('an empty queue just loads the album', () {
      final next = recomposeQueue(
        PlayQueueView.empty,
        context: album,
        contextEntryId: 'album',
      );
      expect(_layout(next), '[a] b c d');
    });
  });

  test('the same song can sit in the queue twice', () {
    var queue = start('b');
    queue = _insert(queue, addToQueueInsertIndex(queue), 'b');
    expect(_layout(queue), 'a [b] +b c d');
    final uids = queue.items.map((item) => item.uid).toSet();
    expect(uids, hasLength(queue.items.length));
    expect(queue.indexOfUid(queue.items[2].uid), 2);
  });

  group('moveQueueItem', () {
    PlayQueueView queued() {
      var queue = start('a'); // [a] b c d
      queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
      return _insert(queue, addToQueueInsertIndex(queue), 'y');
    }

    test('reorders within the queued block', () {
      expect(_layout(moveQueueItem(queued(), 2, 1)), '[a] +y +x b c d');
    });

    test('a song dropped into the album section stops being queued', () {
      expect(_layout(moveQueueItem(queued(), 1, 4)), '[a] +y b c x d');
    });

    test('an album song dropped into the queue block becomes queued', () {
      expect(_layout(moveQueueItem(queued(), 4, 2)), '[a] +x +c +y b d');
    });

    test('keeps a queued song queued at the end of its block', () {
      final moved = moveQueueItem(queued(), 1, 2);
      expect(_layout(moved), '[a] +y +x b c d');
    });

    test('keeps an album song in the album at the start of its section', () {
      final moved = moveQueueItem(queued(), 4, 3);
      expect(_layout(moved), '[a] +x +y c b d');
    });

    test('ignores moves touching the current or past songs', () {
      final queue = queued();
      expect(identical(moveQueueItem(queue, 0, 2), queue), isTrue);
      expect(identical(moveQueueItem(queue, 2, 0), queue), isTrue);
      expect(identical(moveQueueItem(queue, 2, 99), queue), isTrue);
    });
  });

  group('saving the queue', () {
    Track? resolve(String id) => id == 'gone' ? null : _t(id);

    test('round-trips the order, current song and queued songs', () {
      var queue = start('b');
      queue = _insert(queue, addToQueueInsertIndex(queue), 'x');
      final restored = queueFromJson(
        queueToJson(queue),
        resolveTrack: resolve,
      )!;
      expect(_layout(restored), 'a [b] +x c d');
      expect(restored.contextEntryId, 'album');
      expect(restored.items[2].entryId, 'other');
    });

    test('skips deleted songs and queued songs that already played', () {
      final restored = queueFromJson({
        'contextEntryId': 'album',
        'currentIndex': 2,
        'items': [
          {'trackId': 'a', 'entryId': 'album'},
          {'trackId': 'x', 'entryId': 'other', 'userQueued': true},
          {'trackId': 'b', 'entryId': 'album'},
          {'trackId': 'gone', 'entryId': 'album'},
          {'trackId': 'c', 'entryId': 'album'},
        ],
      }, resolveTrack: resolve)!;
      expect(_layout(restored), 'a [b] c');
    });

    test('gives up when the current song is gone or the data is bad', () {
      expect(
        queueFromJson({
          'currentIndex': 0,
          'items': [
            {'trackId': 'gone', 'entryId': 'album'},
          ],
        }, resolveTrack: resolve),
        isNull,
      );
      expect(queueFromJson('nope', resolveTrack: resolve), isNull);
      expect(queueFromJson({'items': []}, resolveTrack: resolve), isNull);
    });
  });
}
