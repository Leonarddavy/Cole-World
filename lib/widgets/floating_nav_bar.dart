import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/graffiti_surfaces.dart';

class NavItem {
  const NavItem({required this.label, required this.icon, this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Bottom navigation as standalone floating buttons: [visibleCount] fit the
/// width at once and the rest are a swipe away, with dots showing the page.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.visibleCount = 3,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int visibleCount;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  late final PageController _pageController = PageController(
    initialPage: _pageOf(widget.selectedIndex),
  );
  late int _page = _pageOf(widget.selectedIndex);

  int get _pageCount => (widget.items.length / widget.visibleCount).ceil();

  int _pageOf(int index) => index ~/ widget.visibleCount;

  @override
  void didUpdateWidget(covariant FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selection changed from elsewhere (e.g. "Back To Vault"): bring the
    // selected button into view.
    final target = _pageOf(widget.selectedIndex).clamp(0, _pageCount - 1);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        target != _page &&
        _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index != widget.selectedIndex) {
      HapticFeedback.selectionClick();
    }
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final perPage = widget.visibleCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 60,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, page) {
                return Row(
                  children: [
                    for (var slot = 0; slot < perPage; slot++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final index = page * perPage + slot;
                            if (index >= items.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 6,
                              ),
                              child: _FloatingNavButton(
                                item: items[index],
                                selected: index == widget.selectedIndex,
                                onTap: () => _select(index),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_pageCount > 1)
            _PageDots(
              count: _pageCount,
              current: _page,
              onTap: (page) => _pageController.animateToPage(
                page,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingNavButton extends StatelessWidget {
  const _FloatingNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final labelStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: selected ? 1.0 : 0.6,
        );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.4)
                    : const Color(0x99000000),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.4)
                    : scheme.outline,
                width: 1.2,
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: selected
                    ? scheme.accentGradient
                    : scheme.raisedGradient,
              ),
              child: InkWell(
                onTap: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? (item.selectedIcon ?? item.icon) : item.icon,
                      color: foreground,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.onTap,
  });

  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var page = 0; page < count; page++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(page),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: page == current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: page == current
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
