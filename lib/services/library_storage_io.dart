import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/collection_models.dart';

class LibraryStorage {
  const LibraryStorage();

  Future<File> _libraryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, 'jcole_library.json'));
  }

  Future<List<CollectionEntry>?> load() async {
    try {
      final file = await _libraryFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
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
      debugPrint('[LibraryStorage.load] $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> save(List<CollectionEntry> entries) async {
    try {
      final file = await _libraryFile();
      final payload = jsonEncode(
        entries.map((entry) => entry.toJson()).toList(),
      );
      await file.writeAsString(payload, flush: true);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[LibraryStorage.save] $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
