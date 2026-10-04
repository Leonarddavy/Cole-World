import 'package:flutter/material.dart';

import '../models/collection_models.dart';

/// One entry in a song's action sheet.
class TrackAction {
  const TrackAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

/// Shows a song's actions as a bottom sheet (the mobile-friendly version of
/// a ⋮ menu). The chosen action runs after the sheet has closed.
Future<void> showTrackActionsSheet(
  BuildContext context, {
  required Track track,
  required List<TrackAction> actions,
  ImageProvider? artwork,
  String? subtitle,
}) async {
  final chosen = await showModalBottomSheet<TrackAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 48,
                  child: artwork == null
                      ? ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        )
                      : Image(image: artwork, fit: BoxFit.cover),
                ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                subtitle ?? track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  color: action.destructive ? scheme.error : null,
                ),
                title: Text(
                  action.label,
                  style: action.destructive
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      );
    },
  );
  chosen?.onSelected();
}
