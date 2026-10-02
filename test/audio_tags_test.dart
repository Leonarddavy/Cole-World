import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:jcole_player/utils/audio_tags.dart';
import 'package:jcole_player/utils/local_fs.dart';

/// Builds a minimal MP3: an ID3v2.3 tag (title, artist, cover) followed by a
/// few silent MPEG-1 Layer III frames.
Uint8List _buildTaggedMp3({
  required String title,
  required String artist,
  required List<int> cover,
  String? lyrics,
}) {
  List<int> frame(String id, List<int> data) {
    final size = data.length;
    return [
      ...ascii.encode(id),
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
      0,
      0,
      ...data,
    ];
  }

  final frames = <int>[
    ...frame('TIT2', [0, ...latin1.encode(title)]),
    ...frame('TPE1', [0, ...latin1.encode(artist)]),
    ...frame('APIC', [0, ...ascii.encode('image/png'), 0, 3, 0, ...cover]),
    if (lyrics != null)
      ...frame('USLT', [
        0,
        ...ascii.encode('eng'),
        0,
        ...latin1.encode(lyrics),
      ]),
  ];
  final size = frames.length;
  final header = <int>[
    ...ascii.encode('ID3'),
    3,
    0,
    0,
    (size >> 21) & 0x7F,
    (size >> 14) & 0x7F,
    (size >> 7) & 0x7F,
    size & 0x7F,
  ];
  // 128 kbps, 44.1 kHz MPEG-1 Layer III frames are 417 bytes each.
  final audio = <int>[
    for (var i = 0; i < 4; i++) ...[
      0xFF,
      0xFB,
      0x90,
      0x64,
      ...List.filled(413, 0),
    ],
  ];
  return Uint8List.fromList([...header, ...frames, ...audio]);
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_tags_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('reads title, artist and cover art from ID3 tags', () async {
    final cover = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4];
    final file = File(path.join(tempDir.path, 'song.mp3'))
      ..writeAsBytesSync(
        _buildTaggedMp3(title: 'Wet Dreamz', artist: 'J. Cole', cover: cover),
      );

    final tags = await readAudioTags(file.path);

    expect(tags, isNotNull);
    expect(tags!.title, 'Wet Dreamz');
    expect(tags.artist, 'J. Cole');
    expect(tags.hasCover, isTrue);
    expect(tags.coverBytes, cover);
    expect(tags.coverExtension, '.png');
  });

  test('returns null for a missing file', () async {
    expect(await readAudioTags(path.join(tempDir.path, 'nope.mp3')), isNull);
  });

  test('returns null for an untagged, unparseable file', () async {
    final file = File(path.join(tempDir.path, 'junk.mp3'))
      ..writeAsBytesSync(List.filled(64, 7));
    expect(await readAudioTags(file.path), isNull);
  });

  test('reads embedded lyrics', () async {
    final file = File(path.join(tempDir.path, 'lyrics.mp3'))
      ..writeAsBytesSync(
        _buildTaggedMp3(
          title: 'Song',
          artist: 'J. Cole',
          cover: const [1, 2, 3],
          lyrics: '[00:01.00]Hello',
        ),
      );
    final tags = await readAudioTags(file.path);
    expect(tags?.lyrics, '[00:01.00]Hello');
  });

  test('finds an .lrc file next to the song', () async {
    final song = path.join(tempDir.path, 'Wet Dreamz.mp3');
    File(song).writeAsBytesSync(const [0]);
    File(
      path.join(tempDir.path, 'Wet Dreamz.lrc'),
    ).writeAsStringSync('[00:02.00]Line');
    expect(await readSidecarLyrics(song), '[00:02.00]Line');
    expect(
      await readSidecarLyrics(path.join(tempDir.path, 'other.mp3')),
      isNull,
    );
  });
}
