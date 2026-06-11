import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/geo/opening_status.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/offer.dart';
import '../../../core/brand/brand_assets_controller.dart';
import '../../../core/localization/area_controller.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/city_picker_sheet.dart';
import '../../../core/widgets/gold_shimmer.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../features/home/presentation/nearby_barbers_controller.dart';
import '../../../features/home/presentation/nearby_shops_controller.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../data/city_dashboard_repository.dart';
import '../models/city_dashboard_models.dart';
import '../../../core/widgets/responsive_center.dart';

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});

  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen> {
  bool _prefetchWired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wirePrefetch());
  }

  void _wirePrefetch() {
    if (_prefetchWired || !mounted) return;
    _prefetchWired = true;

    final media = ref.read(mediaServiceProvider);

    ref.listen<AsyncValue<CityBanner?>>(cityBannerProvider, (prev, next) {
      next.whenData((b) {
        final url = (b?.imageUrl ?? '').trim();
        if (url.isEmpty) return;
        media.precacheAnyImageRef(context, primary: url);
      });
    });

    ref.listen<AsyncValue<NearbyShopsState>>(nearbyShopsControllerProvider, (prev, next) {
      next.whenData((state) {
        for (final it in state.items.take(8)) {
          final s = it.shop;
          final primary = (s.coverUrl ?? s.coverPath ?? '').trim();
          if (primary.isEmpty) continue;
          media.precacheAnyImageRef(context, primary: primary, bucket: 'shop-images');
        }
      });
    });

    ref.listen<AsyncValue<NearbyBarbersState>>(nearbyBarbersControllerProvider, (prev, next) {
      next.whenData((state) {
        for (final it in state.items.take(10)) {
          final b = it.barber;
          final primary = (b.avatarUrl ?? b.avatarPath ?? '').trim();
          if (primary.isEmpty) continue;
          media.precacheAnyImageRef(context, primary: primary, bucket: 'barber-images');
        }
      });
    });

    ref.listen<AsyncValue<List<Offer>>>(cityOffersProvider, (prev, next) {
      next.whenData((items) {
        for (final o in items.take(10)) {
          final primary = (o.bannerUrl ?? o.bannerPath ?? '').trim();
          if (primary.isEmpty) continue;
          media.precacheAnyImageRef(context, primary: primary, bucket: 'offer-images');
        }
      });
    });

    ref.listen<AsyncValue<List<StyleLibraryItem>>>(cityPopularStylesProvider, (prev, next) {
      next.whenData((items) {
        for (final s in items.take(12)) {
          final primary = (s.coverUrl ?? s.coverPath ?? '').trim();
          if (primary.isEmpty) continue;
          media.precacheAnyImageRef(context, primary: primary, bucket: 'style-library');
        }
      });
    });

    ref.listen<AsyncValue<CityTrendingToday>>(cityTrendingTodayProvider, (prev, next) {
      next.whenData((t) {
        final primary = (t.mostWatchedReel?.thumbnailUrl ?? t.mostWatchedReel?.thumbnailPath ?? '').trim();
        if (primary.isEmpty) return;
        media.precacheAnyImageRef(context, primary: primary, bucket: 'reels');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedArea = ref.watch(areaControllerProvider);
    final bannerUrl = ref.watch(cityBannerProvider).valueOrNull?.imageUrl.trim();
    final defaultCityBanner = ref.watch(brandAssetUrlProvider('default_hallaq_city_banner'))?.trim();
    final errorImage = ref.watch(brandAssetUrlProvider('default_error_state'))?.trim();
    final emptyImage = ref.watch(brandAssetUrlProvider('default_empty_state'))?.trim();
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final locationLine = (profile?.location ?? '').trim().isNotEmpty
        ? (profile?.location ?? '').trim()
        : (selectedArea.trim().isEmpty ? '' : selectedArea.trim());

    final w = MediaQuery.sizeOf(context).width;
    final maxWidth = w >= 1200 ? 760.0 : (w >= 900 ? 640.0 : 520.0);
    return ResponsiveCenter(
      maxWidth: maxWidth,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          _Staggered(
            index: 0,
            child: _CityHeader(
              title: l10n.cityTitle,
              subtitle: l10n.citySubtitle,
              onNotifications: () => context.push('/notifications'),
              onSettings: () => context.push(Routes.settings),
            ),
          ),
          const SizedBox(height: 12),
          _Staggered(
            index: 1,
            child: AsyncValueWidget<CityStats>(
              value: ref.watch(cityStatsProvider),
              errorImageUrl: errorImage,
              onRetry: () => ref.invalidate(cityStatsProvider),
              loading: const _LocationCardSkeleton(),
              data: (stats) => _LocationCard(
                areaLabel: l10n.currentAreaLabel,
                location: locationLine.isEmpty ? l10n.cityTitle : locationLine,
                bannerUrl: (bannerUrl != null && bannerUrl.isNotEmpty) ? bannerUrl : defaultCityBanner,
                autoDetected: (profile?.lat != null && profile?.lng != null),
                barbersCount: stats.activeBarbers,
                shopsCount: stats.barberShops,
                offersCount: stats.activeOffers,
                onChangeArea: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const CityPickerSheet(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Staggered(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HallaqSectionTitle(title: l10n.quickActionsTitle),
                const SizedBox(height: 10),
                _QuickActions(
                  onBookBarber: () => context.push('/search?tab=barbers'),
                  onFindShops: () => context.push('/search?tab=shops'),
                  onDiscoverReels: () => context.go('/discover'),
                  onOffers: () => context.push('/offers'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 3,
            child: Column(
              children: [
                _SectionWithTrailing(
                  title: l10n.nearbyBarbers,
                  trailing: TextButton(
                    onPressed: () => context.push('/search?tab=barbers'),
                    child: Text(l10n.viewAll),
                  ),
                ),
                const SizedBox(height: 10),
                _NearbyBarbersRow(errorImage: errorImage, emptyImage: emptyImage),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 4,
            child: Column(
              children: [
                _SectionWithTrailing(
                  title: l10n.nearbyShops,
                  trailing: TextButton(
                    onPressed: () => context.push('/search?tab=shops'),
                    child: Text(l10n.viewAll),
                  ),
                ),
                const SizedBox(height: 10),
                _NearbyShopsRow(errorImage: errorImage, emptyImage: emptyImage),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 5,
            child: Column(
              children: [
                _SectionWithTrailing(
                  title: l10n.trendingToday,
                  trailing: TextButton(
                    onPressed: () => context.go('/discover'),
                    child: Text(l10n.viewAll),
                  ),
                ),
                const SizedBox(height: 10),
                AsyncValueWidget<CityTrendingToday>(
                  value: ref.watch(cityTrendingTodayProvider),
                  errorImageUrl: errorImage,
                  onRetry: () => ref.invalidate(cityTrendingTodayProvider),
                  loading: const _TrendingTodayLoadingRow(),
                  data: (t) => _TrendingTodayRow(trending: t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 6,
            child: Column(
              children: [
                _SectionWithTrailing(
                  title: l10n.offersNearYou,
                  trailing: TextButton(
                    onPressed: () => context.push('/offers'),
                    child: Text(l10n.viewAll),
                  ),
                ),
                const SizedBox(height: 10),
                _OffersRow(errorImage: errorImage, emptyImage: emptyImage),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 7,
            child: Column(
              children: [
                _SectionWithTrailing(
                  title: l10n.popularStyles,
                  trailing: const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                _PopularStylesRow(errorImage: errorImage, emptyImage: emptyImage),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Staggered(
            index: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HallaqSectionTitle(title: l10n.cityStatistics),
                const SizedBox(height: 10),
                AsyncValueWidget<CityStats>(
                  value: ref.watch(cityStatsProvider),
                  errorImageUrl: errorImage,
                  onRetry: () => ref.invalidate(cityStatsProvider),
                  loading: const _CityStatsRowSkeleton(),
                  data: (stats) => _CityStatsRow(stats: stats),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  const _CityHeader({
    required this.title,
    required this.subtitle,
    required this.onNotifications,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: compact ? 0 : 44, right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.goldDeep,
                              fontWeight: FontWeight.w900,
                              letterSpacing: compact ? 1.8 : 2.8,
                            ),
                        textAlign: compact ? TextAlign.start : TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: compact ? TextAlign.start : TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LuxuryIconButton(icon: Icons.notifications_none_rounded, size: compact ? 40 : 44, onPressed: onNotifications),
                  const SizedBox(width: 8),
                  LuxuryIconButton(icon: Icons.settings_outlined, size: compact ? 40 : 44, onPressed: onSettings),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String areaLabel;
  final String location;
  final String? bannerUrl;
  final bool autoDetected;
  final int barbersCount;
  final int shopsCount;
  final int offersCount;
  final VoidCallback onChangeArea;

  const _LocationCard({
    required this.areaLabel,
    required this.location,
    required this.bannerUrl,
    required this.autoDetected,
    required this.barbersCount,
    required this.shopsCount,
    required this.offersCount,
    required this.onChangeArea,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HallaqCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          children: [
            Positioned.fill(
              child: LuxuryNetworkImage(
                imageUrl: bannerUrl,
                fallbackUrl: '',
                fallbackKey: 'default_hallaq_city_banner',
                height: 142,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0B0B0B).withValues(alpha: 0.92),
                      const Color(0xFF0B0B0B).withValues(alpha: 0.55),
                      const Color(0xFF0B0B0B).withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.2,
                      colors: [
                        AppTheme.gold.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22), width: 1),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final metricWidth = compact ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 20) / 3;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (compact) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.gold, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    areaLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    location,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _MiniOutlineButton(label: l10n.changeArea, onTap: onChangeArea),
                        ),
                      ] else
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.gold, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    areaLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _MiniOutlineButton(label: l10n.changeArea, onTap: onChangeArea),
                          ],
                        ),
                      const SizedBox(height: 10),
                      if (autoDetected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F).withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF3CE685), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                l10n.autoDetected,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: metricWidth, child: _MiniMetric(icon: Icons.content_cut_rounded, label: l10n.barbersLabel, value: barbersCount)),
                          SizedBox(width: metricWidth, child: _MiniMetric(icon: Icons.storefront_rounded, label: l10n.shopsLabel, value: shopsCount)),
                          SizedBox(width: metricWidth, child: _MiniMetric(icon: Icons.local_offer_rounded, label: l10n.offers, value: offersCount)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniOutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HallaqHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.gold),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.gold, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _MiniMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionWithTrailing extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionWithTrailing({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onBookBarber;
  final VoidCallback onFindShops;
  final VoidCallback onDiscoverReels;
  final VoidCallback onOffers;

  const _QuickActions({
    required this.onBookBarber,
    required this.onFindShops,
    required this.onDiscoverReels,
    required this.onOffers,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final gap = 10.0;
      final itemW = (maxW - gap * 3) / 4;
      final cards = [
        _QuickActionTile(width: itemW, assetIcon: 'assets/icons/scissors.svg', fallbackIcon: Icons.content_cut_rounded, label: l10n.bookBarber, onTap: onBookBarber),
        _QuickActionTile(width: itemW, assetIcon: 'assets/icons/shop.svg', fallbackIcon: Icons.storefront_rounded, label: l10n.findShops, onTap: onFindShops),
        _QuickActionTile(width: itemW, assetIcon: 'assets/icons/reels.svg', fallbackIcon: Icons.play_circle_outline_rounded, label: l10n.discoverReels, onTap: onDiscoverReels),
        _QuickActionTile(width: itemW, assetIcon: 'assets/icons/tag.svg', fallbackIcon: Icons.local_offer_rounded, label: l10n.offers, onTap: onOffers),
      ];
      if (itemW >= 92) {
        return Row(
          children: [
            Expanded(child: cards[0]),
            SizedBox(width: gap),
            Expanded(child: cards[1]),
            SizedBox(width: gap),
            Expanded(child: cards[2]),
            SizedBox(width: gap),
            Expanded(child: cards[3]),
          ],
        );
      }
      return SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, i) => SizedBox(width: 104, child: cards[i]),
          separatorBuilder: (_, __) => SizedBox(width: gap),
          itemCount: cards.length,
        ),
      );
    });
  }
}

class _QuickActionTile extends StatelessWidget {
  final double width;
  final String assetIcon;
  final IconData fallbackIcon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({required this.width, required this.assetIcon, required this.fallbackIcon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: HallaqCard(
        glass: true,
        onTap: () {
          HallaqHaptics.tap();
          onTap();
        },
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoldIconBadge(asset: assetIcon, fallbackIcon: fallbackIcon),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.1, height: 1.1),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldIconBadge extends StatelessWidget {
  final String asset;
  final IconData fallbackIcon;

  const _GoldIconBadge({required this.asset, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gold.withValues(alpha: 0.22),
            const Color(0xFF0B0B0B).withValues(alpha: 0.0),
          ],
        ),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.30)),
        boxShadow: [
          ...AppTheme.softShadow(opacity: 0.14),
          ...AppTheme.goldGlow(opacity: 0.10, blur: 18, y: 10),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(AppTheme.gold, BlendMode.srcIn),
          placeholderBuilder: (_) => Icon(fallbackIcon, color: AppTheme.gold, size: 22),
        ),
      ),
    );
  }
}

class _NearbyBarbersRow extends ConsumerWidget {
  final String? errorImage;
  final String? emptyImage;

  const _NearbyBarbersRow({required this.errorImage, required this.emptyImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(nearbyBarbersControllerProvider);
    return AsyncValueWidget(
      value: value,
      errorImageUrl: errorImage,
      onRetry: () => ref.read(nearbyBarbersControllerProvider.notifier).refresh(),
      loading: const _NearbyBarbersLoadingRow(),
      data: (state) {
        if (state.items.isEmpty) {
          return HallaqEmptyState(
            title: l10n.noBarbersNearbyTitle,
            description: l10n.noBarbersNearbyDescription,
            imageUrl: emptyImage,
            compact: true,
            showMascot: true,
            actionLabel: l10n.changeArea,
            onAction: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => CityPickerSheet(),
            ),
          );
        }
        return SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _NearbyBarberCard(item: item);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: state.items.length.clamp(0, 12),
          ),
        );
      },
    );
  }
}

class _NearbyBarberCard extends StatelessWidget {
  final dynamic item;

  const _NearbyBarberCard({required this.item});

  String _nextTimeLabel(AppLocalizations l10n) {
    final min = item.barber.waitingTimeMin as int?;
    if (min == null) return l10n.nextTime(item.barber.availableNow ? l10n.now : l10n.today);
    final t = DateTime.now().add(Duration(minutes: min));
    return l10n.nextTime(DateFormat('h:mm a').format(t));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final b = item.barber;
    final verified = (b.badgeVerified as bool?) ?? false;
    final distanceKm = (item.distanceKm as double?);
    final distanceLabel = (distanceKm == null || !distanceKm.isFinite) ? '—' : '${distanceKm.toStringAsFixed(1)} km';
    return SizedBox(
      width: 188,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HallaqAvatar(imageUrl: b.avatarUrl ?? b.avatarPath, size: 44, bucket: 'barber-images'),
                const SizedBox(width: 10),
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
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.verified_rounded, color: AppTheme.gold, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HallaqRating(value: (b.ratingAvg as double?) ?? 0, count: (b.ratingCount as int?) ?? 0, iconSize: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_rounded, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(
                  distanceLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _nextTimeLabel(l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF3CE685), fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            HallaqButton(
              label: l10n.bookNow,
              expanded: true,
              onPressed: () => context.push('/booking/new?barberId=${b.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyShopsRow extends ConsumerWidget {
  final String? errorImage;
  final String? emptyImage;

  const _NearbyShopsRow({required this.errorImage, required this.emptyImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shopFallback = ref.watch(brandAssetUrlProvider('default_shop_cover'))?.trim();
    final value = ref.watch(nearbyShopsControllerProvider);
    return AsyncValueWidget(
      value: value,
      errorImageUrl: errorImage,
      onRetry: () => ref.read(nearbyShopsControllerProvider.notifier).refresh(),
      loading: const _NearbyShopsLoadingRow(),
      data: (state) {
        if (state.items.isEmpty) {
          return HallaqEmptyState(
            title: l10n.noShopsNearbyTitle,
            description: l10n.noShopsNearbyDescription,
            imageUrl: emptyImage,
            compact: true,
            showMascot: true,
            actionLabel: l10n.changeArea,
            onAction: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => CityPickerSheet(),
            ),
          );
        }
        return SizedBox(
          height: 256,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _NearbyShopCard(item: item, fallbackUrl: shopFallback);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: state.items.length.clamp(0, 12),
          ),
        );
      },
    );
  }
}

class _NearbyShopCard extends StatelessWidget {
  final dynamic item;
  final String? fallbackUrl;

  const _NearbyShopCard({required this.item, required this.fallbackUrl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = item.shop;
    final opening = openingStatusFromHours(s.openingHours as Map<String, dynamic>?, DateTime.now());
    final distanceKm = (item.distanceKm as double?);
    final distanceLabel = (distanceKm == null || !distanceKm.isFinite) ? '—' : '${distanceKm.toStringAsFixed(1)} km';
    final primary = opening.primaryLabel.trim();
    final statusLabel = opening.isOpen ? l10n.open : l10n.closed;
    final secondaryLabel = primary.isEmpty || primary.toLowerCase() == statusLabel.toLowerCase() ? '' : primary;
    return SizedBox(
      width: 244,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                children: [
                  LuxuryNetworkImage(
                    imageUrl: s.coverUrl ?? s.coverPath,
                    bucket: 'shop-images',
                    fallbackUrl: (fallbackUrl ?? '').trim(),
                    fallbackKey: 'default_shop_cover',
                    height: 92,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0B0B).withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.favorite_border_rounded, size: 16, color: AppTheme.gold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                HallaqRating(value: s.ratingAvg, count: s.ratingCount, iconSize: 14),
                const Spacer(),
                const Icon(Icons.place_rounded, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(
                  distanceLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: opening.isOpen ? const Color(0xFF3CE685) : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: opening.isOpen ? const Color(0xFF3CE685) : AppTheme.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: secondaryLabel.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          secondaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
            const Spacer(),
            HallaqButton(
              label: l10n.viewShop,
              expanded: true,
              variant: HallaqButtonVariant.secondary,
              onPressed: () => context.push('${Routes.shopProfile}/${s.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTodayRow extends StatelessWidget {
  final CityTrendingToday trending;

  const _TrendingTodayRow({required this.trending});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.locale.languageCode == 'ar';
    final items = [
      _MiniTrendCard(
        icon: Icons.workspace_premium_rounded,
        title: l10n.mostBookedBarber,
        value: trending.mostBookedBarber?.displayName ?? '—',
        footnote: trending.mostBookedBarber == null ? '' : l10n.bookingsToday(trending.mostBookedBarber!.bookingsCount.toString()),
      ),
      _MiniTrendCard(
        icon: Icons.storefront_rounded,
        title: l10n.mostBookedShop,
        value: trending.mostBookedShop?.name ?? '—',
        footnote: trending.mostBookedShop == null ? '' : l10n.bookingsToday(trending.mostBookedShop!.bookingsCount.toString()),
      ),
      _MiniTrendCard(
        icon: Icons.play_circle_fill_rounded,
        title: l10n.mostWatchedReel,
        value: (trending.mostWatchedReel?.caption ?? '').trim().isEmpty ? l10n.trendingReel : (trending.mostWatchedReel?.caption ?? '').trim(),
        footnote: trending.mostWatchedReel == null ? '' : l10n.viewsToday(trending.mostWatchedReel!.viewsCount.toString()),
      ),
      _MiniTrendCard(
        icon: Icons.star_rounded,
        title: l10n.mostLikedStyle,
        value: trending.mostLikedStyle == null ? '—' : (isAr && trending.mostLikedStyle!.nameAr.trim().isNotEmpty ? trending.mostLikedStyle!.nameAr : trending.mostLikedStyle!.nameEn),
        footnote: trending.mostLikedStyle == null ? '' : l10n.likesToday(trending.mostLikedStyle!.viewsCount.toString()),
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        itemBuilder: (context, i) => SizedBox(width: 214, child: items[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _MiniTrendCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String footnote;

  const _MiniTrendCard({required this.icon, required this.title, required this.value, required this.footnote});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: AppTheme.goldGradient,
              boxShadow: [
                ...AppTheme.softShadow(opacity: 0.26),
                ...AppTheme.goldGlow(opacity: 0.14, blur: 22, y: 10),
              ],
            ),
            child: Icon(icon, color: Colors.black, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.1),
          ),
          if (footnote.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(footnote, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _OffersRow extends ConsumerWidget {
  final String? errorImage;
  final String? emptyImage;

  const _OffersRow({required this.errorImage, required this.emptyImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(cityOffersProvider);
    final defaultOffer = ref.watch(brandAssetUrlProvider('default_offer_image'))?.trim();
    return AsyncValueWidget(
      value: value,
      errorImageUrl: errorImage,
      onRetry: () => ref.invalidate(cityOffersProvider),
      loading: const _OffersLoadingRow(),
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
            title: l10n.noOffersRightNowTitle,
            description: l10n.noOffersRightNowDescription,
            imageUrl: emptyImage,
            compact: true,
            showMascot: true,
          );
        }
        return SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2),
            itemBuilder: (context, index) => _OfferCard(offer: items[index], defaultOfferImage: defaultOffer),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length.clamp(0, 12),
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final dynamic offer;
  final String? defaultOfferImage;

  const _OfferCard({required this.offer, required this.defaultOfferImage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final discount = offer.discountPercent != null ? '${offer.discountPercent.toStringAsFixed(0)}%' : '';
    final expires = offer.validTo == null ? null : DateFormat('d MMM').format(offer.validTo as DateTime);
    final img = (offer.bannerUrl as String?)?.trim();
    final title = (offer.title as String?)?.trim().isNotEmpty == true ? (offer.title as String).trim() : l10n.specialOffer;
    final desc = (offer.description as String?)?.trim().isNotEmpty == true ? (offer.description as String).trim() : l10n.premiumDealNearYou;
    return SizedBox(
      width: 236,
      child: HallaqCard(
        glass: true,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Stack(
            children: [
              Positioned.fill(
                child: LuxuryNetworkImage(
                  imageUrl: img,
                  fallbackUrl: (defaultOfferImage ?? '').trim(),
                  fallbackKey: 'default_offer_image',
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0B0B0B).withValues(alpha: 0.82),
                        const Color(0xFF0B0B0B).withValues(alpha: 0.55),
                        const Color(0xFF0B0B0B).withValues(alpha: 0.86),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.20)),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discount.isNotEmpty)
                      Text(
                        l10n.discountOff(discount),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900, height: 1),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (expires != null)
                      Text(
                        l10n.validUntil(expires),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                      ),
                    const SizedBox(height: 10),
                    HallaqButton(
                      label: l10n.bookNow,
                      expanded: true,
                      onPressed: () {
                        final shopId = (offer.shopId as String?)?.trim();
                        final barberId = (offer.barberId as String?)?.trim();
                        if (shopId != null && shopId.isNotEmpty) {
                          context.push('/booking/new?shopId=$shopId');
                          return;
                        }
                        if (barberId != null && barberId.isNotEmpty) {
                          context.push('/booking/new?barberId=$barberId');
                          return;
                        }
                        context.push('/offers');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularStylesRow extends ConsumerWidget {
  final String? errorImage;
  final String? emptyImage;

  const _PopularStylesRow({required this.errorImage, required this.emptyImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(cityPopularStylesProvider);
    final defaultStyle = ref.watch(brandAssetUrlProvider('default_style_image'))?.trim();
    return AsyncValueWidget(
      value: value,
      errorImageUrl: errorImage,
      onRetry: () => ref.invalidate(cityPopularStylesProvider),
      loading: const _StylesLoadingRow(),
      data: (items) {
        if (items.isEmpty) {
          return HallaqEmptyState(
            title: l10n.noStylesYetTitle,
            description: l10n.noStylesYetDescription,
            imageUrl: emptyImage,
            compact: true,
            showMascot: true,
          );
        }
        final isAr = l10n.locale.languageCode == 'ar';
        return SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2),
            itemBuilder: (context, index) {
              final s = items[index];
              final title = isAr && s.nameAr.trim().isNotEmpty ? s.nameAr : s.nameEn;
              return _StyleCard(style: s, title: title, defaultStyleImage: defaultStyle);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length.clamp(0, 18),
          ),
        );
      },
    );
  }
}

class _StyleCard extends StatelessWidget {
  final StyleLibraryItem style;
  final String title;
  final String? defaultStyleImage;

  const _StyleCard({required this.style, required this.title, required this.defaultStyleImage});

  @override
  Widget build(BuildContext context) {
    final img = (style.coverUrl ?? '').trim();
    return SizedBox(
      width: 112,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/style/${style.id}'),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: LuxuryNetworkImage(
                imageUrl: img,
                fallbackUrl: (defaultStyleImage ?? '').trim(),
                fallbackKey: 'default_style_image',
                width: 92,
                height: 64,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityStatsRow extends StatelessWidget {
  final CityStats stats;

  const _CityStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, c) {
      const w1 = 92.0;
      const w2 = 92.0;
      const w3 = 112.0;
      const w4 = 102.0;
      const vLine = 21.0;
      const requiredW = w1 + w2 + w3 + w4 + (vLine * 3);
      final row = Row(
        children: [
          SizedBox(width: w1, child: _CityStatMini(icon: Icons.person_rounded, label: l10n.activeBarbersStat, value: stats.activeBarbers.toString())),
          _VLine(),
          SizedBox(width: w2, child: _CityStatMini(icon: Icons.storefront_rounded, label: l10n.barberShopsStat, value: stats.barberShops.toString())),
          _VLine(),
          SizedBox(width: w3, child: _CityStatMini(icon: Icons.event_available_rounded, label: l10n.monthlyBookingsStat, value: stats.monthlyBookings.toString())),
          _VLine(),
          SizedBox(width: w4, child: _CityStatMini(icon: Icons.star_rounded, label: l10n.averageRatingStat, value: stats.averageRating.toStringAsFixed(1))),
        ],
      );
      return HallaqCard(
        glass: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: c.maxWidth < requiredW ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row) : row,
      );
    });
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.gold.withValues(alpha: 0.12),
    );
  }
}

class _CityStatMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CityStatMini({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonLine({required this.width, required this.height, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    return GoldShimmer(width: width, height: height, borderRadius: BorderRadius.circular(radius));
  }
}

class _LocationCardSkeleton extends StatelessWidget {
  const _LocationCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SkeletonLine(width: 18, height: 18, radius: 6),
                const SizedBox(width: 8),
                const Expanded(child: _SkeletonLine(width: double.infinity, height: 12)),
                const SizedBox(width: 10),
                const _SkeletonLine(width: 98, height: 32, radius: 999),
              ],
            ),
            const SizedBox(height: 10),
            const _SkeletonLine(width: 160, height: 16),
            const SizedBox(height: 10),
            const _SkeletonLine(width: 110, height: 24, radius: 999),
            const Spacer(),
            Row(
              children: const [
                Expanded(child: _SkeletonLine(width: double.infinity, height: 48, radius: 18)),
                SizedBox(width: 10),
                Expanded(child: _SkeletonLine(width: double.infinity, height: 48, radius: 18)),
                SizedBox(width: 10),
                Expanded(child: _SkeletonLine(width: double.infinity, height: 48, radius: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyBarbersLoadingRow extends StatelessWidget {
  const _NearbyBarbersLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 6,
        itemBuilder: (_, __) => const _NearbyBarberCardSkeleton(),
      ),
    );
  }
}

class _NearbyBarberCardSkeleton extends StatelessWidget {
  const _NearbyBarberCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GoldShimmer(width: 44, height: 44, borderRadius: BorderRadius.circular(999)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonLine(width: double.infinity, height: 14),
                      SizedBox(height: 8),
                      _SkeletonLine(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _SkeletonLine(width: 90, height: 12),
            const SizedBox(height: 8),
            const _SkeletonLine(width: 120, height: 12),
            const Spacer(),
            const _SkeletonLine(width: double.infinity, height: 46, radius: AppTheme.radiusMd),
          ],
        ),
      ),
    );
  }
}

class _NearbyShopsLoadingRow extends StatelessWidget {
  const _NearbyShopsLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 244,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 6,
        itemBuilder: (_, __) => const _NearbyShopCardSkeleton(),
      ),
    );
  }
}

class _NearbyShopCardSkeleton extends StatelessWidget {
  const _NearbyShopCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GoldShimmer(width: double.infinity, height: 92, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            const SizedBox(height: 10),
            const _SkeletonLine(width: 160, height: 14),
            const SizedBox(height: 8),
            const _SkeletonLine(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const _SkeletonLine(width: 140, height: 12),
            const Spacer(),
            const _SkeletonLine(width: double.infinity, height: 46, radius: AppTheme.radiusMd),
          ],
        ),
      ),
    );
  }
}

class _TrendingTodayLoadingRow extends StatelessWidget {
  const _TrendingTodayLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 4,
        itemBuilder: (_, __) => const _MiniTrendCardSkeleton(),
      ),
    );
  }
}

class _MiniTrendCardSkeleton extends StatelessWidget {
  const _MiniTrendCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 214,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SkeletonLine(width: 34, height: 34, radius: 14),
            SizedBox(height: 10),
            _SkeletonLine(width: 130, height: 12),
            SizedBox(height: 8),
            _SkeletonLine(width: double.infinity, height: 14),
            SizedBox(height: 8),
            _SkeletonLine(width: 120, height: 12),
          ],
        ),
      ),
    );
  }
}

class _OffersLoadingRow extends StatelessWidget {
  const _OffersLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 5,
        itemBuilder: (_, __) => const _OfferCardSkeleton(),
      ),
    );
  }
}

class _OfferCardSkeleton extends StatelessWidget {
  const _OfferCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: HallaqCard(
        glass: true,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Stack(
            children: [
              Positioned.fill(
                child: GoldShimmer(width: double.infinity, height: double.infinity, borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonLine(width: 90, height: 20),
                    SizedBox(height: 10),
                    _SkeletonLine(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    _SkeletonLine(width: double.infinity, height: 12),
                    Spacer(),
                    _SkeletonLine(width: 140, height: 12),
                    SizedBox(height: 10),
                    _SkeletonLine(width: double.infinity, height: 46, radius: AppTheme.radiusMd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StylesLoadingRow extends StatelessWidget {
  const _StylesLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 8,
        itemBuilder: (_, __) => const _StyleCardSkeleton(),
      ),
    );
  }
}

class _StyleCardSkeleton extends StatelessWidget {
  const _StyleCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(10),
        child: Column(
          children: const [
            _SkeletonLine(width: 84, height: 60, radius: AppTheme.radiusMd),
            SizedBox(height: 8),
            _SkeletonLine(width: 70, height: 12),
          ],
        ),
      ),
    );
  }
}

class _CityStatsRowSkeleton extends StatelessWidget {
  const _CityStatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _SkeletonLine(width: 72, height: 46, radius: 16),
          _SkeletonLine(width: 72, height: 46, radius: 16),
          _SkeletonLine(width: 92, height: 46, radius: 16),
          _SkeletonLine(width: 82, height: 46, radius: 16),
        ],
      ),
    );
  }
}

class _Staggered extends StatefulWidget {
  final int index;
  final Widget child;

  const _Staggered({required this.index, required this.child});

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    final delay = 70 * widget.index;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _on = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      opacity: _on ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _on ? Offset.zero : const Offset(0, 0.06),
        child: widget.child,
      ),
    );
  }
}
