import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/local_image.dart';

/// The photo-and-spray-paint background behind every screen.
///
/// All backdrops show the same image: one is picked per app launch, and when
/// rotation is turned on a single shared timer advances it for every screen
/// at once (rather than one timer per open page).
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

  static const Duration rotationInterval = Duration(seconds: 12);

  static final ValueNotifier<List<String>> _sourcesListenable = ValueNotifier([
    ...defaultShowcaseAssets,
  ]);

  /// Off by default: a changing background competes with the content.
  static final ValueNotifier<bool> _rotationEnabled = ValueNotifier(false);

  /// Shared position in the image list, offset by a per-launch random start.
  static final ValueNotifier<int> _step = ValueNotifier(0);
  static final int _launchOffset = Random().nextInt(1 << 16);
  static Timer? _timer;
  static int _mounted = 0;

  static ValueListenable<List<String>> get sourcesListenable =>
      _sourcesListenable;

  static List<String> get currentSources => _sourcesListenable.value;

  static bool get rotationEnabled => _rotationEnabled.value;

  static void setRotationEnabled(bool enabled) {
    _rotationEnabled.value = enabled;
    _syncTimer();
  }

  /// The built-in images, which differ per artist edition.
  static List<String> _defaultSources = defaultShowcaseAssets;
  static List<String> _customSources = const [];

  static void setDefaultSources(List<String> sources) {
    _defaultSources = sources.isEmpty ? defaultShowcaseAssets : sources;
    setCustomSources(_customSources);
  }

  static void setCustomSources(List<String> customSources) {
    final cleaned = customSources
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    _customSources = cleaned;
    final next = cleaned.isEmpty ? [..._defaultSources] : cleaned;
    if (listEquals(next, _sourcesListenable.value)) {
      return;
    }
    _sourcesListenable.value = next;
    _syncTimer();
  }

  static void _syncTimer() {
    final shouldRun =
        _rotationEnabled.value && _mounted > 0 && currentSources.length > 1;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(rotationInterval, (_) => _step.value++);
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  State<GraffitiBackdrop> createState() => _GraffitiBackdropState();
}

class _GraffitiBackdropState extends State<GraffitiBackdrop> {
  @override
  void initState() {
    super.initState();
    GraffitiBackdrop._mounted++;
    GraffitiBackdrop._syncTimer();
  }

  @override
  void dispose() {
    GraffitiBackdrop._mounted--;
    GraffitiBackdrop._syncTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: GraffitiBackdrop._sourcesListenable,
        builder: (context, sources, _) {
          return ValueListenableBuilder<int>(
            valueListenable: GraffitiBackdrop._step,
            builder: (context, step, _) {
              final source = sources.isEmpty
                  ? null
                  : sources[(GraffitiBackdrop._launchOffset +
                            (reduceMotion ? 0 : step)) %
                        sources.length];
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 1400),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: source == null
                          ? const SizedBox.expand()
                          : _BackdropImage(
                              key: ValueKey(source),
                              source: source,
                            ),
                    ),
                  ),
                  // Darker than before at the top and bottom, where text and
                  // controls sit, so content stays readable over any photo.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xCC0B0A09),
                          Color(0x660B0A09),
                          Color(0xD90B0A09),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  Positioned(
                    left: -120,
                    top: -140,
                    child: _Glow(color: scheme.primary, alpha: 0.18),
                  ),
                  Positioned(
                    right: -140,
                    bottom: -120,
                    child: _Glow(color: scheme.secondary, alpha: 0.16),
                  ),
                  const Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _SprayPainter()),
                    ),
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
          );
        },
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
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
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
      );
    }
    if (canLoadLocalImage(source)) {
      return SizedBox.expand(child: buildLocalImage(source, fit: BoxFit.cover));
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0B0A09)),
      child: _buildSourceImage(),
    );
  }
}

class _SprayPainter extends CustomPainter {
  const _SprayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(1337);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 220; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.4 + 0.3;
      final opacity = random.nextDouble() * 0.05 + 0.02;
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
