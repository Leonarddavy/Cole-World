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
