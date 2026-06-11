import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/currency_formatters.dart';
import '../../../core/geo/eta.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/geo/maps_launcher.dart';
import '../../../core/geo/opening_status.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/localization/area_controller.dart';
import '../../../core/localization/cities_repository.dart';
import '../../../core/models/offer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/city_picker_sheet.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_skeletons.dart';
import '../../../core/widgets/premium_hero_card.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/utils/debouncer.dart';
import '../../offers/data/offers_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../social/data/social_repository.dart';
import '../../favorites/data/follow_favorites_repository.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../data/home_repository.dart';
import '../models/home_banner.dart';
import '../models/nearby_listings.dart';
import 'home_reels_controller.dart';
import 'nearby_barbers_controller.dart';
import 'nearby_shops_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bannerController = PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  int _bannerCount = 0;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final count = _bannerCount;
      if (count < 2) return;
      if (!_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % count;
      _bannerController.animateToPage(next, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _openAreaPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CityPickerSheet(),
    );
  }

  Future<void> _maybePromptLocation() async {
    if (_promptOpen) return;
    final c = ref.read(locationControllerProvider);
    final should = await c.shouldPrompt();
    if (!should || !mounted) return;
    _promptOpen = true;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: LuxuryCard(
              glass: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: AppTheme.goldGradient,
                        boxShadow: AppTheme.goldGlow(opacity: 0.20, blur: 36, y: 16),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.black, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.enableLocationTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.enableLocationDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    HallaqButton(
                      label: l10n.allowLocation,
                      icon: Icons.my_location_rounded,
                      onPressed: () async {
                        Navigator.of(context).pop(true);
                      },
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          l10n.notNow,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.goldDeep, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    await c.markPrompted();
    if (!mounted) return;

    if (allow == true) {
      try {
        await c.requestAndSave();
        ref.invalidate(nearbyShopsControllerProvider);
        ref.invalidate(nearbyBarbersControllerProvider);
      } catch (_) {
        if (!mounted) return;
        await _openAreaPicker();
      }
    } else {
      await _openAreaPicker();
    }
    _promptOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uri = GoRouterState.of(context).uri;
    final isPreview = uri.queryParameters['preview'] == '1';
    final area = ref.watch(areaControllerProvider);
    final banners = ref.watch(homeBannersProvider);
    final cities = ref.watch(activeCitiesProvider);
    final cityId = cities.valueOrNull
        ?.where((c) => c.name.trim().toLowerCase() == area.trim().toLowerCase())
        .map((c) => c.id)
        .cast<String?>()
        .firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => null);
    final reels = ref.watch(homeReelsControllerProvider(cityId));
    final offers = (cityId != null && cityId.trim().isNotEmpty) ? ref.watch(activeOffersForCityProvider(cityId)) : ref.watch(activeOffersProvider);
    final nearbyShops = ref.watch(nearbyShopsControllerProvider);
    final nearbyBarbers = ref.watch(nearbyBarbersControllerProvider);
    final unread = ref.watch(myUnreadNotificationsCountProvider);
    final unreadCount = unread.valueOrNull ?? 0;

    final displayArea = area.trim().isEmpty ? 'Manama' : area.trim();
    final w = MediaQuery.sizeOf(context).width;
    final maxWidth = w >= 1180 ? 1080.0 : (w >= 820 ? 760.0 : 420.0);
    final edge = w >= 820 ? const EdgeInsets.symmetric(horizontal: 20) : const EdgeInsets.symmetric(horizontal: 12);

    return ResponsiveCenter(
      maxWidth: maxWidth,
      padding: edge,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: _TopHeader(
                locationLabel: '$displayArea, ${l10n.bahrain}',
                onNotifications: () => context.go('/notifications'),
                onLocation: _openAreaPicker,
                onQrScan: () => context.push('/scan'),
                notificationsBadge: unreadCount,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _HomeSearchBar(
                placeholder: l10n.homeSearchPlaceholder,
                onTap: () => context.push(isPreview ? '/search?preview=1' : '/search'),
                onFilter: () => context.push(isPreview ? '/search?preview=1' : '/search'),
                onQuery: (q) => context.push(isPreview ? '/search?q=${Uri.encodeQueryComponent(q)}&preview=1' : '/search?q=${Uri.encodeQueryComponent(q)}'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AsyncValueWidget<List<HomeBanner>>(
                value: banners,
                loading: const HorizontalCardsSkeleton(cardWidth: 340, cardHeight: 190),
                onRetry: () => ref.invalidate(homeBannersProvider),
                errorImageUrl: HallaqImages.shopCover(variant: '01'),
                data: (items) {
                  _bannerCount = items.isEmpty ? 1 : items.length;
                  return _BannerSlider(
                    controller: _bannerController,
                    items: items.isEmpty
                        ? const [
                            HomeBanner(id: 'fallback', title: 'Hallaq', imageUrl: null, linkUrl: null),
                          ]
                        : items,
                    onIndexChanged: (i) => setState(() => _bannerIndex = i),
                    activeIndex: _bannerIndex,
                    onBookNow: () => context.push(isPreview ? '/booking/new?preview=1' : '/booking/new'),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(isPreview ? '/city?preview=1' : '/city'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'View All',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickActions.length,
                itemBuilder: (context, index) {
                  final a = _quickActions[index];
                  final route = isPreview ? (a.route.contains('?') ? '${a.route}&preview=1' : '${a.route}?preview=1') : a.route;
                  return _QuickActionTile(
                    icon: a.icon,
                    label: a.label,
                    onTap: () => context.push(route),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: l10n.nearbyShopsTitle,
              onSeeAll: () => context.push(isPreview ? '/search?tab=shops&preview=1' : '/search?tab=shops'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 236,
              child: AsyncValueWidget<NearbyShopsState>(
                value: nearbyShops,
                loading: const HorizontalCardsSkeleton(cardWidth: 176, cardHeight: 228),
                onRetry: () => ref.invalidate(nearbyShopsControllerProvider),
                errorImageUrl: HallaqImages.shopCover(variant: '01'),
                data: (state) {
                  if (state.items.isEmpty) {
                    if (!state.hasLocation) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EnableLocationInlineCard(onEnable: () async {
                        try {
                          await ref.read(locationControllerProvider).requestAndSave();
                          ref.invalidate(nearbyShopsControllerProvider);
                          ref.invalidate(nearbyBarbersControllerProvider);
                        } catch (_) {
                          if (!mounted) return;
                          await _openAreaPicker();
                        }
                      }),
                    );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyNearbyInlineCard(
                        title: l10n.noNearbyShopsTitle,
                        description: l10n.noNearbyShopsDescription,
                        onAction: _openAreaPicker,
                      ),
                    );
                  }
                  final sorted = [...state.items]
                    ..sort((a, b) {
                      final ao = openingStatusFromHours(a.shop.openingHours, DateTime.now()).isOpen;
                      final bo = openingStatusFromHours(b.shop.openingHours, DateTime.now()).isOpen;
                      if (ao != bo) return ao ? -1 : 1;
                      final d = a.distanceKm.compareTo(b.distanceKm);
                      if (d != 0) return d;
                      return b.shop.ratingAvg.compareTo(a.shop.ratingAvg);
                    });
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis != Axis.horizontal) return false;
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                        ref.read(nearbyShopsControllerProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        final variant = (index + 1).toString().padLeft(2, '0');
                        return _NearbyShopCard(
                          item: item,
                          variant: variant,
                          onTap: () => context.push('/shop/${item.shop.id}'),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: sorted.length,
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: l10n.topBarbersNearYouTitle,
              onSeeAll: () => context.push(isPreview ? '/search?tab=barbers&preview=1' : '/search?tab=barbers'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 228,
              child: AsyncValueWidget<NearbyBarbersState>(
                value: nearbyBarbers,
                loading: const HorizontalCardsSkeleton(cardWidth: 168, cardHeight: 220),
                onRetry: () => ref.invalidate(nearbyBarbersControllerProvider),
                errorImageUrl: HallaqImages.professionalBarberPortrait(variant: '01'),
                data: (state) {
                  if (state.items.isEmpty) {
                    if (!state.hasLocation) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EnableLocationInlineCard(onEnable: () async {
                        try {
                          await ref.read(locationControllerProvider).requestAndSave();
                          ref.invalidate(nearbyShopsControllerProvider);
                          ref.invalidate(nearbyBarbersControllerProvider);
                        } catch (_) {
                          if (!mounted) return;
                          await _openAreaPicker();
                        }
                      }),
                    );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyNearbyInlineCard(
                        title: l10n.noNearbyBarbersTitle,
                        description: l10n.noNearbyBarbersDescription,
                        onAction: _openAreaPicker,
                      ),
                    );
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis != Axis.horizontal) return false;
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                        ref.read(nearbyBarbersControllerProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        final variant = (index + 1).toString().padLeft(2, '0');
                        return _NearbyBarberCard(
                          item: item,
                          variant: variant,
                          onTap: () => context.push('/barber/${item.barber.slug.isNotEmpty ? item.barber.slug : item.barber.id}'),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: state.items.length,
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Reels For You',
              onSeeAll: () => context.go(isPreview ? '/discover?preview=1' : '/discover'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: AsyncValueWidget<HomeReelsState>(
                value: reels,
                loading: const HorizontalCardsSkeleton(cardWidth: 84, cardHeight: 124),
                onRetry: () => ref.invalidate(homeReelsControllerProvider(cityId)),
                errorImageUrl: HallaqImages.haircut(variant: '01'),
                data: (state) {
                  final list = state.items;
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyNearbyInlineCard(
                        title: 'No reels yet',
                        description: 'Fresh cuts and transformations will show up here soon.',
                        onAction: () async => context.go(isPreview ? '/discover?preview=1' : '/discover'),
                      ),
                    );
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis != Axis.horizontal) return false;
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
                        ref.read(homeReelsControllerProvider(cityId).notifier).loadMore(cityId);
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final r = list[index];
                        final v = (index + 1).toString().padLeft(2, '0');
                        final thumbRef = (r.thumbnailPath ?? '').trim().isNotEmpty
                            ? r.thumbnailPath
                            : (r.thumbnailUrl ?? '').trim().isNotEmpty
                                ? r.thumbnailUrl
                                : r.mediaType == 'image'
                                    ? (r.mediaPath ?? '').trim().isNotEmpty
                                        ? r.mediaPath
                                        : r.mediaUrl
                                    : null;
                        return _ReelPreviewCard(
                          imageUrl: thumbRef,
                          fallbackUrl: HallaqImages.haircut(variant: v),
                          onTap: () => context.go(isPreview ? '/discover?preview=1' : '/discover'),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: list.length,
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AsyncValueWidget<List<Offer>>(
              value: offers,
              loading: Column(
                children: [
                  _SectionTitle(
                    title: 'Offers',
                    onSeeAll: () => context.push(isPreview ? '/offers?preview=1' : '/offers'),
                  ),
                  const SizedBox(
                    height: 196,
                    child: HorizontalCardsSkeleton(cardWidth: 250, cardHeight: 186),
                  ),
                ],
              ),
              onRetry: () {
                ref.invalidate(activeOffersProvider);
                if (cityId != null && cityId.trim().isNotEmpty) {
                  ref.invalidate(activeOffersForCityProvider(cityId));
                }
              },
              errorImageUrl: HallaqImages.premiumGrooming(variant: '01'),
              data: (items) {
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    _SectionTitle(
                      title: 'Offers',
                      onSeeAll: () => context.push(isPreview ? '/offers?preview=1' : '/offers'),
                    ),
                    SizedBox(
                      height: 196,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length.clamp(0, 10),
                        itemBuilder: (context, index) {
                          final o = items[index];
                          return _OfferCard(
                            offer: o,
                            variant: (index + 1).toString().padLeft(2, '0'),
                            onTap: () => context.push(isPreview ? '/offers?preview=1' : '/offers'),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onNotifications;
  final VoidCallback onLocation;
  final VoidCallback onQrScan;
  final int notificationsBadge;

  const _TopHeader({
    required this.locationLabel,
    required this.onNotifications,
    required this.onLocation,
    required this.onQrScan,
    required this.notificationsBadge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.softShadow(opacity: 0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.gold, size: 18),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 142),
                    child: Text(
                      locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 18),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'HALLAQ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.6,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'BOOK. STYLE. SHINE.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _HeaderIconButton(icon: Icons.notifications_none_rounded, onTap: onNotifications, badge: notificationsBadge),
          const SizedBox(width: 10),
          _HeaderIconButton(icon: Icons.qr_code_scanner_rounded, onTap: onQrScan),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const _HeaderIconButton({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow(opacity: 0.12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
                ),
                child: Text(
                  badge! > 99 ? '99+' : badge!.toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerSlider extends StatelessWidget {
  final PageController controller;
  final List<HomeBanner> items;
  final ValueChanged<int> onIndexChanged;
  final int activeIndex;
  final VoidCallback onBookNow;

  const _BannerSlider({
    required this.controller,
    required this.items,
    required this.onIndexChanged,
    required this.activeIndex,
    required this.onBookNow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onIndexChanged,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final b = items[index];
              final variant = (index + 1).toString().padLeft(2, '0');
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PremiumHeroCard(
                  imageUrl: b.imageUrl ?? '',
                  fallbackUrl: HallaqImages.shopCover(variant: variant),
                  title: (b.title.trim().isEmpty) ? 'Hallaq' : b.title,
                  subtitle: l10n.discoverPremiumSpots,
                  trailing: LuxuryIconButton(icon: Icons.arrow_forward_rounded, onPressed: onBookNow),
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(
                          l10n.bookNow,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final isActive = i == activeIndex.clamp(0, items.length - 1);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isActive ? AppTheme.gold : AppTheme.border,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;

  const _QuickAction({required this.icon, required this.label, required this.route});
}

const _quickActions = <_QuickAction>[
  _QuickAction(icon: Icons.calendar_month_rounded, label: 'Book\nAppointment', route: '/booking/new'),
  _QuickAction(icon: Icons.person_search_rounded, label: 'Find\nBarbers', route: '/search?tab=barbers'),
  _QuickAction(icon: Icons.storefront_rounded, label: 'Explore\nShops', route: '/search?tab=shops'),
  _QuickAction(icon: Icons.content_cut_rounded, label: 'Hair\nStyles', route: '/discover'),
  _QuickAction(icon: Icons.local_offer_rounded, label: 'Offers\n& Deals', route: '/offers'),
  _QuickAction(icon: Icons.auto_awesome_rounded, label: 'AI\nStudio', route: '/discover'),
  _QuickAction(icon: Icons.card_giftcard_rounded, label: 'Gift\nCards', route: '/products'),
];

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 98,
      child: LuxuryCard(
        glass: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
                boxShadow: AppTheme.softShadow(opacity: 0.10),
              ),
              child: Icon(icon, color: AppTheme.gold, size: 22),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchBar extends StatefulWidget {
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback onFilter;
  final Future<void> Function(String query) onQuery;

  const _HomeSearchBar({required this.placeholder, required this.onTap, required this.onFilter, required this.onQuery});

  @override
  State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(const Duration(milliseconds: 260));
  var _launching = false;

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _openWithQuery(String raw, {required bool immediate}) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    if (_launching) return;
    setState(() => _launching = true);
    try {
      await widget.onQuery(q);
    } finally {
      if (mounted) {
        _controller.clear();
        setState(() => _launching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      glass: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onTap: widget.onTap,
              onChanged: (v) {
                if (_launching) return;
                _debouncer.run(() => _openWithQuery(v, immediate: false));
              },
              onSubmitted: (v) => _openWithQuery(v, immediate: true),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.placeholder,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onFilter,
            child: const Icon(Icons.tune_rounded, color: AppTheme.gold),
          ),
        ],
      ),
    );
  }
}

class _ReelPreviewCard extends StatelessWidget {
  final String? imageUrl;
  final String fallbackUrl;
  final VoidCallback onTap;

  const _ReelPreviewCard({
    required this.imageUrl,
    required this.fallbackUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 124,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LuxuryCard(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: LuxuryNetworkImage(
                  imageUrl: imageUrl,
                  fallbackUrl: fallbackUrl,
                  fallbackKey: 'default_reel_thumbnail',
                  width: 84,
                  height: 124,
                  bucket: 'reels',
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.38),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Offer offer;
  final String variant;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final discount = offer.discountPercent != null ? '${offer.discountPercent!.round()}%' : null;
    final exp = offer.validTo;
    final expiresLabel = exp == null ? null : 'Expires ${exp.month}/${exp.day}';

    return SizedBox(
      width: 250,
      child: LuxuryCard(
        glass: true,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 122,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LuxuryNetworkImage(
                        imageUrl: offer.bannerUrl ?? offer.bannerPath,
                        fallbackUrl: HallaqImages.premiumGrooming(variant: variant),
                        fallbackKey: 'default_offer_image',
                        borderRadius: BorderRadius.zero,
                        bucket: 'offer-images',
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (discount != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: AppTheme.goldGradient,
                            boxShadow: AppTheme.goldGlow(opacity: 0.12, blur: 22, y: 12),
                          ),
                          child: Text(
                            discount,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title.isEmpty ? 'Offer' : offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      if (expiresLabel != null)
                        Text(
                          expiresLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                      const Spacer(),
                      SizedBox(
                        height: 40,
                        child: HallaqButton(
                          label: 'Book Now',
                          onPressed: onTap,
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionTitle({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Text(
              AppLocalizations.of(context).viewAll,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableLocationInlineCard extends StatelessWidget {
  final VoidCallback onEnable;

  const _EnableLocationInlineCard({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LuxuryCard(
      glass: true,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: AppTheme.goldGradient,
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.black, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.enableLocationTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  l10n.enableLocationDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          LuxuryIconButton(icon: Icons.arrow_forward_rounded, onPressed: onEnable),
        ],
      ),
    );
  }
}

class _EmptyNearbyInlineCard extends StatelessWidget {
  final String title;
  final String description;
  final Future<void> Function() onAction;

  const _EmptyNearbyInlineCard({required this.title, required this.description, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      glass: true,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: AppTheme.onyx.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.place_rounded, color: Colors.white.withValues(alpha: 0.88), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          LuxuryIconButton(icon: Icons.tune_rounded, onPressed: () => onAction()),
        ],
      ),
    );
  }
}

class _NearbyShopCard extends ConsumerWidget {
  final NearbyShop item;
  final String variant;
  final VoidCallback onTap;

  const _NearbyShopCard({required this.item, required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = item.shop;
    final status = openingStatusFromHours(shop.openingHours, DateTime.now());
    final distance = _formatKm(item.distanceKm);
    final hasDistance = distance.isNotEmpty;
    final eta = hasDistance ? etaLabelFromMinutes(etaMinutesFromKm(item.distanceKm)) : '';
    final starting = item.startingPriceBhd;
    final following = ref.watch(isFollowingShopProvider(shop.id)).valueOrNull ?? false;

    return SizedBox(
      width: 176,
      child: LuxuryCard(
        glass: true,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LuxuryNetworkImage(
                        imageUrl: shop.coverUrl,
                        fallbackUrl: HallaqImages.shopCover(variant: variant),
                        fallbackKey: 'default_shop_cover',
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.62),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: (status.isOpen ? AppTheme.success : AppTheme.onyx).withValues(alpha: 0.55),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          status.primaryLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          HallaqHaptics.tap();
                          try {
                            final repo = ref.read(socialRepositoryProvider);
                            if (following) {
                              await repo.unfollowShop(shop.id);
                            } else {
                              await repo.followShop(shop.id);
                            }
                            ref.invalidate(isFollowingShopProvider(shop.id));
                            ref.invalidate(followedShopsProvider);
                          } catch (_) {}
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.36),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Icon(
                            following ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: following ? AppTheme.gold : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                          const SizedBox(width: 4),
                          Text(shop.ratingAvg.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      if (hasDistance) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$distance remaining • $eta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              starting == null ? status.secondaryLabel : 'From ${CurrencyFormatters.bd(starting)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LuxuryIconButton(
                            icon: Icons.directions_rounded,
                            onPressed: () => unawaited(launchDirections(googleMapsUrl: shop.googleMapsUrl, lat: shop.lat, lng: shop.lng)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyBarberCard extends ConsumerWidget {
  final NearbyBarber item;
  final String variant;
  final VoidCallback onTap;

  const _NearbyBarberCard({required this.item, required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final b = item.barber;
    final distance = _formatKm(item.distanceKm);
    final starting = item.startingPriceBhd;
    final hasDistance = distance.isNotEmpty;
    final eta = hasDistance ? etaLabelFromMinutes(etaMinutesFromKm(item.distanceKm)) : '';
    final worksAt = b.shopId == null ? l10n.independent : l10n.worksAt;
    final areaLabel = (b.area ?? '').trim();
    final following = ref.watch(isFollowingBarberProvider(b.id)).valueOrNull ?? false;

    return SizedBox(
      width: 168,
      child: LuxuryCard(
        glass: true,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HallaqAvatar(imageUrl: b.avatarUrl, size: 54, variant: variant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                          const SizedBox(width: 4),
                          Text(b.ratingAvg.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    HallaqHaptics.tap();
                    try {
                      final repo = ref.read(socialRepositoryProvider);
                      if (following) {
                        await repo.unfollowBarber(b.id);
                      } else {
                        await repo.followBarber(b.id);
                      }
                      ref.invalidate(isFollowingBarberProvider(b.id));
                      ref.invalidate(followedBarbersProvider);
                    } catch (_) {}
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      following ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: following ? AppTheme.gold : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              worksAt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasDistance ? '$distance remaining • $eta' : areaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (starting != null)
              Text(
                'From ${CurrencyFormatters.bd(starting)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: HallaqButton(
                      label: l10n.bookNow,
                      icon: Icons.calendar_month_rounded,
                      onPressed: () => context.push('/booking/new?barberId=${b.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LuxuryIconButton(
                  icon: Icons.directions_rounded,
                  size: 40,
                  onPressed: () => unawaited(launchDirections(lat: b.lat, lng: b.lng)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatKm(double km) {
  if (km.isNaN || km.isInfinite || km < 0) return '';
  final decimals = km < 10 ? 1 : 0;
  return '${km.toStringAsFixed(decimals)} km';
}
