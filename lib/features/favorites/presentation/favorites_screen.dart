import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/follow_favorites_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qp = GoRouterState.of(context).uri.queryParameters['tab'];
    final isShops = qp == 'shops';

    final barbers = ref.watch(followedBarbersProvider);
    final shops = ref.watch(followedShopsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(
          isShops ? 'Favorite Shops' : 'Favorite Barbers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      child: isShops
          ? AsyncValueWidget(
              value: shops,
              data: (items) => _ShopsList(items: items),
            )
          : AsyncValueWidget(
              value: barbers,
              data: (items) => _BarbersList(items: items),
            ),
    );
  }
}

class _BarbersList extends ConsumerWidget {
  final List<FollowedBarberCard> items;

  const _BarbersList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No favorite barbers yet',
          description: 'Barbers you follow will appear here for quick access.',
          compact: true,
          showMascot: true,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemBuilder: (_, i) {
        final e = items[i];
        final b = e.barber;
        final verified = b.badgeVerified;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/barber/${b.slug.isNotEmpty ? b.slug : b.id}'),
          child: HallaqCard(
            glass: true,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipOval(
                  child: LuxuryNetworkImage(
                    imageUrl: b.avatarUrl,
                    fallbackUrl: HallaqImages.barberAvatar(),
                    width: 54,
                    height: 54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (e.shopName ?? '').trim().isEmpty ? (b.area ?? '') : e.shopName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                          const SizedBox(width: 4),
                          Text(
                            b.ratingAvg.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (b.ratingCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${b.ratingCount})',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(followFavoritesRepositoryProvider).unfollow(targetType: 'barber', targetId: b.id);
                      ref.invalidate(followedBarbersProvider);
                    } catch (err) {
                      if (context.mounted) showErrorSnackBar(context, err);
                    }
                  },
                  icon: const Icon(Icons.favorite_rounded, color: AppTheme.gold),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _ShopsList extends ConsumerWidget {
  final List<Barbershop> items;

  const _ShopsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No favorite shops yet',
          description: 'Shops you follow will appear here for faster return visits.',
          compact: true,
          showMascot: true,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemBuilder: (_, i) {
        final s = items[i];
        final verified = s.badgeVerified;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/shop/${s.id}'),
          child: HallaqCard(
            glass: true,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LuxuryNetworkImage(
                    imageUrl: s.logoUrl,
                    fallbackUrl: HallaqImages.barberShopExterior(),
                    width: 54,
                    height: 54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.area ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(followFavoritesRepositoryProvider).unfollow(targetType: 'shop', targetId: s.id);
                      ref.invalidate(followedShopsProvider);
                    } catch (err) {
                      if (context.mounted) showErrorSnackBar(context, err);
                    }
                  },
                  icon: const Icon(Icons.bookmark_rounded, color: AppTheme.gold),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}
