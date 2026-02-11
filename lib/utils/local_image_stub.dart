import 'package:flutter/widgets.dart';

bool canLoadLocalImage(String filePath) {
  return false;
}

Widget buildLocalImage(
  String filePath, {
  BoxFit fit = BoxFit.cover,
}) {
  return const SizedBox.shrink();
}
