import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuxuryBackground extends StatelessWidget {
  final String? imageUrl;
  final Widget child;

  const LuxuryBackground({
    super.key,
    required this.child,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppTheme.background),
            child: imageUrl == null
                ? const SizedBox.shrink()
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.35),
                  AppTheme.background.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
