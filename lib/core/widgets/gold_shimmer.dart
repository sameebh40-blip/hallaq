import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GoldShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final BorderRadius? borderRadius;

  const GoldShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppTheme.radiusMd,
    this.borderRadius,
  });

  @override
  State<GoldShimmer> createState() => _GoldShimmerState();
}

class _GoldShimmerState extends State<GoldShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final x = -1.2 + (2.4 * t);
        final br = widget.borderRadius ?? BorderRadius.all(Radius.circular(widget.radius));
        return ClipRRect(
          borderRadius: br,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                gradient: LinearGradient(
                  begin: Alignment(x, -1),
                  end: Alignment(x + 1.2, 1),
                  colors: [
                    const Color(0xFF141414),
                    AppTheme.gold.withValues(alpha: 0.16),
                    const Color(0xFF141414),
                  ],
                  stops: const [0.2, 0.5, 0.8],
                  transform: const GradientRotation(math.pi / 10),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
