import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hallaq_mascot.dart';
import 'luxury_network_image.dart';

class PremiumHeroCard extends StatelessWidget {
  final String imageUrl;
  final String fallbackUrl;
  final String title;
  final String subtitle;
  final double height;
  final Widget? badge;
  final Widget? trailing;

  const PremiumHeroCard({
    super.key,
    required this.imageUrl,
    required this.fallbackUrl,
    required this.title,
    required this.subtitle,
    this.height = 220,
    this.badge,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          ...AppTheme.softShadow(opacity: 0.62),
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.18),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: LuxuryNetworkImage(
                imageUrl: imageUrl,
                fallbackUrl: fallbackUrl,
                borderRadius: BorderRadius.zero,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0xB3000000),
                      Color(0xF0000000),
                    ],
                    stops: [0, 0.65, 1],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 14,
              start: 14,
              child: badge ??
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(
                          'Premium',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
            ),
            if (trailing != null)
              PositionedDirectional(
                top: 12,
                end: 12,
                child: trailing!,
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const HallaqMascot(size: 42, animated: false),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.96),
                                  height: 1.05,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

