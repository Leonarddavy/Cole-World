import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('window.localStorage')
external _JSStorage? get _localStorage;

extension type _JSStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

class AppPrefs {
  const AppPrefs();

  static const String _prefsStorageKey = 'jcole_prefs_json';

  Future<Map<String, dynamic>> load() async {
    try {
      final raw = _localStorage?.getItem(_prefsStorageKey);
      if (raw == null || raw.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error, stackTrace) {
      debugPrint('[AppPrefs.load.web] $error');
      debugPrintStack(stackTrace: stackTrace);
      return {};
    }
  }

  Future<bool> save(Map<String, dynamic> prefs) async {
    try {
      final storage = _localStorage;
      if (storage == null) {
        return false;
      }
      storage.setItem(_prefsStorageKey, jsonEncode(prefs));
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AppPrefs.save.web] $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
