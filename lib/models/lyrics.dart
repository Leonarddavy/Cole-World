/// One lyric line. [time] is null for lyrics without timestamps.
class LyricLine {
  const LyricLine({required this.text, this.time});

  final Duration? time;
  final String text;

  /// Timed blank lines mark instrumental breaks.
  bool get isBreak => text.isEmpty;
}

/// Lyrics parsed from LRC (`[mm:ss.xx]line`) or plain text.
class Lyrics {
  const Lyrics({required this.lines, required this.isSynced, this.source});

  final List<LyricLine> lines;

  /// Who supplied the lyrics, from the LRC `[re:...]` tag (e.g. "LRCLIB").
  final String? source;

  /// True when lines carry timestamps and can follow playback.
  final bool isSynced;

  static final RegExp _timestamp = RegExp(
    r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _leadingTimestamps = RegExp(
    r'^(\s*\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\])+',
  );
  static final RegExp _wordTimestamp = RegExp(
    r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>',
  );
  static final RegExp _metadataTag = RegExp(r'^\[([a-zA-Z#]+):(.*)\]$');

  /// Parses [raw], returning null when there is nothing to show.
  static Lyrics? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final text = raw.replaceFirst('﻿', '');
    if (text.trim().isEmpty) {
      return null;
    }

    var offset = Duration.zero;
    String? source;
    final timed = <LyricLine>[];
    final plain = <String>[];

    for (final rawLine in text.split(RegExp(r'\r\n|\r|\n'))) {
      final line = rawLine.trim();
      final prefix = _leadingTimestamps.firstMatch(line);
      if (prefix != null) {
        final body = _clean(line.substring(prefix.end));
        for (final match in _timestamp.allMatches(prefix.group(0)!)) {
          timed.add(LyricLine(time: _parseTime(match), text: body));
        }
        continue;
      }
      final tag = _metadataTag.firstMatch(line);
      if (tag != null) {
        // [offset:+250] means show lyrics 250ms earlier.
        final key = tag.group(1)!.toLowerCase();
        if (key == 're' && tag.group(2)!.trim().isNotEmpty) {
          source = tag.group(2)!.trim();
        }
        if (key == 'offset') {
          final ms = int.tryParse(tag.group(2)!.trim().replaceFirst('+', ''));
          if (ms != null) {
            offset = Duration(milliseconds: ms);
          }
        }
        continue;
      }
      plain.add(_clean(line));
    }

    if (timed.isNotEmpty) {
      final shifted = [
        for (final line in timed)
          LyricLine(time: _clamp(line.time! - offset), text: line.text),
      ]..sort((a, b) => a.time!.compareTo(b.time!));
      // Drop leading blank lines; they would only push the first lyric down.
      final firstText = shifted.indexWhere((line) => !line.isBreak);
      if (firstText < 0) {
        return null;
      }
      return Lyrics(
        lines: shifted.sublist(firstText),
        isSynced: true,
        source: source,
      );
    }

    // Collapse runs of blank lines and trim blank edges.
    final lines = <LyricLine>[];
    for (final line in plain) {
      if (line.isEmpty && (lines.isEmpty || lines.last.isBreak)) {
        continue;
      }
      lines.add(LyricLine(text: line));
    }
    while (lines.isNotEmpty && lines.last.isBreak) {
      lines.removeLast();
    }
    return lines.isEmpty
        ? null
        : Lyrics(lines: lines, isSynced: false, source: source);
  }

  /// Index of the line being sung at [position], or -1 before the first line
  /// (and always -1 for unsynced lyrics).
  int indexAt(Duration position) {
    if (!isSynced) {
      return -1;
    }
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time! <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  static Duration _parseTime(RegExpMatch match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fraction = match.group(3);
    var millis = 0;
    if (fraction != null) {
      // ".5" is tenths, ".05" hundredths, ".005" thousandths.
      millis = int.parse(fraction.padRight(3, '0'));
    }
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  static String _clean(String text) => text
      .replaceAll(_wordTimestamp, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Duration _clamp(Duration value) =>
      value.isNegative ? Duration.zero : value;
}
