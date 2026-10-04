import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../theme/graffiti_surfaces.dart';
import '../ui/collection_type_ui.dart';
import '../utils/local_image.dart';

/// Decoded base64 thumbnails, so a rebuild reuses the same bytes (and the
/// image cache entry) instead of decoding and re-uploading the image.
final LinkedHashMap<String, Uint8List> _decodedThumbnails = LinkedHashMap();
const int _maxDecodedThumbnails = 48;

Uint8List? _decodeThumbnail(String data) {
  final cached = _decodedThumbnails.remove(data);
  if (cached != null) {
    _decodedThumbnails[data] = cached;
    return cached;
  }
  try {
    final bytes = base64Decode(data);
    if (bytes.isEmpty) {
      return null;
    }
    _decodedThumbnails[data] = bytes;
    if (_decodedThumbnails.length > _maxDecodedThumbnails) {
      _decodedThumbnails.remove(_decodedThumbnails.keys.first);
    }
    return bytes;
  } on FormatException {
    return null;
  }
}

/// The best available image: [imagePath] (e.g. a song's own cover), then the
/// collection's thumbnail. Null when there is nothing to show.
ImageProvider? artworkImageProvider({
  CollectionEntry? entry,
  String? imagePath,
}) {
  if (!kIsWeb && imagePath != null && imagePath.isNotEmpty) {
    if (canLoadLocalImage(imagePath)) {
      return localImageProvider(imagePath);
    }
  }
  final data = entry?.thumbnailDataBase64;
  if (data != null && data.isNotEmpty) {
    final bytes = _decodeThumbnail(data);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
  }
  final path = entry?.thumbnailPath;
  if (!kIsWeb && path != null && path.isNotEmpty && canLoadLocalImage(path)) {
    return localImageProvider(path);
  }
  return null;
}

class ArtworkCard extends StatelessWidget {
  const ArtworkCard({
    super.key,
    required this.entry,
    required this.borderRadius,
    this.heroTag,
    this.imagePath,
    this.showTypeBadge = false,
  });

  final CollectionEntry entry;
  final BorderRadius borderRadius;
  final String? heroTag;

  /// A local image (e.g. the playing track's own cover) shown in place of the
  /// collection thumbnail when it exists.
  final String? imagePath;

  /// Labels the cover "ALBUM", "SINGLE"…; only useful where types are mixed.
  final bool showTypeBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = artworkImageProvider(entry: entry, imagePath: imagePath);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: scheme.artworkPlaceholderGradient),
      child: Center(
        child: Icon(entry.type.icon, size: 42, color: scheme.onSurfaceVariant),
      ),
    );

    final child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (provider == null)
              placeholder
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // Decode at display size, not the cover's full resolution.
                  final width = constraints.maxWidth;
                  final cacheWidth = width.isFinite && width > 0
                      ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                      : null;
                  return Image(
                    image: ResizeImage.resizeIfNeeded(
                      cacheWidth,
                      null,
                      provider,
                    ),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => placeholder,
                  );
                },
              ),
            if (showTypeBadge)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
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
