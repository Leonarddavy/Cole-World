import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPrefs {
  const AppPrefs();

  Future<File> _prefsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, 'jcole_prefs.json'));
  }

  Future<Map<String, dynamic>> load() async {
    try {
      final file = await _prefsFile();
      if (!await file.exists()) {
        return {};
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, dynamic> prefs) async {
    try {
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode(prefs), flush: true);
    } catch (_) {}
  }
}

