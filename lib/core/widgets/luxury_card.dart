import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuxuryCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool glass;

  const LuxuryCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.glass = false,
  });

  @override
  State<LuxuryCard> createState() => _LuxuryCardState();
}

class _LuxuryCardState extends State<LuxuryCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    final content = Padding(padding: widget.padding, child: widget.child);

    final body = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: widget.glass ? 14 : 0, sigmaY: widget.glass ? 14 : 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.glass ? AppTheme.surface.withValues(alpha: 0.72) : AppTheme.card,
          borderRadius: radius,
          border: Border.all(color: AppTheme.border.withValues(alpha: widget.glass ? 0.85 : 1)),
          boxShadow: AppTheme.softShadow(opacity: _hovered ? 0.14 : 0.10),
        ),
        child: content,
      ),
    );

    if (widget.onTap == null) {
      return ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: body,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hovered = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.992 : 1,
            child: body,
          ),
        ),
      ),
    );
  }
}
