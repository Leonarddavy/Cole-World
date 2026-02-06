import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../ui/collection_type_ui.dart';

class ArtworkCard extends StatelessWidget {
  const ArtworkCard({
    super.key,
    required this.entry,
    required this.borderRadius,
    this.heroTag,
  });

  final CollectionEntry entry;
  final BorderRadius borderRadius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = entry.thumbnailPath;
    final thumbData = entry.thumbnailDataBase64;
    final Uint8List? bytes = thumbData == null || thumbData.isEmpty
        ? null
        : base64Decode(thumbData);

    final hasMemoryThumb = bytes != null && bytes.isNotEmpty;
    final hasThumb =
        !kIsWeb &&
        thumbnailPath != null &&
        thumbnailPath.isNotEmpty &&
        File(thumbnailPath).existsSync();

    final child = ClipRRect(
      borderRadius: borderRadius,
      child: hasMemoryThumb
          ? Image.memory(bytes, fit: BoxFit.cover)
          : hasThumb
          ? Image.file(File(thumbnailPath), fit: BoxFit.cover)
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A371D), Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(child: Icon(entry.type.icon, size: 42)),
            ),
    );

    if (heroTag == null) {
      return child;
    }
    return Hero(tag: heroTag!, child: child);
  }
}
