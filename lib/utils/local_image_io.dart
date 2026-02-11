import 'dart:io';

import 'package:flutter/widgets.dart';

bool canLoadLocalImage(String filePath) {
  return File(filePath).existsSync();
}

Widget buildLocalImage(
  String filePath, {
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(File(filePath), fit: fit);
}
