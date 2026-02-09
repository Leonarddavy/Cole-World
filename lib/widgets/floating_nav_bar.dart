import 'dart:math';

import 'package:flutter/material.dart';

class NavItem {
  const NavItem({required this.label, required this.icon, this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final selectedIndex = widget.selectedIndex;
    final onSelected = widget.onSelected;

    final denominator = items.length <= 1 ? 1 : items.length - 1;
    final x = -1 + (2 * selectedIndex / denominator);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 22,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value;
          return ClipPath(
            clipper: _GraffitiWaveClipper(phase: phase),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1C1612), Color(0xFF0E0A08)],
                ),
              ),
              child: CustomPaint(
                foregroundPainter: _GraffitiBarPainter(phase: phase),
                child: child,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(x, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _SelectedSmear(selected: true),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int index = 0; index < items.length; index++)
                    Expanded(
                      child: _NavButton(
                        item: items[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1B1209) : Colors.white70;
    final baseStyle = Theme.of(context).textTheme.labelLarge ??
        const TextStyle(fontWeight: FontWeight.w600);
    final style = baseStyle.copyWith(
      color: color,
      fontSize: selected ? 12 : 11,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: selected ? 1.0 : 0.7,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedSlide(
            offset: selected ? Offset.zero : const Offset(0, 0.06),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    selected ? (item.selectedIcon ?? item.icon) : item.icon,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: style,
                  child: Transform.rotate(
                    angle: selected ? -0.03 : 0.02,
                    child: Text(item.label.toUpperCase()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedSmear extends StatelessWidget {
  const _SelectedSmear({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: const _SmearPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SmearPainter extends CustomPainter {
  const _SmearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      const Radius.circular(18),
    );

    // Soft glow underneath.
    final glow = Paint()
      ..color = const Color(0x33FFB547)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(rrect, glow);

    // Main paint fill.
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB547), Color(0xFFB8742C)],
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    // Slight "hand-drawn" outline by double-stroking with tiny offsets.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xAA1B1209);
    canvas.save();
    canvas.translate(0.6, 0.2);
    canvas.drawRRect(rrect, outline);
    canvas.translate(-1.1, 0.1);
    canvas.drawRRect(rrect, outline..color = const Color(0x551B1209));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraffitiWaveClipper extends CustomClipper<Path> {
  const _GraffitiWaveClipper({required this.phase});

  // 0..1 repeating value.
  final double phase;

  static Path pathForSize(Size size, {required double phase}) {
    final w = size.width;
    final h = size.height;
    const r = 22.0;

    final amp = min(8.0, h * 0.18);
    final base = amp * 0.45;
    final cycles = 2.4;
    final cycles2 = 1.1;
    final p = phase * 2 * pi;

    double topY(double x) {
      final t = x / w;
      final v = base +
          (amp * 0.55) * sin((t * cycles * 2 * pi) + p) +
          (amp * 0.18) * sin((t * cycles2 * 2 * pi) - (p * 1.4));
      return v.clamp(0.0, amp * 1.2);
    }

    double bottomY(double x) {
      final t = x / w;
      // Opposite direction for that "infinity loop" feel.
      final v = base +
          (amp * 0.55) * sin((t * cycles * 2 * pi) - p) +
          (amp * 0.18) * sin((t * cycles2 * 2 * pi) + (p * 1.2));
      final y = h - v;
      return y.clamp(h - amp * 1.2, h);
    }

    final startTop = topY(r);
    final startBottom = bottomY(w - r);

    final segments = max(16, ((w - 2 * r) / 10).round());

    final path = Path();
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, startTop);

    for (int i = 1; i <= segments; i++) {
      final x = r + ((w - 2 * r) * i / segments);
      path.lineTo(x, topY(x));
    }

    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, startBottom);

    for (int i = 1; i <= segments; i++) {
      final x = (w - r) - ((w - 2 * r) * i / segments);
      path.lineTo(x, bottomY(x));
    }

    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, r);
    path.close();
    return path;
  }

  @override
  Path getClip(Size size) => pathForSize(size, phase: phase);

  @override
  bool shouldReclip(covariant _GraffitiWaveClipper oldClipper) {
    return (oldClipper.phase - phase).abs() > 0.0001;
  }
}

class _GraffitiBarPainter extends CustomPainter {
  const _GraffitiBarPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _GraffitiWaveClipper.pathForSize(size, phase: phase);
    final rect = Offset.zero & size;

    // Border: slightly uneven, like marker/paint.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawPath(path, border);

    final border2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55000000);
    canvas.save();
    canvas.translate(0.8, 1.0);
    canvas.drawPath(path, border2);
    canvas.restore();

    // Spray texture overlay.
    final spray = Paint()..style = PaintingStyle.fill;
    final seed = 1337;
    final r = Random(seed);
    for (int i = 0; i < 110; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final radius = r.nextDouble() * 1.6 + 0.2;
      spray.color = Colors.white.withValues(alpha: r.nextDouble() * 0.06);
      canvas.drawCircle(Offset(x, y), radius, spray);
    }

    // A faint highlight streak to push the "painted" feel.
    final streak = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x22FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.7],
      ).createShader(rect)
      ..blendMode = BlendMode.screen;
    canvas.drawRect(rect, streak);
  }

  @override
  bool shouldRepaint(covariant _GraffitiBarPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.0001;
  }
}
