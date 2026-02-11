import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../models/collection_models.dart';

@JS('window.localStorage')
external _JSStorage? get _localStorage;

extension type _JSStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

class LibraryStorage {
  const LibraryStorage();

  static const String _libraryStorageKey = 'jcole_library_json';

  Future<List<CollectionEntry>?> load() async {
    try {
      final raw = _localStorage?.getItem(_libraryStorageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => CollectionEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error, stackTrace) {
      debugPrint('[LibraryStorage.load.web] $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> save(List<CollectionEntry> entries) async {
    try {
      final payload = jsonEncode(
        entries.map((entry) => entry.toJson()).toList(),
      );
      final storage = _localStorage;
      if (storage == null) {
        return false;
      }
      storage.setItem(_libraryStorageKey, payload);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[LibraryStorage.save.web] $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
