import 'package:flutter/material.dart';

import '../data/artist_editions.dart';
import '../theme/app_theme.dart';

/// A small preview of an artist edition's look: its background, accent
/// colours and display lettering.
class ArtistSwatch extends StatelessWidget {
  const ArtistSwatch({super.key, required this.edition, this.size = 44});

  final ArtistEdition edition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = edition.theme;
    final initials = edition.initials;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: look.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: look.primaryColor, width: size / 16),
        ),
        child: Text(
          initials,
          maxLines: 1,
          style: AppTheme.displayFont(
            look.displayFontKey,
            textStyle: TextStyle(
              color: look.secondaryColor,
              // A lone initial gets the room two would share.
              fontSize: size * (initials.length > 1 ? 0.4 : 0.52),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// One artist in a list to switch between, ticked when it's the current one.
class ArtistEditionTile extends StatelessWidget {
  const ArtistEditionTile({
    super.key,
    required this.edition,
    required this.selected,
    required this.onTap,
  });

  final ArtistEdition edition;
  final bool selected;

  /// Null leaves the tile inert, e.g. for the artist already showing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ArtistSwatch(edition: edition),
      title: Text(edition.name),
      subtitle: Text(edition.labelLine),
      selected: selected,
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
