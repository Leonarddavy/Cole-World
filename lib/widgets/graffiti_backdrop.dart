import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class GraffitiBackdrop extends StatefulWidget {
  const GraffitiBackdrop({super.key});

  static const List<String> showcaseAssets = [
    'assets/groove.jpg',
    'assets/groove2.jpg',
    'assets/jcole2.jpg',
    'assets/jcole3.jpg',
    'assets/KEKE2.jpg',
    'assets/KEKE3.jpg',
    'assets/KEKE5.jpg',
    'assets/KEKE6.jpg',
  ];

  @override
  State<GraffitiBackdrop> createState() => _GraffitiBackdropState();
}

class _GraffitiBackdropState extends State<GraffitiBackdrop> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || GraffitiBackdrop.showcaseAssets.isEmpty) {
        return;
      }
      setState(() => _index = (_index + 1) % GraffitiBackdrop.showcaseAssets.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Best-effort prefetch to avoid jarring first-time loads on transition.
    for (final asset in GraffitiBackdrop.showcaseAssets) {
      precacheImage(AssetImage(asset), context).catchError((_) {
        // Asset manifests on Flutter Web do not update with hot reload; ignore here.
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = GraffitiBackdrop.showcaseAssets.isEmpty
        ? null
        : GraffitiBackdrop.showcaseAssets[_index % GraffitiBackdrop.showcaseAssets.length];

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.02, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: asset == null
                  ? const SizedBox.expand()
                  : _BackdropImage(key: ValueKey(asset), asset: asset),
            ),
          ),
          // Scrim: keep the center more visible, darken edges for readability.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30B0A09),
                  Color(0x330B0A09),
                  Color(0xB30B0A09),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
          ),
          Positioned(
            left: -120,
            top: -140,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x553A2411), Color(0x0022160C)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -140,
            bottom: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x4433BEB2), Color(0x00111412)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x22FFFFFF),
                        Colors.transparent,
                      ],
                      stops: [0.46, 0.5, 0.54],
                      tileMode: TileMode.repeated,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _SprayPainter())),
          Positioned(
            right: 18,
            bottom: 18,
            child: Text(
              'VAULT',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 86,
                color: Colors.white.withValues(alpha: 0.05),
                letterSpacing: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    const contrast = 1.08;
    const offset = (1 - contrast) * 128;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0B0A09)),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          contrast, 0, 0, 0, offset,
          0, contrast, 0, 0, offset,
          0, 0, contrast, 0, offset,
          0, 0, 0, 1, 0,
        ]),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.expand();
          },
        ),
      ),
    );
  }
}

class _SprayPainter extends CustomPainter {
  const _SprayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(1337);
    for (int i = 0; i < 220; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.4 + 0.3;
      final opacity = random.nextDouble() * 0.05 + 0.02;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
