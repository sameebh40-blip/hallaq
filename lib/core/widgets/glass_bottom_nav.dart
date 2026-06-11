import 'package:flutter/material.dart';

import '../haptics/hallaq_haptics.dart';
import '../theme/app_theme.dart';

class GlassBottomNavItem {
  final IconData icon;
  final String label;

  const GlassBottomNavItem({required this.icon, required this.label});
}

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassBottomNavItem> items;
  final VoidCallback? onActionTap;
  final bool actionSelected;
  final IconData actionIcon;
  final String? actionLabel;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onActionTap,
    this.actionSelected = false,
    this.actionIcon = Icons.add_rounded,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final mid = (items.length / 2).ceil();
    final left = items.take(mid).toList();
    final right = items.skip(mid).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final compact = maxWidth < 390;
        final navHeight = compact ? 82.0 : 88.0;
        final outerPadding = compact ? const EdgeInsets.fromLTRB(10, 8, 10, 12) : const EdgeInsets.fromLTRB(14, 8, 14, 14);
        final shellPadding = compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        final actionGap = onActionTap == null ? (compact ? 10.0 : 14.0) : (compact ? 70.0 : 90.0);
        final actionOffset = compact ? -22.0 : -28.0;

        Widget buildNavGroup(List<GlassBottomNavItem> group, int startIndex) {
          return Row(
            children: List.generate(group.length, (i) {
              final index = startIndex + i;
              final item = group[i];
              final selected = index == currentIndex;
              return Expanded(
                child: _NavButton(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  compact: compact,
                  onTap: () => onTap(index),
                ),
              );
            }),
          );
        }

        return Padding(
          padding: outerPadding,
          child: SizedBox(
            height: navHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    padding: shellPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        ...AppTheme.softShadow(opacity: 0.18),
                        ...AppTheme.goldGlow(opacity: 0.04, blur: 22, y: 6),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          AppTheme.surface,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: buildNavGroup(left, 0)),
                        SizedBox(width: actionGap),
                        Expanded(child: buildNavGroup(right, mid)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: actionOffset,
                  child: onActionTap == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: _ActionButton(
                            icon: actionIcon,
                            onTap: onActionTap,
                            label: actionLabel,
                            selected: actionSelected,
                            compact: compact,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? AppTheme.gold : AppTheme.textMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HallaqHaptics.selection();
          widget.onTap();
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.03 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 12, vertical: widget.compact ? 6 : 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.selected ? AppTheme.gold.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(
                color: widget.selected ? AppTheme.gold.withValues(alpha: 0.26) : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: color, size: widget.compact ? 20 : 22),
                SizedBox(height: widget.compact ? 4 : 6),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: widget.compact ? 10 : null,
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

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final bool selected;
  final bool compact;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.label,
    required this.selected,
    required this.compact,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final borderColor = AppTheme.gold.withValues(alpha: widget.selected ? 0.96 : 0.74);
    final shadow = widget.selected ? 0.42 : 0.30;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HallaqHaptics.tap();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.compact ? 64 : 72,
              height: widget.compact ? 64 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.goldGradient,
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  ...AppTheme.softShadow(opacity: shadow),
                  ...AppTheme.goldGlow(opacity: widget.selected ? 0.30 : 0.22, blur: widget.selected ? 38 : 32, y: 14),
                ],
              ),
              child: Icon(widget.icon, color: Colors.black, size: widget.compact ? 26 : 30),
            ),
            if ((widget.label ?? '').trim().isNotEmpty) ...[
              SizedBox(height: widget.compact ? 4 : 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.compact ? 82 : 96),
                child: Text(
                  widget.label!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: widget.selected ? AppTheme.gold : AppTheme.textMuted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        fontSize: widget.compact ? 10 : null,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
