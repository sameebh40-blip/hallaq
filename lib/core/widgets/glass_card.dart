import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blur;
  final Color tint;
  final Color borderColor;
  final bool glow;
  final Color glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = 18,
    this.tint = const Color(0x16161616),
    this.borderColor = const Color(0x26FFFFFF),
    this.glow = false,
    this.glowColor = const Color(0xFFD4AF37),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [
              const BoxShadow(
                color: Color(0x7A000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
              if (glow)
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.16),
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
