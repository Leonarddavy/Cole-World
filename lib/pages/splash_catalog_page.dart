import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/graffiti_scaffold.dart';
import '../widgets/graffiti_tag.dart';

class SplashCatalogPage extends StatefulWidget {
  const SplashCatalogPage({
    super.key,
    required this.onFinished,
    this.autoAdvance = true,
    this.tagLabel = 'Vault Preview',
    this.primaryCtaLabel = 'Enter Vault',
    this.secondaryCtaLabel = 'Skip',
  });

  final VoidCallback onFinished;
  final bool autoAdvance;
  final String tagLabel;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;

  @override
  State<SplashCatalogPage> createState() => _SplashCatalogPageState();
}

class _SplashCatalogPageState extends State<SplashCatalogPage> {
  final PageController _pageController = PageController();

  final List<_CatalogItem> _items = const [
    _CatalogItem(
      year: 'Grammy Era',
      title: 'Best Rap Song Winner',
      detail:
          'Recognized at the Grammy Awards for songwriting and lyrical precision.',
    ),
    _CatalogItem(
      year: '2014',
      title: 'Forest Hills Milestone',
      detail:
          '2014 Forest Hills Drive became one of modern rap\'s most defining albums.',
    ),
    _CatalogItem(
      year: 'Dreamville',
      title: 'Label Architect',
      detail:
          'Built Dreamville into a respected roster and collaborative movement.',
    ),
    _CatalogItem(
      year: 'Feature Run',
      title: 'Elite Guest Verses',
      detail:
          'Delivered standout verses across the 2020s with technical consistency.',
    ),
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.autoAdvance) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 2100), (_) {
      if (!mounted) {
        return;
      }
      if (_index >= _items.length - 1) {
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 600), widget.onFinished);
        return;
      }
      _index += 1;
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GraffitiScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              GraffitiTag(label: widget.tagLabel),
              const SizedBox(height: 14),
              Center(
                child: Image.asset(
                  'assets/logo26.png',
                  height: 86,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'II.VI',
                style: theme.textTheme.displayLarge,
              ),
              Text(
                'Vault',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quick Catalog Highlights',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: widget.autoAdvance
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return AnimatedScale(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      scale: _index == index ? 1 : 0.92,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF241B14), Color(0xFF17110D)],
                            ),
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 18,
                                offset: Offset(0, 12),
                              ),
                            ],
                        ),
                          padding: const EdgeInsets.all(22),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxHeight < 150;
                              final titleLines = compact ? 1 : 2;
                              final detailLines = compact ? 2 : 3;
                              final titleSpacing = compact ? 8.0 : 16.0;
                              final detailSpacing = compact ? 6.0 : 12.0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GraffitiTag(label: item.year),
                                  SizedBox(height: titleSpacing),
                                  Text(
                                    item.title,
                                    maxLines: titleLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                  SizedBox(height: detailSpacing),
                                  Flexible(
                                    child: Text(
                                      item.detail,
                                      maxLines: detailLines,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < _items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: _index == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _index == i
                            ? theme.colorScheme.primary
                            : Colors.white30,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.onFinished,
                    child: Text(widget.secondaryCtaLabel),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: widget.onFinished,
                    child: Text(widget.primaryCtaLabel),
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

class _CatalogItem {
  const _CatalogItem({
    required this.year,
    required this.title,
    required this.detail,
  });

  final String year;
  final String title;
  final String detail;
}
