import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/geo/distance_providers.dart';
import '../../../core/geo/eta.dart';
import '../../../core/geo/maps_launcher.dart';
import '../../../core/geo/opening_status.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/links/app_links.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/models/before_after_item.dart';
import '../../../core/models/offer.dart';
import '../../../core/models/portfolio_item.dart';
import '../../../core/models/review.dart';
import '../../../core/models/service.dart';
import '../../../core/routing/routes.dart';
import '../../../core/social_proof/hallaq_badges.dart';
import '../../../core/social_proof/social_proof_repository.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_badges_row.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../before_after/data/before_after_repository.dart';
import '../../offers/data/offers_repository.dart';
import '../../portfolio/data/portfolio_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../../reviews/presentation/write_review_screen.dart';
import '../../services/data/services_repository.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../social/data/social_repository.dart';
import '../../shop_claim/data/shop_claim_repository.dart';
import '../../trending/presentation/trending_this_week_section.dart';
import '../data/shop_repository.dart';

class ShopProfileScreen extends ConsumerWidget {
  final String id;

  const ShopProfileScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shopValue = ref.watch(_shopProvider(id));

    return LuxuryScaffold(
      child: AsyncValueWidget<Barbershop>(
        value: shopValue,
        data: (shop) {
          final user = ref.watch(supabaseClientProvider).auth.currentUser;
          final myClaimValue = ref.watch(myShopClaimForShopProvider(shop.id));
          final canClaim = user != null && user.id != shop.ownerProfileId;
          final barbersCount = ref.watch(_barbersCountForShopProvider(shop.id));
          final followers = ref.watch(followersCountProvider((targetType: 'shop', targetId: shop.id)));
          final reviewsCount = ref.watch(reviewsCountProvider((targetType: 'shop', targetId: shop.id)));
          final bookings = ref.watch(bookingsCountForShopProvider(shop.id));

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
            children: [
              _ShopHero(
                shop: shop,
                onBack: () => context.pop(),
                onShare: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ShareQrSheet(shop: shop),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _ShopStatsRow(
                  barbers: barbersCount,
                  reviews: reviewsCount,
                  rating: shop.ratingAvg,
                  followers: followers,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(child: _FollowShopButton(shopId: shop.id)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HallaqButton(
                        label: l10n.bookNow,
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: HallaqCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.bookWithTeam,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    HallaqButton(
                                      label: l10n.chooseSpecificBarber,
                                      variant: HallaqButtonVariant.secondary,
                                      icon: Icons.people_alt_rounded,
                                      onPressed: () {
                                        ref.read(_shopTabIndexProvider(shop.id).notifier).state = 1;
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    HallaqButton(
                                      label: l10n.anyAvailableBarber,
                                      icon: Icons.auto_awesome_rounded,
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        context.push('${Routes.bookingNew}?shopId=${shop.id}');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (canClaim) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AsyncValueWidget<ShopClaimRequest?>(
                    value: myClaimValue,
                    data: (req) {
                      final pending = req != null && req.status == 'pending';
                      return HallaqButton(
                        label: pending ? 'Claim Pending' : 'Claim This Shop',
                        variant: HallaqButtonVariant.secondary,
                        icon: Icons.verified_user_rounded,
                        onPressed: pending ? null : () => context.push('${Routes.shopProfile}/${shop.id}/claim'),
                      );
                    },
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: HallaqButton(
                        label: 'Products',
                        variant: HallaqButtonVariant.secondary,
                        icon: Icons.shopping_bag_rounded,
                        onPressed: () => context.push('${Routes.products}?shopId=${shop.id}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HallaqButton(
                        label: 'Cart',
                        variant: HallaqButtonVariant.secondary,
                        icon: Icons.shopping_cart_rounded,
                        onPressed: () => context.push(Routes.cart),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HallaqBadgesRow(badges: badgesForShop(context, shop).take(4).toList()),
              ),
              const SizedBox(height: 12),
              TrendingThisWeekSection(currentShopId: shop.id),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ShopTabs(
                  shop: shop,
                  followers: followers,
                  reviewsCount: reviewsCount,
                  bookings: bookings,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _shopProvider = FutureProvider.family<Barbershop, String>((ref, id) async {
  return ref.watch(shopRepositoryProvider).getById(id);
});

final _barbersCountForShopProvider = FutureProvider.family<int, String>((ref, shopId) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final total = await client
        .from('barbers')
        .count(CountOption.exact)
        .eq('shop_id', shopId)
        .eq('status', 'approved')
        .eq('is_active', true);
    return total;
  } catch (_) {
    return 0;
  }
});

class _ShopHero extends StatelessWidget {
  final Barbershop shop;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _ShopHero({required this.shop, required this.onBack, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = openingStatusFromHours(shop.openingHours, DateTime.now());
    final variant = ((shop.id.hashCode.abs() % 6) + 1).toString().padLeft(2, '0');
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXl)),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            Positioned.fill(
              child: LuxuryNetworkImage(
                imageUrl: shop.coverUrl,
                fallbackUrl: HallaqImages.shopCover(variant: variant),
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
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: onBack),
                    const Spacer(),
                    LuxuryIconButton(icon: Icons.ios_share_rounded, onPressed: () async => Share.share(AppLinks.shopProfile(shop.id))),
                    const SizedBox(width: 10),
                    LuxuryIconButton(icon: Icons.qr_code_rounded, onPressed: onShare),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.softShadow(opacity: 0.12),
                        ),
                        child: ClipOval(
                          child: LuxuryNetworkImage(
                            imageUrl: shop.logoUrl,
                            fallbackUrl: HallaqImages.goldScissorsIllustration(variant: '02'),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    shop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                if (shop.badgeVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: AppTheme.gold, size: 20),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    (shop.area ?? '').isEmpty ? l10n.bahrain : shop.area!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: (status.isOpen ? AppTheme.success : AppTheme.error).withValues(alpha: 0.20),
                          border: Border.all(color: (status.isOpen ? AppTheme.success : AppTheme.error).withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          status.primaryLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopStatsRow extends StatelessWidget {
  final AsyncValue<int> barbers;
  final AsyncValue<int> reviews;
  final double rating;
  final AsyncValue<int> followers;

  const _ShopStatsRow({
    required this.barbers,
    required this.reviews,
    required this.rating,
    required this.followers,
  });

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: 'Barbers', value: barbers)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: AppLocalizations.of(context).reviews, value: reviews)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: AppLocalizations.of(context).followers, value: followers)),
        ],
      ),
    );
  }
}

final _shopTabIndexProvider = StateProvider.family<int, String>((ref, shopId) => 0);

class _ShopTabs extends ConsumerWidget {
  final Barbershop shop;
  final AsyncValue<int> followers;
  final AsyncValue<int> reviewsCount;
  final AsyncValue<int> bookings;

  const _ShopTabs({
    required this.shop,
    required this.followers,
    required this.reviewsCount,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(_shopTabIndexProvider(shop.id));
    final setIndex = ref.read(_shopTabIndexProvider(shop.id).notifier);

    Widget tabChip({required String label, required bool selected, required VoidCallback onTap}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? AppTheme.gold.withValues(alpha: 0.14) : AppTheme.surface,
            border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.22) : AppTheme.border),
            boxShadow: selected ? AppTheme.softShadow(opacity: 0.08) : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selected ? AppTheme.text : AppTheme.textMuted,
                ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              tabChip(label: l10n.about, selected: index == 0, onTap: () => setIndex.state = 0),
              const SizedBox(width: 10),
              tabChip(label: l10n.team, selected: index == 1, onTap: () => setIndex.state = 1),
              const SizedBox(width: 10),
              tabChip(label: l10n.services, selected: index == 2, onTap: () => setIndex.state = 2),
              const SizedBox(width: 10),
              tabChip(label: l10n.gallery, selected: index == 3, onTap: () => setIndex.state = 3),
              const SizedBox(width: 10),
              tabChip(label: 'Before & After', selected: index == 4, onTap: () => setIndex.state = 4),
              const SizedBox(width: 10),
              tabChip(label: 'Offers', selected: index == 5, onTap: () => setIndex.state = 5),
              const SizedBox(width: 10),
              tabChip(label: l10n.reviews, selected: index == 6, onTap: () => setIndex.state = 6),
            ],
          ),
        ),
        const SizedBox(height: 14),
        switch (index) {
          0 => _AboutTab(shop: shop, followers: followers, reviewsCount: reviewsCount, bookings: bookings),
          1 => _TeamTab(value: ref.watch(barbersForShopProvider(shop.id)), shopId: shop.id),
          2 => _ServicesTab(value: ref.watch(shopServicesProvider(shop.id))),
          3 => _GalleryTab(value: ref.watch(portfolioPreviewForShopProvider(shop.id)), variantSeed: shop.id),
          4 => _BeforeAfterTab(value: ref.watch(beforeAfterForShopProvider(shop.id))),
          5 => _OffersTab(value: ref.watch(activeOffersForShopProvider(shop.id))),
          _ => _ReviewsTab(value: ref.watch(reviewsPreviewForTargetProvider((targetType: 'shop', targetId: shop.id))), shopId: shop.id),
        },
      ],
    );
  }
}

class _OffersTab extends StatelessWidget {
  final AsyncValue<List<Offer>> value;

  const _OffersTab({required this.value});

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<Offer>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
            title: 'Offers',
            description: 'No offers right now',
            showMascot: true,
          );
        }
        return Column(children: items.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _ShopOfferCard(offer: o))).toList());
      },
    );
  }
}

