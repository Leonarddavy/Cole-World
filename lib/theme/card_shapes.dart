import 'package:flutter/material.dart';

/// The look of cards, tiles and covers, chosen in Settings → Card shape.
enum CardShapeStyle { rounded, sharp, soft, cut, squircle, round }

extension CardShapeStyleUi on CardShapeStyle {
  String get label => switch (this) {
    CardShapeStyle.rounded => 'Rounded',
    CardShapeStyle.sharp => 'Sharp',
    CardShapeStyle.soft => 'Soft',
    CardShapeStyle.cut => 'Cut corners',
    CardShapeStyle.squircle => 'Squircle',
    CardShapeStyle.round => 'Circle',
  };

  String get description => switch (this) {
    CardShapeStyle.rounded => 'Gently rounded corners',
    CardShapeStyle.sharp => 'Square corners, like printed posters',
    CardShapeStyle.soft => 'Extra-round, pillowy corners',
    CardShapeStyle.cut => 'Clipped corners, like a sticker or stencil',
    CardShapeStyle.squircle => 'Smooth app-icon curves',
    CardShapeStyle.round => 'Round covers like records, pill-shaped cards',
  };

  static CardShapeStyle fromKey(String? key) =>
      CardShapeStyle.values.firstWhere(
        (style) => style.name == key,
        orElse: () => CardShapeStyle.rounded,
      );
}

/// Hands out shapes in the chosen style. Widgets ask for the shape of
/// something "normally drawn with corner radius r", so each keeps its
/// proportions whatever style is picked.
@immutable
class CardShapes extends ThemeExtension<CardShapes> {
  const CardShapes(this.style);

  static const CardShapes fallback = CardShapes(CardShapeStyle.rounded);

  final CardShapeStyle style;

  static CardShapes of(BuildContext context) =>
      Theme.of(context).extension<CardShapes>() ?? fallback;

  /// A card, tile or panel. A radius of 0 always stays square (used where a
  /// shape is nested inside another, e.g. art inside a tile).
  OutlinedBorder card(double radius, {BorderSide side = BorderSide.none}) {
    if (radius <= 0) {
      return RoundedRectangleBorder(side: side);
    }
    return switch (style) {
      CardShapeStyle.rounded => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      CardShapeStyle.sharp => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius < 3 ? radius : 3),
        side: side,
      ),
      CardShapeStyle.soft => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 1.8),
        side: side,
      ),
      CardShapeStyle.cut => BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 0.75),
        side: side,
      ),
      CardShapeStyle.squircle => ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 2.4),
        side: side,
      ),
      CardShapeStyle.round => StadiumBorder(side: side),
    };
  }

  /// Square cover art. With [CardShapeStyle.round] covers become circles.
  OutlinedBorder artwork(double radius, {BorderSide side = BorderSide.none}) {
    if (radius > 0 && style == CardShapeStyle.round) {
      return CircleBorder(side: side);
    }
    return card(radius, side: side);
  }

  @override
  CardShapes copyWith({CardShapeStyle? style}) =>
      CardShapes(style ?? this.style);

  @override
  CardShapes lerp(covariant CardShapes? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Clips [child] to [shape] and draws the shape's outline over it.
class ShapedBox extends StatelessWidget {
  const ShapedBox({
    super.key,
    required this.shape,
    required this.child,
    this.outline,
    this.shadows,
  });

  final OutlinedBorder shape;
  final Widget child;

  /// Drawn on top, so images don't cover the edge.
  final BorderSide? outline;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    Widget result = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: child,
    );
    if (outline != null) {
      result = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: shape.copyWith(side: outline)),
        child: result,
      );
    }
    if (shadows != null) {
      result = DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: shadows),
        child: result,
      );
    }
    return result;
  }
}
