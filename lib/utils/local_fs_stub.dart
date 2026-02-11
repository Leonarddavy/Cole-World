Future<String?> ensureAppSubdirectory(String directoryName) async {
  return null;
}

bool localFileExistsSync(String filePath) {
  return false;
}

bool localFileUriExistsSync(Uri fileUri) {
  return false;
}

Future<bool> localFileExists(String filePath) async {
  return false;
}

String localFilePathFromUri(Uri fileUri) {
  return fileUri.path;
}

Future<String?> copyLocalFileToPath({
  required String sourcePath,
  required String targetPath,
}) async {
  return null;
}

Future<void> deleteLocalFile(String filePath) async {}
