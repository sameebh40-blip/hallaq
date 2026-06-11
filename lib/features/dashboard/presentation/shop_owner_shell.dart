import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';

class ShopOwnerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShopOwnerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(scaffoldBackgroundColor: AppTheme.background);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          bottom: false,
          child: navigationShell,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: HallaqBottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(i),
            items: const [
              HallaqBottomNavItem(icon: Icons.home_rounded, label: 'Dashboard'),
              HallaqBottomNavItem(icon: Icons.event_available_rounded, label: 'Bookings'),
              HallaqBottomNavItem(icon: Icons.content_cut_rounded, label: 'Barbers'),
              HallaqBottomNavItem(icon: Icons.people_alt_rounded, label: 'Customers'),
              HallaqBottomNavItem(icon: Icons.more_horiz_rounded, label: 'More'),
            ],
            onActionTap: () => navigationShell.goBranch(5),
            actionSelected: navigationShell.currentIndex == 5,
            actionIcon: Icons.design_services_rounded,
            actionLabel: 'Services',
          ),
        ),
      ),
    );
  }
}

class ShopOwnerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ShopOwnerBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final compact = w < 420 || media.textScaler.scale(1) > 1.05;
    const centerIndex = 5;
    final items = const [
      _ShopNavItem(icon: Icons.home_rounded, label: 'Dashboard', compactLabel: 'Dash', index: 0),
      _ShopNavItem(icon: Icons.event_available_rounded, label: 'Bookings', compactLabel: 'Books', index: 1),
      _ShopNavItem(icon: Icons.content_cut_rounded, label: 'Barbers', compactLabel: 'Team', index: 2),
      _ShopNavItem(icon: Icons.people_alt_rounded, label: 'Customers', compactLabel: 'CRM', index: 3),
      _ShopNavItem(icon: Icons.more_horiz_rounded, label: 'More', compactLabel: 'More', index: 4),
    ];

    const gapWidth = 78.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final selectedCenter = currentIndex == centerIndex;
          final left = (c.maxWidth - gapWidth) / 2;
          return SizedBox(
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.softShadow(opacity: 0.12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ShopNavButton(
                            icon: items[0].icon,
                            label: compact ? items[0].compactLabel : items[0].label,
                            selected: currentIndex == items[0].index,
                            onTap: () => onTap(items[0].index),
                          ),
                        ),
                        Expanded(
                          child: _ShopNavButton(
                            icon: items[1].icon,
                            label: compact ? items[1].compactLabel : items[1].label,
                            selected: currentIndex == items[1].index,
                            onTap: () => onTap(items[1].index),
                          ),
                        ),
                        const SizedBox(width: gapWidth),
                        Expanded(
                          child: _ShopNavButton(
                            icon: items[2].icon,
                            label: compact ? items[2].compactLabel : items[2].label,
                            selected: currentIndex == items[2].index,
                            onTap: () => onTap(items[2].index),
                          ),
                        ),
                        Expanded(
                          child: _ShopNavButton(
                            icon: items[3].icon,
                            label: compact ? items[3].compactLabel : items[3].label,
                            selected: currentIndex == items[3].index,
                            onTap: () => onTap(items[3].index),
                          ),
                        ),
                        Expanded(
                          child: _ShopNavButton(
                            icon: items[4].icon,
                            label: compact ? items[4].compactLabel : items[4].label,
                            selected: currentIndex == items[4].index,
                            onTap: () => onTap(items[4].index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  left: left,
                  width: gapWidth,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(centerIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.goldGradient,
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.9), width: 1.2),
                          boxShadow: selectedCenter ? AppTheme.goldGlow(opacity: 0.18, blur: 30, y: 16) : AppTheme.goldGlow(opacity: 0.10),
                        ),
                        child: Icon(
                          Icons.design_services_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopNavItem {
  final IconData icon;
  final String label;
  final String compactLabel;
  final int index;

  const _ShopNavItem({required this.icon, required this.label, required this.index, String? compactLabel})
      : compactLabel = compactLabel ?? label;
}

class _ShopNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopNavButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.gold : AppTheme.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              SizedBox(
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
