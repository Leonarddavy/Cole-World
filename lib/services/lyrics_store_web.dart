import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('window.localStorage')
external _JSStorage? get _localStorage;

extension type _JSStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Imported lyrics kept in the browser's localStorage, one key per track.
class LyricsStore {
  const LyricsStore();

  static String _key(String trackId) => 'jcole_lyrics_$trackId';

  Future<String?> read(String trackId) async {
    try {
      return _localStorage?.getItem(_key(trackId));
    } catch (error) {
      debugPrint('[LyricsStore.read.web] $error');
      return null;
    }
  }

  Future<bool> write(String trackId, String lyrics) async {
    try {
      final storage = _localStorage;
      if (storage == null) {
        return false;
      }
      storage.setItem(_key(trackId), lyrics);
      return true;
    } catch (error) {
      debugPrint('[LyricsStore.write.web] $error');
      return false;
    }
  }

  Future<void> delete(String trackId) async {
    try {
      _localStorage?.removeItem(_key(trackId));
    } catch (error) {
      debugPrint('[LyricsStore.delete.web] $error');
    }
  }
}
