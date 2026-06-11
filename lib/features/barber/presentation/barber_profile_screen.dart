import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/links/app_links.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/models/before_after_item.dart';
import '../../../core/models/portfolio_item.dart';
import '../../../core/models/review.dart';
import '../../../core/models/service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/engagement/engagement_repository.dart';
import '../../../core/social_proof/hallaq_badges.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_badges_row.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../before_after/data/before_after_repository.dart';
import '../../portfolio/data/portfolio_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../../reviews/presentation/write_review_screen.dart';
import '../../services/data/services_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../../trending/data/trending_repository.dart';
import '../../trending/presentation/trending_this_week_section.dart';
import '../data/barber_repository.dart';

class BarberProfileScreen extends ConsumerWidget {
  final String ref;

  const BarberProfileScreen({super.key, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final barberValue = ref.watch(_barberProvider(this.ref));

    ref.listen<AsyncValue<Barber>>(_barberProvider(this.ref), (prev, next) async {
      final barber = next.valueOrNull;
      if (barber == null) return;
      final tracked = ref.read(_trackedViewsProvider);
      if (tracked.contains(barber.id)) return;
      ref.read(_trackedViewsProvider.notifier).update((s) => {...s, barber.id});
      await ref.read(engagementRepositoryProvider).trackProfileView(targetType: 'barber', targetId: barber.id);
      ref.invalidate(viewsTodayProvider((targetType: 'barber', targetId: barber.id)));
      ref.invalidate(viewsWeekProvider((targetType: 'barber', targetId: barber.id)));
    });

    return LuxuryScaffold(
      child: AsyncValueWidget<Barber>(
        value: barberValue,
        data: (barber) {
          final shopValue = (barber.shopId ?? '').isEmpty ? const AsyncValue<Barbershop?>.data(null) : ref.watch(_shopByIdProvider(barber.shopId!)).whenData((s) => s as Barbershop?);
          final tab = ref.watch(_barberTabProvider(barber.id));

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
            children: [
              _BarberHero(
                barber: barber,
                shopValue: shopValue,
                onBack: () => context.pop(),
                onShare: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ShareQrSheet(barber: barber),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _BarberStatsRow(
                  rating: barber.ratingAvg,
                  reviews: barber.reviewsCount,
                  followers: barber.followersCount,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _BarberPublicStatsRow(barberId: barber.id),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: HallaqButton(
                        label: l10n.bookNow,
                        onPressed: () => context.push('/booking/new?barberId=${barber.id}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HallaqButton(
                        label: 'WhatsApp',
                        variant: HallaqButtonVariant.secondary,
                        onPressed: () async => _openWhatsApp(context, shopValue.valueOrNull?.whatsapp),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HallaqBadgesRow(badges: badgesForBarber(context, barber).take(4).toList()),
              ),
              const SizedBox(height: 12),
              TrendingThisWeekSection(currentBarberId: barber.id),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BarberTabs(
                  value: tab,
                  onChanged: (v) => ref.read(_barberTabProvider(barber.id).notifier).state = v,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: switch (tab) {
                  0 => _PortfolioTab(value: ref.watch(portfolioForBarberProvider(barber.id)), barberId: barber.id),
                  1 => _BeforeAfterTab(value: ref.watch(beforeAfterForBarberProvider(barber.id))),
                  2 => _ServicesTab(value: ref.watch(barberServicesProvider(barber.id)), barberId: barber.id),
                  3 => _ReviewsTab(
                      value: ref.watch(reviewsPreviewForTargetProvider((targetType: 'barber', targetId: barber.id))),
                      barberId: barber.id,
                    ),
                  _ => _AboutTab(barber: barber, shopValue: shopValue),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

final _barberTabProvider = StateProvider.family<int, String>((ref, barberId) => 0);
final _portfolioCategoryProvider = StateProvider.family<String?, String>((ref, barberId) => null);

class _BarberHero extends StatelessWidget {
  final Barber barber;
  final AsyncValue<Barbershop?> shopValue;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _BarberHero({
    required this.barber,
    required this.shopValue,
    required this.onBack,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final v = ((barber.id.hashCode.abs() % 9) + 1).toString().padLeft(2, '0');
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: LuxuryNetworkImage(
              imageUrl: barber.coverUrl,
              fallbackUrl: HallaqImages.professionalBarberPortrait(variant: v),
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
                      Colors.black.withValues(alpha: 0.20),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.0, 0.45, 1.0],
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
                  LuxuryIconButton(
                    icon: Icons.ios_share_rounded,
                    onPressed: () async => Share.share(AppLinks.barberProfile(barber.slug)),
                  ),
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
                    HallaqAvatar(imageUrl: barber.avatarUrl, size: 56, variant: v),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  barber.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (barber.badgeVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: AppTheme.gold, size: 20),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (barber.specialty ?? '').trim().isEmpty ? AppLocalizations.of(context).professional : barber.specialty!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          AsyncValueWidget<Barbershop?>(
                            value: shopValue,
                            data: (shop) {
                              final label = shop == null ? (barber.area ?? AppLocalizations.of(context).bahrain) : '${shop.name} • ${shop.area ?? ''}'.trim();
                              return Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarberStatsRow extends StatelessWidget {
  final double rating;
  final int reviews;
  final int followers;

  const _BarberStatsRow({required this.rating, required this.reviews, required this.followers});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _SimpleStat(label: 'Rating', value: rating.toStringAsFixed(1))),
          const SizedBox(width: 10),
          Expanded(child: _SimpleStat(label: AppLocalizations.of(context).reviews, value: reviews.toString())),
          const SizedBox(width: 10),
          Expanded(child: _SimpleStat(label: AppLocalizations.of(context).followers, value: followers.toString())),
        ],
      ),
    );
  }
}

class _SimpleStat extends StatelessWidget {
  final String label;
  final String value;

  const _SimpleStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _BarberPublicStatsRow extends ConsumerWidget {
  final String barberId;

  const _BarberPublicStatsRow({required this.barberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsValue = ref.watch(barberPublicStatsProvider(barberId));
    return AsyncValueWidget(
      value: statsValue,
      loading: const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (stats) {
        if (stats == null) return const SizedBox.shrink();
        final completion = stats.completionRate == null ? null : (stats.completionRate! * 100).round().clamp(0, 100);
        final response = stats.responseTimeMinutes?.round();
        return HallaqCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(child: _SimpleStat(label: 'Years', value: stats.yearsExperience.toString())),
              const SizedBox(width: 10),
              Expanded(child: _SimpleStat(label: 'Bookings', value: stats.totalBookings.toString())),
              const SizedBox(width: 10),
              Expanded(child: _SimpleStat(label: 'Response', value: response == null ? '—' : '${response}m')),
              const SizedBox(width: 10),
              Expanded(child: _SimpleStat(label: 'Completion', value: completion == null ? '—' : '$completion%')),
            ],
          ),
        );
      },
    );
  }
}

class _BarberTabs extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _BarberTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _TabChip(label: l10n.portfolio, selected: value == 0, onTap: () => onChanged(0)),
          const SizedBox(width: 10),
          _TabChip(label: 'Before & After', selected: value == 1, onTap: () => onChanged(1)),
          const SizedBox(width: 10),
          _TabChip(label: l10n.services, selected: value == 2, onTap: () => onChanged(2)),
          const SizedBox(width: 10),
          _TabChip(label: l10n.reviews, selected: value == 3, onTap: () => onChanged(3)),
          const SizedBox(width: 10),
          _TabChip(label: l10n.about, selected: value == 4, onTap: () => onChanged(4)),
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
          return Center(
            child: HallaqEmptyState(
              title: 'Before & After',
              description: 'No before & after yet',
              showMascot: true,
            ),
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

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TabChip(label: label, selected: selected, onTap: onTap);
  }
}

class _PortfolioTab extends ConsumerWidget {
  final AsyncValue<List<PortfolioItem>> value;
  final String barberId;

  const _PortfolioTab({required this.value, required this.barberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final selectedCategory = ref.watch(_portfolioCategoryProvider(barberId));

    return AsyncValueWidget<List<PortfolioItem>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: HallaqEmptyState(
              title: l10n.portfolio,
              description: l10n.noPortfolioDescription,
              showMascot: true,
            ),
          );
        }

        final categories = <String>{};
        for (final i in items) {
          final c = (i.category ?? '').trim();
          if (c.isNotEmpty) categories.add(c);
        }

        final filtered = selectedCategory == null
            ? items.toList(growable: false)
            : items.where((i) => (i.category ?? '').trim() == selectedCategory).toList(growable: false);

        filtered.sort((a, b) {
          final f = (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
          if (f != 0) return f;
          return b.createdAt.compareTo(a.createdAt);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (categories.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.all,
                      selected: selectedCategory == null,
                      onTap: () => ref.read(_portfolioCategoryProvider(barberId).notifier).state = null,
                    ),
                    ...categories.map(
                      (c) => Padding(
                        padding: const EdgeInsetsDirectional.only(start: 10),
                        child: _FilterChip(
                          label: c,
                          selected: selectedCategory == c,
                          onTap: () => ref.read(_portfolioCategoryProvider(barberId).notifier).state = c,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (filtered.isEmpty)
              Center(
                child: HallaqEmptyState(
                  title: l10n.portfolio,
                  description: l10n.noPortfolioDescription,
                  showMascot: true,
                  compact: true,
                ),
              )
            else
              _PortfolioGrid(items: filtered, languageCode: lang),
          ],
        );
      },
    );
  }
}

class _PortfolioGrid extends StatelessWidget {
  final List<PortfolioItem> items;
  final String languageCode;

  const _PortfolioGrid({required this.items, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final cap = item.displayCaption(languageCode);
        return HallaqCard(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: LuxuryNetworkImage(
                  imageUrl: (item.thumbnailPath ?? '').trim().isNotEmpty
                      ? item.thumbnailPath
                      : (item.thumbnailUrl ?? '').trim().isNotEmpty
                          ? item.thumbnailUrl
                          : item.mediaPath ?? item.imageUrl ?? item.mediaUrl,
                  fallbackUrl: '',
                  bucket: 'portfolio',
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              if (item.isFeatured)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                  ),
                ),
              if (cap.trim().isNotEmpty)
                PositionedDirectional(
                  start: 8,
                  end: 8,
                  bottom: 8,
                  child: Text(
                    cap,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.92),
                          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServicesTab extends StatelessWidget {
  final AsyncValue<List<Service>> value;
  final String barberId;

  const _ServicesTab({required this.value, required this.barberId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return AsyncValueWidget<List<Service>>(
      value: value,
      data: (items) {
        final list = items.where((s) => s.isActive).toList(growable: false);
        list.sort((a, b) {
          final p = (b.isPopular ? 1 : 0).compareTo(a.isPopular ? 1 : 0);
          if (p != 0) return p;
          return a.priceBhd.compareTo(b.priceBhd);
        });

        if (list.isEmpty) {
          return Center(
            child: HallaqEmptyState(
              title: l10n.services,
              description: l10n.noServicesDescription,
              showMascot: true,
            ),
          );
        }
        return Column(children: list.map((s) => _ServiceCard(service: s, barberId: barberId, languageCode: lang)).toList());
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final AsyncValue<List<Review>> value;
  final String barberId;

  const _ReviewsTab({required this.value, required this.barberId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
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
            final total = items.length;
            final sum = items.fold<int>(0, (p, e) => p + e.rating);
            final avg = total == 0 ? 0.0 : (sum / total);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HallaqCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.reviews,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      HallaqRating(value: avg, count: total),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...items.take(10).map((r) => _ReviewCard(review: r, languageCode: lang)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  final Barber barber;
  final AsyncValue<Barbershop?> shopValue;

  const _AboutTab({required this.barber, required this.shopValue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bio = (barber.bio ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HallaqSectionTitle(title: l10n.about),
        HallaqCard(
          child: Text(
            bio.isNotEmpty ? bio : l10n.bioFallback,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        AsyncValueWidget<Barbershop?>(
          value: shopValue,
          data: (shop) {
            if (shop == null) return const SizedBox.shrink();
            return _WorksAtShopCard(shopId: shop.id);
          },
        ),
      ],
    );
  }
}

Future<void> _openWhatsApp(BuildContext context, String? raw) async {
  try {
    final v = (raw ?? '').trim();
    if (v.isEmpty) {
      context.push('/support');
      return;
    }
    final phone = v.replaceAll(RegExp(r'\s+'), '');
    final url = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e);
  }
}

final _barberProvider = FutureProvider.family<Barber, String>((ref, barberRef) async {
  return ref.watch(barberRepositoryProvider).getByRef(barberRef);
});

final _trackedViewsProvider = StateProvider<Set<String>>((ref) => <String>{});

final _shopByIdProvider = FutureProvider.family<Barbershop, String>((ref, shopId) async {
  return ref.watch(shopRepositoryProvider).getById(shopId);
});

class _WorksAtShopCard extends ConsumerWidget {
  final String shopId;

  const _WorksAtShopCard({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shopValue = ref.watch(_shopByIdProvider(shopId));
    return AsyncValueWidget<Barbershop>(
      value: shopValue,
      data: (shop) {
        final v = ((shop.id.hashCode.abs() % 6) + 1).toString().padLeft(2, '0');
        return HallaqCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push('/shop/${shop.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: SizedBox(
              height: 140,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LuxuryNetworkImage(
                      imageUrl: shop.coverUrl,
                      fallbackUrl: HallaqImages.shopCover(variant: v),
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
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.86),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 14,
                    end: 14,
                    bottom: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.worksAt,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              if ((shop.area ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  shop.area!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppTheme.gold),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  final String barberId;
  final String languageCode;

  const _ServiceCard({required this.service, required this.barberId, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LuxuryNetworkImage(
                imageUrl: service.imageUrl,
                fallbackUrl: '',
                bucket: 'service-images',
                width: 72,
                height: 72,
                borderRadius: BorderRadius.zero,
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
                          service.displayName(languageCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (service.isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppTheme.gold.withValues(alpha: 0.14),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                          ),
                          child: Text(
                            l10n.popular,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${service.durationMin} ${l10n.minutes} • ${service.price.toStringAsFixed(2)} BHD',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            HallaqButton(
              label: l10n.select,
              expanded: false,
              onPressed: () => context.push('/booking/new?barberId=$barberId&serviceId=${service.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final String languageCode;

  const _ReviewCard({required this.review, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (review.customerName ?? '').trim();
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p.substring(0, 1).toUpperCase())
            .join();

    final dateText = DateFormat.yMMMd(languageCode).format(review.createdAt.toLocal());
    final text = (review.comment ?? '').trim();
    final photoUrl = (review.imageUrl ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.onyx2,
                        AppTheme.onyx4,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Customer' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                          if (review.isVerified) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.20)),
                              ),
                              child: Text(
                                l10n.verified,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                HallaqRating(value: review.rating.toDouble(), showValue: false, iconSize: 16),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (photoUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              LuxuryNetworkImage(
                imageUrl: photoUrl,
                fallbackUrl: HallaqImages.premiumMembership(variant: '02'),
                height: 180,
                borderRadius: BorderRadius.circular(18),
              ),
            ],
            if ((review.replyText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  color: AppTheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.reply, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text((review.replyText ?? '').trim(), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareQrSheet extends StatefulWidget {
  final Barber barber;

  const _ShareQrSheet({required this.barber});

  @override
  State<_ShareQrSheet> createState() => _ShareQrSheetState();
}

class _ShareQrSheetState extends State<_ShareQrSheet> {
  final _qrKey = GlobalKey();

  Barber get barber => widget.barber;

  Future<void> _shareLink() async {
    final url = AppLinks.barberProfile(barber.slug);
    await Share.share(url);
  }

  Future<void> _shareQr() async {
    final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final data = bytes.buffer.asUint8List();
    final file = XFile.fromData(data, mimeType: 'image/png', name: 'hallaq-${barber.slug}.png');
    await Share.shareXFiles([file], text: AppLinks.barberProfile(barber.slug));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = AppLinks.barberProfile(barber.slug);

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
                  Expanded(
                    child: Text(
                      barber.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 14),
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white,
                  ),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                    dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                url,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: HallaqButton(
                      label: l10n.share,
                      onPressed: _shareLink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HallaqButton(
                      label: l10n.qrCode,
                      variant: HallaqButtonVariant.secondary,
                      onPressed: _shareQr,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
