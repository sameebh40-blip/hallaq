import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hallaq_logo.dart';

class HallaqMascot extends StatelessWidget {
  final double size;
  final bool animated;
  final String? assetKey;

  const HallaqMascot({
    super.key,
    this.size = 120,
    this.animated = true,
    this.assetKey,
  });

  @override
  Widget build(BuildContext context) {
    if (!animated) return _Body(size: size, t: 0, assetKey: assetKey);
    return _Animated(size: size, assetKey: assetKey);
  }
}

class _Animated extends StatefulWidget {
  final double size;
  final String? assetKey;

  const _Animated({required this.size, required this.assetKey});

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => _Body(size: widget.size, t: _c.value, assetKey: widget.assetKey),
    );
  }
}

class _Body extends StatelessWidget {
  final double size;
  final double t;
  final String? assetKey;

  const _Body({required this.size, required this.t, required this.assetKey});

  @override
  Widget build(BuildContext context) {
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
    final glow = 0.18 + (pulse * 0.22);
    final scale = 0.98 + (pulse * 0.04);
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: glow),
              blurRadius: 44,
              spreadRadius: 1,
            ),
          ],
        ),
        child: HallaqLogo(size: size, assetKey: assetKey),
      ),
    );
  }
}
