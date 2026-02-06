import 'dart:async';

import 'package:flutter/material.dart';

class SplashCatalogPage extends StatefulWidget {
  const SplashCatalogPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF171411), Color(0xFF2B2117)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'J. Cole Vault',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quick Catalog Highlights',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return AnimatedScale(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      scale: _index == index ? 1 : 0.92,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color(0xE8221B14),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.year,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: const Color(0xFFE8B55B)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              Text(item.detail),
                            ],
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
                      width: _index == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _index == i
                            ? const Color(0xFFE4B159)
                            : Colors.white30,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.onFinished,
                child: const Text('Skip'),
              ),
              const SizedBox(height: 12),
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
