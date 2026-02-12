import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String?> ensureAppSubdirectory(String directoryName) async {
  final directory = await getApplicationDocumentsDirectory();
  final subdirectory = Directory(path.join(directory.path, directoryName));
  if (!await subdirectory.exists()) {
    await subdirectory.create(recursive: true);
  }
  return subdirectory.path;
}

bool localFileExistsSync(String filePath) {
  return File(filePath).existsSync();
}

bool localFileUriExistsSync(Uri fileUri) {
  return File.fromUri(fileUri).existsSync();
}

Future<bool> localFileExists(String filePath) async {
  return File(filePath).exists();
}

String localFilePathFromUri(Uri fileUri) {
  return File.fromUri(fileUri).path;
}

Future<String?> copyLocalFileToPath({
  required String sourcePath,
  required String targetPath,
}) async {
  final copied = await File(sourcePath).copy(targetPath);
  return copied.path;
}

Future<void> deleteLocalFile(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<List<String>> listAudioFilesRecursively(
  String directoryPath, {
  Set<String>? extensions,
}) async {
  final trimmed = directoryPath.trim();
  final root = await _resolveDirectoryForListing(trimmed);
  if (root == null) {
    return const [];
  }
  if (!await root.exists()) {
    return const [];
  }

  final allowed = (extensions == null || extensions.isEmpty)
      ? <String>{
          '.mp3',
          '.wav',
          '.m4a',
          '.aac',
          '.flac',
          '.ogg',
          '.opus',
          '.wma',
        }
      : extensions.map((item) => item.toLowerCase()).toSet();

  final paths = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final extension = path.extension(entity.path).toLowerCase();
    if (allowed.contains(extension)) {
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}

Future<Directory?> _resolveDirectoryForListing(String rawPath) async {
  final candidates = _directoryCandidates(rawPath);
  for (final candidate in candidates) {
    final directory = Directory(candidate);
    if (await directory.exists()) {
      return directory;
    }
  }
  return null;
}

List<String> _directoryCandidates(String rawPath) {
  if (rawPath.isEmpty) {
    return const [];
  }
  final normalized = <String>{rawPath, Uri.decodeFull(rawPath)};
  final parsedUri = Uri.tryParse(rawPath);
  if (parsedUri != null && parsedUri.scheme == 'file') {
    normalized.add(File.fromUri(parsedUri).path);
  }

  final docId = _androidDocumentId(rawPath);
  if (docId != null) {
    normalized.addAll(_androidPathsFromDocumentId(docId));
  }
  final decodedDocId = _androidDocumentId(Uri.decodeFull(rawPath));
  if (decodedDocId != null) {
    normalized.addAll(_androidPathsFromDocumentId(decodedDocId));
  }

  return normalized
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _androidDocumentId(String source) {
  final treeMatch = RegExp(r'(?:^|/)tree/([^/]+)').firstMatch(source);
  if (treeMatch != null) {
    return Uri.decodeComponent(treeMatch.group(1)!);
  }
  final documentMatch = RegExp(r'(?:^|/)document/([^/]+)').firstMatch(source);
  if (documentMatch != null) {
    return Uri.decodeComponent(documentMatch.group(1)!);
  }
  final rawMatch = RegExp(
    r'^(primary|home|raw|[A-Za-z0-9_-]+):',
  ).firstMatch(source);
  if (rawMatch != null) {
    return source;
  }
  return null;
}

List<String> _androidPathsFromDocumentId(String documentId) {
  final trimmed = documentId.trim();
  if (trimmed.isEmpty) {
    return const [];
  }
  if (trimmed.startsWith('raw:')) {
    return [trimmed.substring(4)];
  }
  final separator = trimmed.indexOf(':');
  if (separator <= 0) {
    return const [];
  }

  final volume = trimmed.substring(0, separator);
  final relative = trimmed.substring(separator + 1);
  if (volume == 'primary' || volume == 'home') {
    return [path.normalize(path.join('/storage/emulated/0', relative))];
  }

  return [
    path.normalize(path.join('/storage', volume, relative)),
    path.normalize(path.join('/storage', volume.toUpperCase(), relative)),
  ];
}
