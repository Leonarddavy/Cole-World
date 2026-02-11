import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
    } catch (error, stackTrace) {
      debugPrint('[AppPrefs.load] $error');
      debugPrintStack(stackTrace: stackTrace);
      return {};
    }
  }

  Future<bool> save(Map<String, dynamic> prefs) async {
    try {
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode(prefs), flush: true);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AppPrefs.save] $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
