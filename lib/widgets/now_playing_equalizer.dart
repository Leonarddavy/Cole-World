import 'dart:math';

import 'package:flutter/material.dart';

class NowPlayingEqualizer extends StatefulWidget {
  const NowPlayingEqualizer({
    super.key,
    this.isActive = true,
    this.color,
    this.size = 18,
  });

  final bool isActive;
  final Color? color;
  final double size;

  @override
  State<NowPlayingEqualizer> createState() => _NowPlayingEqualizerState();
}

class _NowPlayingEqualizerState extends State<NowPlayingEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? Theme.of(context).colorScheme.secondary;
    final inactiveColor = baseColor.withValues(alpha: 0.35);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;
          final heights = [
            0.35 + 0.55 * (0.5 + 0.5 * sin(t)),
            0.25 + 0.65 * (0.5 + 0.5 * sin(t + 1.8)),
            0.30 + 0.60 * (0.5 + 0.5 * sin(t + 3.1)),
          ];

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < heights.length; i++)
                Container(
                  width: widget.size / 6,
                  height: widget.size * heights[i],
                  margin: EdgeInsets.symmetric(horizontal: widget.size / 18),
                  decoration: BoxDecoration(
                    color: widget.isActive ? baseColor : inactiveColor,
                    borderRadius: BorderRadius.circular(widget.size / 8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

