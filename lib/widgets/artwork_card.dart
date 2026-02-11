import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../ui/collection_type_ui.dart';
import '../utils/local_image.dart';

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
    Uint8List? bytes;
    if (thumbData != null && thumbData.isNotEmpty) {
      try {
        bytes = base64Decode(thumbData);
      } on FormatException {
        bytes = null;
      }
    }

    final hasMemoryThumb = bytes != null && bytes.isNotEmpty;
    final hasThumb =
        thumbnailPath != null &&
        thumbnailPath.isNotEmpty &&
        !kIsWeb &&
        canLoadLocalImage(thumbnailPath);

    final image = hasMemoryThumb
        ? Image.memory(bytes, fit: BoxFit.cover)
        : hasThumb
        ? buildLocalImage(thumbnailPath, fit: BoxFit.cover)
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A371D), Color(0xFF141210)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(child: Icon(entry.type.icon, size: 42)),
          );

    final child = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x11000000),
                      Color(0x77000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  entry.type.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (heroTag == null) {
      return child;
    }
    return Hero(tag: heroTag!, child: child);
  }
}
