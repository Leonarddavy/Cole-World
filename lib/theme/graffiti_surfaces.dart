import 'package:flutter/material.dart';

/// Shared surface treatments derived from the active color scheme, so every
/// card, tile and badge follows the colors chosen in the theme editor.
extension GraffitiSurfaces on ColorScheme {
  /// Cards and list tiles.
  LinearGradient get cardGradient =>
      LinearGradient(colors: [surfaceContainerHigh, surfaceContainer]);

  /// Raised elements such as tags, the mini player and nav buttons.
  LinearGradient get raisedGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceContainerHighest, surfaceContainerLow],
  );

  /// The selected / accent fill (e.g. the active nav button).
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color.lerp(primary, Colors.black, 0.28)!],
  );

  /// Placeholder artwork when a collection has no cover.
  LinearGradient get artworkPlaceholderGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(surfaceContainerHighest, primary, 0.25)!, surface],
  );
}
