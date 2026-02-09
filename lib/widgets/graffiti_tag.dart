import 'package:flutter/material.dart';

class GraffitiTag extends StatelessWidget {
  const GraffitiTag({
    super.key,
    required this.label,
    this.fillColor,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final String label;
  final Color? fillColor;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedBorder = borderColor ?? Colors.white24;
    final resolvedText =
        textColor ?? Theme.of(context).colorScheme.onSurface;
    final decoration = fillColor == null
        ? const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2A2117), Color(0xFF16110C)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          );

    return Container(
      padding: padding,
      decoration: decoration.copyWith(
        border: Border.all(color: resolvedBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: resolvedText,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
