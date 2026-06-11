import 'dart:ui';

import 'package:flutter/material.dart';

import '../haptics/hallaq_haptics.dart';
import '../theme/app_theme.dart';
import 'luxury_loader.dart';

enum LuxuryButtonVariant { primary, secondary, ghost }

class LuxuryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final LuxuryButtonVariant variant;
  final bool expanded;
  final bool isLoading;
  final IconData? icon;

  const LuxuryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LuxuryButtonVariant.primary,
    this.expanded = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<LuxuryButton> createState() => _LuxuryButtonState();
}

class _LuxuryButtonState extends State<LuxuryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.985 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: enabled ? 1 : 0.55,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.variant == LuxuryButtonVariant.ghost ? 10 : 0,
                sigmaY: widget.variant == LuxuryButtonVariant.ghost ? 10 : 0,
              ),
              child: DecoratedBox(
                decoration: _decoration(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Center(
                    child: widget.isLoading
                        ? const LuxuryLoader(size: 20)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, size: 18, color: _foregroundColor(context)),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                widget.label,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: _foregroundColor(context),
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tappable = MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: enabled
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: () {
                HallaqHaptics.tap();
                widget.onPressed?.call();
              },
              child: child,
            )
          : IgnorePointer(child: child),
    );

    if (!widget.expanded) return tappable;
    return SizedBox(width: double.infinity, child: tappable);
  }

  Color _foregroundColor(BuildContext context) {
    return switch (widget.variant) {
      LuxuryButtonVariant.primary => const Color(0xFF111111),
      LuxuryButtonVariant.secondary => const Color(0xFF111111),
      LuxuryButtonVariant.ghost => AppTheme.text,
    };
  }

  BoxDecoration _decoration(BuildContext context) {
    return switch (widget.variant) {
      LuxuryButtonVariant.primary => BoxDecoration(
          color: AppTheme.gold,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow(opacity: _hovered ? 0.14 : 0.10),
        ),
      LuxuryButtonVariant.secondary => BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow(opacity: _hovered ? 0.12 : 0.08),
        ),
      LuxuryButtonVariant.ghost => BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
    };
  }
}
