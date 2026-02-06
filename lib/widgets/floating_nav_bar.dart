import 'package:flutter/material.dart';

class NavItem {
  const NavItem({required this.label, required this.icon, this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class FloatingNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final denominator = items.length <= 1 ? 1 : items.length - 1;
    final x = -1 + (2 * selectedIndex / denominator);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xE81B1A18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                alignment: Alignment(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDEA84A), Color(0xFF92632D)],
                      ),
                    ),
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
    final color = selected ? const Color(0xFF2A1A07) : Colors.white70;

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
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: selected ? 12 : 11,
                  ),
                  child: Text(item.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
