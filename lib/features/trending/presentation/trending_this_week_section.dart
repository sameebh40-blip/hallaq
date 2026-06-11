import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/reel.dart';
import '../../../core/models/trending_entry.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/section_header.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../data/trending_repository.dart';

class TrendingThisWeekSection extends ConsumerWidget {
  final String? currentBarberId;
  final String? currentShopId;
  final EdgeInsetsGeometry padding;
  final bool showHeader;
  final double height;

  const TrendingThisWeekSection({
    super.key,
    this.currentBarberId,
    this.currentShopId,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.showHeader = true,
    this.height = 128,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingThisWeekProvider);

    return AsyncValueWidget<List<TrendingEntry>>(
      value: trending,
      loading: const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (items) {
        final list = items.where((e) => e.entityId.isNotEmpty).toList(growable: false);
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) SectionHeader(title: 'Trending This Week'),
            SizedBox(
              height: height,
              child: ListView.separated(
                padding: padding,
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = list[index];
                  return SizedBox(
                    width: 250,
                    child: _TrendingCard(
                      entry: entry,
                      isCurrent: (entry.entityType == 'barber' && entry.entityId == currentBarberId) ||
                          (entry.entityType == 'shop' && entry.entityId == currentShopId),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrendingCard extends ConsumerWidget {
  final TrendingEntry entry;
  final bool isCurrent;

  const _TrendingCard({required this.entry, required this.isCurrent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _labelForKind(entry.kind);

    return LuxuryCard(
      onTap: () {
        if (entry.entityType == 'barber') context.push('/barber/${entry.entityId}');
        if (entry.entityType == 'shop') context.push('/shop/${entry.entityId}');
        if (entry.entityType == 'reel') context.push('/discover');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'YOU',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (entry.entityType) {
              'barber' => _BarberWinner(entry: entry),
              'shop' => _ShopWinner(entry: entry),
              _ => _ReelWinner(entry: entry),
            },
          ),
        ],
      ),
    );
  }
}

class _BarberWinner extends ConsumerWidget {
  final TrendingEntry entry;

  const _BarberWinner({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(barberByIdProvider(entry.entityId));
    return AsyncValueWidget(
      value: barberValue,
      loading: const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (barber) {
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 44,
                child: LuxuryNetworkImage(
                  imageUrl: barber.avatarUrl,
                  fallbackUrl: HallaqImages.professionalBarberPortrait(variant: '01'),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    barber.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${barber.ratingAvg.toStringAsFixed(1)} • ${barber.followersCount} followers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShopWinner extends ConsumerWidget {
  final TrendingEntry entry;

  const _ShopWinner({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(shopByIdProvider(entry.entityId));
    return AsyncValueWidget(
      value: shopValue,
      loading: const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (shop) {
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 44,
                child: LuxuryNetworkImage(
                  imageUrl: shop.logoUrl,
                  fallbackUrl: HallaqImages.premiumGrooming(variant: '01'),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shop.ratingAvg.toStringAsFixed(1)} • ${shop.area ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReelWinner extends ConsumerWidget {
  final TrendingEntry entry;

  const _ReelWinner({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelValue = ref.watch(trendingReelProvider(entry.entityId));
    return AsyncValueWidget<Reel?>(
      value: reelValue,
      loading: const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (reel) {
        if (reel == null) return const SizedBox.shrink();
        final thumb = (reel.thumbnailUrl ?? '').trim().isNotEmpty ? reel.thumbnailUrl : reel.mediaUrl;
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 44,
                child: LuxuryNetworkImage(
                  imageUrl: thumb,
                  fallbackUrl: HallaqImages.premiumGrooming(variant: '03'),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Most viewed reel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reel.caption ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _labelForKind(String kind) {
  return switch (kind) {
    'most_booked_barber' => 'Most booked',
    'most_viewed_reel' => 'Most viewed',
    'fastest_growing_barber' => 'Fastest growing',
    'most_followed_barber' => 'Most followed',
    'top_rated_shop' => 'Top rated shop',
    'top_rated_barber' => 'Top rated barber',
    _ => 'Trending',
  };
}
