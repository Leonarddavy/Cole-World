import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Lyrics the user imported (or that came with a song), one `.lrc` file per
/// track id in the app's documents directory.
class LyricsStore {
  const LyricsStore();

  Future<File> _fileFor(String trackId) async {
    final directory = await getApplicationDocumentsDirectory();
    final lyricsDir = Directory(path.join(directory.path, 'lyrics'));
    if (!await lyricsDir.exists()) {
      await lyricsDir.create(recursive: true);
    }
    final safeId = trackId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(path.join(lyricsDir.path, '$safeId.lrc'));
  }

  Future<String?> read(String trackId) async {
    try {
      final file = await _fileFor(trackId);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (error) {
      debugPrint('[LyricsStore.read] $error');
      return null;
    }
  }

  Future<bool> write(String trackId, String lyrics) async {
    try {
      final file = await _fileFor(trackId);
      await file.writeAsString(lyrics, flush: true);
      return true;
    } catch (error) {
      debugPrint('[LyricsStore.write] $error');
      return false;
    }
  }

  Future<void> delete(String trackId) async {
    try {
      final file = await _fileFor(trackId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('[LyricsStore.delete] $error');
    }
  }
}
