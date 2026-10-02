import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/lyrics.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  test('parses timed lines in order and skips metadata tags', () {
    final lyrics = Lyrics.tryParse('''
[ar:J. Cole]
[ti:Love Yourz]
[00:12.50]No such thing as a life that's better than yours
[00:05.00]Intro line
[01:02.123]Third
''')!;
    expect(lyrics.isSynced, isTrue);
    expect(lyrics.lines.map((l) => l.text), [
      'Intro line',
      "No such thing as a life that's better than yours",
      'Third',
    ]);
    expect(lyrics.lines.map((l) => l.time), [
      _ms(5000),
      _ms(12500),
      _ms(62123),
    ]);
  });

  test('expands lines with several timestamps (repeated choruses)', () {
    final lyrics = Lyrics.tryParse('[00:10.00][00:40.00]Chorus\n[00:20]Verse')!;
    expect(lyrics.lines.map((l) => '${l.time!.inSeconds} ${l.text}'), [
      '10 Chorus',
      '20 Verse',
      '40 Chorus',
    ]);
  });

  test('reads tenths, hundredths and thousandths', () {
    final lyrics = Lyrics.tryParse('[00:01.5]a\n[00:02.05]b\n[00:03.005]c')!;
    expect(lyrics.lines.map((l) => l.time), [_ms(1500), _ms(2050), _ms(3005)]);
  });

  test('applies [offset] and strips word-level timestamps', () {
    final lyrics = Lyrics.tryParse(
      '[offset:+500]\n[00:10.00]<00:10.00>Wet <00:10.40>dreamz',
    )!;
    expect(lyrics.lines.single.time, _ms(9500));
    expect(lyrics.lines.single.text, 'Wet dreamz');
  });

  test('keeps timed blank lines as breaks but drops leading ones', () {
    final lyrics = Lyrics.tryParse('[00:01.00]\n[00:02.00]Start\n[00:09.00]')!;
    expect(lyrics.lines.map((l) => l.text), ['Start', '']);
    expect(lyrics.lines.last.isBreak, isTrue);
  });

  test('treats untimed text as unsynced lyrics', () {
    final lyrics = Lyrics.tryParse('﻿Line one\r\n\r\n\r\nLine two\n\n')!;
    expect(lyrics.isSynced, isFalse);
    expect(lyrics.lines.map((l) => l.text), ['Line one', '', 'Line two']);
    expect(lyrics.indexAt(_ms(99999)), -1);
  });

  test('returns null when there is nothing to show', () {
    expect(Lyrics.tryParse(null), isNull);
    expect(Lyrics.tryParse('   \n '), isNull);
    expect(Lyrics.tryParse('[ar:Someone]\n[ti:Title]'), isNull);
    expect(Lyrics.tryParse('[00:01.00]\n[00:02.00]'), isNull);
  });

  test('indexAt finds the line being sung', () {
    final lyrics = Lyrics.tryParse('[00:05]a\n[00:10]b\n[00:20]c')!;
    expect(lyrics.indexAt(_ms(0)), -1);
    expect(lyrics.indexAt(_ms(5000)), 0);
    expect(lyrics.indexAt(_ms(9999)), 0);
    expect(lyrics.indexAt(_ms(10000)), 1);
    expect(lyrics.indexAt(_ms(600000)), 2);
  });
}
