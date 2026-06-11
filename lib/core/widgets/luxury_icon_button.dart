import 'dart:ui';

import 'package:flutter/material.dart';

import '../haptics/hallaq_haptics.dart';
import '../theme/app_theme.dart';

class LuxuryIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final Color? iconColor;
  final Color? hoverIconColor;

  const LuxuryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.filled = true,
    this.iconColor,
    this.hoverIconColor,
  });

  @override
  State<LuxuryIconButton> createState() => _LuxuryIconButtonState();
}

class _LuxuryIconButtonState extends State<LuxuryIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final iconColor = widget.iconColor ?? AppTheme.text;
    final hoverIconColor = widget.hoverIconColor ?? AppTheme.text;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled
            ? () {
                HallaqHaptics.tap();
                widget.onPressed?.call();
              }
            : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.95 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: enabled ? 1 : 0.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: widget.filled ? 12 : 0, sigmaY: widget.filled ? 12 : 0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.filled ? AppTheme.surface.withValues(alpha: 0.9) : Colors.transparent,
                    border: Border.all(color: AppTheme.border),
                    boxShadow: widget.filled ? AppTheme.softShadow(opacity: _hovered ? 0.14 : 0.10) : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    color: _hovered ? hoverIconColor : iconColor,
                    size: widget.size * 0.48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
