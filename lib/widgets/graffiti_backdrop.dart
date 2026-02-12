import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/local_image.dart';

class GraffitiBackdrop extends StatefulWidget {
  const GraffitiBackdrop({super.key});

  static const List<String> defaultShowcaseAssets = [
    'assets/groove.jpg',
    'assets/groove2.jpg',
    'assets/jcole2.jpg',
    'assets/jcole3.jpg',
    'assets/KEKE2.jpg',
    'assets/KEKE3.jpg',
    'assets/KEKE5.jpg',
    'assets/KEKE6.jpg',
  ];

  static final ValueNotifier<List<String>> _sourcesListenable = ValueNotifier([
    ...defaultShowcaseAssets,
  ]);

  static ValueListenable<List<String>> get sourcesListenable =>
      _sourcesListenable;

  static List<String> get currentSources => _sourcesListenable.value;

  static void setCustomSources(List<String> customSources) {
    final cleaned = customSources
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final next = cleaned.isEmpty ? [...defaultShowcaseAssets] : cleaned;
    final previous = _sourcesListenable.value;
    var same = next.length == previous.length;
    if (same) {
      for (int i = 0; i < next.length; i++) {
        if (next[i] != previous[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) {
      return;
    }
    _sourcesListenable.value = next;
  }

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
      final sources = GraffitiBackdrop.currentSources;
      if (!mounted || sources.isEmpty) {
        return;
      }
      setState(() => _index = (_index + 1) % sources.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final source in GraffitiBackdrop.currentSources) {
      if (!source.startsWith('assets/')) {
        continue;
      }
      precacheImage(AssetImage(source), context).catchError((_) {});
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

    return IgnorePointer(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: GraffitiBackdrop.sourcesListenable,
        builder: (context, sources, _) {
          final source = sources.isEmpty
              ? null
              : sources[_index % sources.length];

          return Stack(
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
                        scale: Tween<double>(
                          begin: 1.02,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: source == null
                      ? const SizedBox.expand()
                      : _BackdropImage(key: ValueKey(source), source: source),
                ),
              ),
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
              const Positioned.fill(
                child: CustomPaint(painter: _SprayPainter()),
              ),
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
          );
        },
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({super.key, required this.source});

  final String source;

  Widget _buildSourceImage() {
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }
    if (canLoadLocalImage(source)) {
      return SizedBox.expand(child: buildLocalImage(source, fit: BoxFit.cover));
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) {
        return const SizedBox.expand();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const contrast = 1.08;
    const offset = (1 - contrast) * 128;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0B0A09)),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          contrast,
          0,
          0,
          0,
          offset,
          0,
          contrast,
          0,
          0,
          offset,
          0,
          0,
          contrast,
          0,
          offset,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: _buildSourceImage(),
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
