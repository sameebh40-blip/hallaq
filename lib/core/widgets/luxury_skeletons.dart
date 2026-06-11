import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'gold_shimmer.dart';

class HorizontalCardsSkeleton extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double cardHeight;
  final EdgeInsets padding;

  const HorizontalCardsSkeleton({
    super.key,
    this.count = 4,
    required this.cardWidth,
    required this.cardHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      scrollDirection: Axis.horizontal,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, __) => GoldShimmer(
        width: cardWidth,
        height: cardHeight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }
}

class HorizontalAvatarsSkeleton extends StatelessWidget {
  final int count;
  final double itemSize;
  final EdgeInsets padding;

  const HorizontalAvatarsSkeleton({
    super.key,
    this.count = 6,
    this.itemSize = 62,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      scrollDirection: Axis.horizontal,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) => Column(
        children: [
          GoldShimmer(
            width: itemSize,
            height: itemSize,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          GoldShimmer(
            width: itemSize * 0.9,
            height: 12,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}

class FullScreenFeedSkeleton extends StatelessWidget {
  final int count;

  const FullScreenFeedSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: count,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            Positioned.fill(
              child: GoldShimmer(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.86),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 16,
              end: 86,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoldShimmer(
                    width: 220,
                    height: 20,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 10),
                  GoldShimmer(
                    width: 280,
                    height: 16,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              end: 14,
              bottom: 150,
              child: Column(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: EdgeInsets.only(bottom: i == 4 ? 0 : 14),
                    child: GoldShimmer(
                      width: 58,
                      height: 58,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