class _ShopOfferCard extends ConsumerWidget {
  final Offer offer;

  const _ShopOfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (offer.offerType) {
      'fixed' => offer.discountAmount == null ? 'DISCOUNT' : '${offer.discountAmount!.toStringAsFixed(3)} BHD OFF',
      'package' => 'PACKAGE',
      _ => offer.discountPercent == null ? 'DISCOUNT' : '${offer.discountPercent!.toStringAsFixed(0)}% OFF',
    };
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LuxuryNetworkImage(
              imageUrl: offer.bannerUrl,
              fallbackUrl: HallaqImages.blackGoldBackground(),
              width: 64,
              height: 64,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              try {
                await ref.read(favoritesRepositoryProvider).add(targetType: 'offer', targetId: offer.id);
                ref.invalidate(favoriteOffersProvider);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
              } catch (_) {}
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterTab extends StatelessWidget {
  final AsyncValue<List<BeforeAfterItem>> value;

  const _BeforeAfterTab({required this.value});

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<BeforeAfterItem>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
            title: 'Before & After',
            description: 'No before & after yet',
            showMascot: true,
          );
        }
        return Column(
          children: items
              .map(
                (it) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HallaqCard(
                    glass: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: LuxuryNetworkImage(
                                  imageUrl: it.beforeImageUrl,
                                  fallbackUrl: HallaqImages.blackGoldBackground(),
                                  height: 140,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: LuxuryNetworkImage(
                                  imageUrl: it.afterImageUrl,
                                  fallbackUrl: HallaqImages.blackGoldBackground(),
                                  height: 140,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((it.caption ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(it.caption!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _TeamTab extends StatelessWidget {
  final AsyncValue<List<Barber>> value;
  final String shopId;

  const _TeamTab({required this.value, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AsyncValueWidget<List<Barber>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
                title: l10n.team,
            description: l10n.noServicesDescription,
            showMascot: true,
          );
        }
        return Column(
          children: items.map((b) => _TeamBarberCard(barber: b, shopId: shopId)).toList(),
        );
      },
    );
  }
}

class _TeamBarberCard extends StatelessWidget {
  final Barber barber;
  final String shopId;

  const _TeamBarberCard({required this.barber, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = ((barber.id.hashCode.abs() % 6) + 1).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HallaqCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/barber/${barber.slug.isNotEmpty ? barber.slug : barber.id}'),
        child: Row(
          children: [
            HallaqAvatar(imageUrl: barber.avatarUrl, size: 54, variant: v),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          barber.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (barber.badgeVerified) const Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (barber.specialty ?? '').trim().isEmpty ? l10n.professional : barber.specialty!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  HallaqRating(value: barber.ratingAvg, count: barber.ratingCount, iconSize: 16),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                HallaqButton(
                  label: l10n.bookNow,
                  expanded: false,
                  onPressed: () => context.push('${Routes.bookingNew}?barberId=${barber.id}&shopId=$shopId'),
                ),
                const SizedBox(height: 10),
                HallaqButton(
                  label: l10n.viewProfile,
                  expanded: false,
                  variant: HallaqButtonVariant.ghost,
                  onPressed: () => context.push('/barber/${barber.slug.isNotEmpty ? barber.slug : barber.id}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesTab extends StatelessWidget {
  final AsyncValue<List<Service>> value;

  const _ServicesTab({required this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AsyncValueWidget<List<Service>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
            title: l10n.services,
            description: l10n.noServicesDescription,
            showMascot: true,
          );
        }
        return Column(children: items.map((s) => _ServiceTile(service: s)).toList());
      },
    );
  }
}

class _GalleryTab extends StatelessWidget {
  final AsyncValue<List<PortfolioItem>> value;
  final String variantSeed;

  const _GalleryTab({required this.value, required this.variantSeed});

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<PortfolioItem>>(
      value: value,
      data: (items) {
        final list = items.isEmpty ? List<PortfolioItem?>.generate(6, (_) => null) : items.take(20).toList();
        return _GalleryRow(items: list, variantSeed: variantSeed);
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final AsyncValue<List<Review>> value;
  final String shopId;

  const _ReviewsTab({required this.value, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('To leave a review, open your completed booking.')),
              );
              context.go('/bookings');
            },
            child: Text(l10n.write, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 12),
        AsyncValueWidget<List<Review>>(
          value: value,
          data: (items) {
            if (items.isEmpty) {
              return HallaqEmptyState(
                title: l10n.noReviewsTitle,
                description: l10n.noReviewsDescription,
                showMascot: true,
              );
            }
            return Column(children: items.take(10).map((r) => _ReviewTile(rating: r.rating, text: r.comment, photoUrl: r.imageUrl)).toList());
          },
        ),
      ],
    );
  }
}

class _AboutTab extends ConsumerWidget {
  final Barbershop shop;
  final AsyncValue<int> followers;
  final AsyncValue<int> reviewsCount;
  final AsyncValue<int> bookings;

  const _AboutTab({required this.shop, required this.followers, required this.reviewsCount, required this.bookings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final isOwner = user != null && user.id == shop.ownerProfileId;
    final about = (shop.aboutUs ?? shop.description ?? '').trim();
    final story = (shop.story ?? '').trim();
    final years = shop.yearsInBusiness;
    final specialties = shop.specialties.where((e) => e.trim().isNotEmpty).toList(growable: false);
    final awards = shop.awards.where((e) => e.trim().isNotEmpty).toList(growable: false);
    final languages = shop.languages.where((e) => e.trim().isNotEmpty).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HallaqSectionTitle(
          title: 'About',
          trailing: isOwner
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => _ShopStoryEditorSheet(shop: shop),
                  ),
                  child: Text(l10n.editProfile, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
                )
              : null,
        ),
        HallaqCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuxuryNetworkImage(
                imageUrl: null,
                fallbackUrl: HallaqImages.luxuryBarberInterior(variant: '03'),
                height: 180,
              ),
              const SizedBox(height: 12),
              if (about.isNotEmpty) ...[
                Text('About Us', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(about, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
              if (story.isNotEmpty) ...[
                if (about.isNotEmpty) const SizedBox(height: 12),
                Text('Story', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(story, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
              if (about.isEmpty && story.isEmpty)
                Text(
                  l10n.noServicesDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              if (years != null || specialties.isNotEmpty || awards.isNotEmpty || languages.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Shop details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (years != null) _MetaRow(label: 'Years in business', value: '$years'),
                if (specialties.isNotEmpty) _MetaRow(label: 'Specialties', value: specialties.join(', ')),
                if (awards.isNotEmpty) _MetaRow(label: 'Awards', value: awards.join(', ')),
                if (languages.isNotEmpty) _MetaRow(label: 'Languages', value: languages.join(', ')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        HallaqSectionTitle(title: l10n.contact),
        HallaqCard(
          child: Column(
            children: [
              _ContactRow(
                icon: Icons.call_rounded,
                label: l10n.call,
                value: (shop.phone ?? '').trim(),
                onTap: (v) => _launch(context, Uri.parse('tel:$v')),
              ),
              const Divider(height: 18),
              _ContactRow(
                icon: Icons.chat_bubble_rounded,
                label: l10n.whatsapp,
                value: (shop.whatsapp ?? '').trim(),
                onTap: (v) {
                  final phone = v.replaceAll(RegExp(r'\s+'), '');
                  return _launch(context, Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'));
                },
              ),
              const Divider(height: 18),
              _ContactRow(
                icon: Icons.alternate_email_rounded,
                label: l10n.instagram,
                value: (shop.instagram ?? '').trim(),
                onTap: (v) {
                  final handle = v.startsWith('@') ? v.substring(1) : v;
                  return _launch(context, Uri.parse('https://instagram.com/$handle'));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HallaqSectionTitle(title: l10n.addressTitle),
        HallaqCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ((shop.address ?? '').trim().isNotEmpty) ? shop.address!.trim() : (shop.area ?? 'Bahrain'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AsyncValueWidget<double?>(
                value: ref.watch(distanceToShopKmProvider(shop.id)),
                data: (km) {
                  final label = km == null ? '—' : '${km.toStringAsFixed(1)} km • ${etaLabelFromMinutes(etaMinutesFromKm(km))}';
                  return HallaqCard(
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded, color: AppTheme.gold),
                        const SizedBox(width: 10),
                        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HallaqButton(
                label: l10n.getDirections,
                icon: Icons.directions_rounded,
                onPressed: () async {
                  final ok = await launchDirections(googleMapsUrl: shop.googleMapsUrl, lat: shop.lat, lng: shop.lng);
                  if (!context.mounted) return;
                  if (!ok) showErrorSnackBar(context, 'Unable to open maps');
                },
              ),
            ),
          ],
        ),
        if (shop.openingHours != null && shop.openingHours!.isNotEmpty) ...[
          const SizedBox(height: 14),
          HallaqSectionTitle(title: l10n.openingHoursTitle),
          HallaqCard(
            child: Column(
              children: shop.openingHours!.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key.toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            (e.value ?? '').toString(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _ShopStoryEditorSheet extends ConsumerStatefulWidget {
  final Barbershop shop;

  const _ShopStoryEditorSheet({required this.shop});

  @override
  ConsumerState<_ShopStoryEditorSheet> createState() => _ShopStoryEditorSheetState();
}

class _ShopStoryEditorSheetState extends ConsumerState<_ShopStoryEditorSheet> {
  final _about = TextEditingController();
  final _story = TextEditingController();
  final _years = TextEditingController();
  final _specialties = TextEditingController();
  final _awards = TextEditingController();
  final _languages = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _about.dispose();
    _story.dispose();
    _years.dispose();
    _specialties.dispose();
    _awards.dispose();
    _languages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    if (_about.text.isEmpty && _story.text.isEmpty && _years.text.isEmpty && _specialties.text.isEmpty && _awards.text.isEmpty && _languages.text.isEmpty) {
      _about.text = (shop.aboutUs ?? shop.description ?? '').trim();
      _story.text = (shop.story ?? '').trim();
      _years.text = shop.yearsInBusiness?.toString() ?? '';
      _specialties.text = shop.specialties.join(', ');
      _awards.text = shop.awards.join(', ');
      _languages.text = shop.languages.join(', ');
    }

    final bottom = 16 + MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        child: HallaqCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Edit shop story', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _about, maxLines: 4, decoration: const InputDecoration(labelText: 'About Us')),
              const SizedBox(height: 10),
              TextField(controller: _story, maxLines: 6, decoration: const InputDecoration(labelText: 'Story')),
              const SizedBox(height: 10),
              TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years in business')),
              const SizedBox(height: 10),
              TextField(controller: _specialties, decoration: const InputDecoration(labelText: 'Specialties (comma separated)')),
              const SizedBox(height: 10),
              TextField(controller: _awards, decoration: const InputDecoration(labelText: 'Awards (comma separated)')),
              const SizedBox(height: 10),
              TextField(controller: _languages, decoration: const InputDecoration(labelText: 'Languages (comma separated)')),
              const SizedBox(height: 12),
              HallaqButton(
                label: 'Save',
                icon: Icons.check_rounded,
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final parsedYears = int.tryParse(_years.text.trim());
                          List<String> listFrom(String s) => s
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(growable: false);
                          await ref.read(shopRepositoryProvider).updateShop(
                                shopId: shop.id,
                                aboutUs: _about.text.trim(),
                                story: _story.text.trim(),
                                yearsInBusiness: parsedYears,
                                specialties: listFrom(_specialties.text),
                                awards: listFrom(_awards.text),
                                languages: listFrom(_languages.text),
                              );
                          ref.invalidate(_shopProvider(shop.id));
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        } on AppException catch (e) {
                          if (!context.mounted) return;
                          showErrorSnackBar(context, e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function(String value) onTap;

  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = value.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !enabled ? null : () => onTap(value),
      child: Row(
        children: [
          Icon(icon, color: enabled ? AppTheme.gold : AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  enabled ? value : '—',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: enabled ? AppTheme.gold : AppTheme.textMuted),
        ],
      ),
    );
  }
}

Future<void> _launch(BuildContext context, Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final AsyncValue<int> value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        AsyncValueWidget<int>(
          value: value,
          data: (v) => Text(
            v.toString(),
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

final _isFollowingShopProvider = FutureProvider.family<bool, String>((ref, shopId) async {
  return ref.watch(socialRepositoryProvider).isFollowing(targetType: 'shop', targetId: shopId);
});

class _FollowShopButton extends ConsumerWidget {
  final String shopId;

  const _FollowShopButton({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(_isFollowingShopProvider(shopId));
    return AsyncValueWidget<bool>(
      value: value,
      data: (isFollowing) {
        return HallaqButton(
          label: isFollowing ? l10n.following : l10n.follow,
          variant: HallaqButtonVariant.secondary,
          icon: isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
          onPressed: () async {
            final repo = ref.read(socialRepositoryProvider);
            if (isFollowing) {
              await repo.unfollow(targetType: 'shop', targetId: shopId);
            } else {
              await repo.follow(targetType: 'shop', targetId: shopId);
            }
            ref.invalidate(_isFollowingShopProvider(shopId));
            ref.invalidate(followersCountProvider((targetType: 'shop', targetId: shopId)));
          },
        );
      },
    );
  }
}

class _ShareQrSheet extends StatelessWidget {
  final Barbershop shop;

  const _ShareQrSheet({required this.shop});

  @override
  Widget build(BuildContext context) {
    final url = AppLinks.shopProfile(shop.id);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: HallaqCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Share shop', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: QrImageView(data: url, size: 220),
              ),
              const SizedBox(height: 14),
              HallaqButton(label: 'Share Link', icon: Icons.ios_share_rounded, onPressed: () async => Share.share(url)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Service service;

  const _ServiceTile({required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${service.durationMin} min', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            Text('${service.price.toStringAsFixed(2)} BHD', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final int rating;
  final String? text;
  final String? photoUrl;

  const _ReviewTile({required this.rating, required this.text, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HallaqRating(value: rating.toDouble(), showValue: false, iconSize: 16),
            if (text != null && text!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (photoUrl != null && photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              LuxuryNetworkImage(
                imageUrl: photoUrl,
                fallbackUrl: '',
                height: 180,
                borderRadius: BorderRadius.circular(18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryRow extends StatelessWidget {
  final List<PortfolioItem?> items;
  final String variantSeed;

  const _GalleryRow({required this.items, required this.variantSeed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final v = ((variantSeed.hashCode.abs() + index) % 6 + 1).toString().padLeft(2, '0');
          return SizedBox(
            width: 150,
            child: HallaqCard(
              padding: EdgeInsets.zero,
              child: LuxuryNetworkImage(
                imageUrl: item == null
                    ? null
                    : ((item.thumbnailPath ?? '').trim().isNotEmpty
                        ? item.thumbnailPath
                        : (item.thumbnailUrl ?? '').trim().isNotEmpty
                            ? item.thumbnailUrl
                            : item.mediaPath ?? item.mediaUrl),
                fallbackUrl: HallaqImages.shopCover(variant: v),
                height: 190,
                bucket: 'portfolio',
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          );
        },
      ),
    );
  }
}
