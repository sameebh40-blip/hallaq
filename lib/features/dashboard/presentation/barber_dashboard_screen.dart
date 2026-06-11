import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/review.dart';
import '../../../core/models/reel.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_line_chart.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../barber/data/barber_clients_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/barber_dashboard_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../../explore/data/reels_repository.dart';
import '../../trending/data/trending_repository.dart';
import 'barber_bookings_screen.dart';
import 'barber_profile_tab.dart';
import 'barber_quick_create_sheet.dart';
import 'barber_reels_center_tab.dart';

final _shopNameProvider = FutureProvider.family<String?, String>((ref, shopId) async {
  final shop = await ref.watch(shopRepositoryProvider).getById(shopId);
  return shop.name;
});

class BarberDashboardScreen extends ConsumerStatefulWidget {
  const BarberDashboardScreen({super.key});

  @override
  ConsumerState<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends ConsumerState<BarberDashboardScreen> {
  int _index = 0;

  Future<void> _openQuickCreate(BuildContext context) async {
    final action = await showModalBottomSheet<BarberQuickCreateAction>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (context) => const BarberQuickCreateSheet(),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case BarberQuickCreateAction.uploadReel:
        context.push(Routes.barberUploadReel);
        return;
      case BarberQuickCreateAction.addPortfolio:
        context.push(Routes.barberManagePortfolio);
        return;
      case BarberQuickCreateAction.blockTime:
        context.push(Routes.barberManageAvailability);
        return;
      case BarberQuickCreateAction.addService:
        context.push(Routes.barberManageServices);
        return;
      case BarberQuickCreateAction.createOffer:
        context.push(Routes.barberManageOffers);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      safeBottom: false,
      bottom: HallaqBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onActionTap: () => _openQuickCreate(context),
        items: [
          const HallaqBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
          const HallaqBottomNavItem(icon: Icons.event_available_outlined, label: 'Bookings'),
          const HallaqBottomNavItem(icon: Icons.play_circle_outline_rounded, label: 'Reels'),
          const HallaqBottomNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
      ),
      child: IndexedStack(
        index: _index,
        children: const [
          _BarberHomeTab(),
          BarberBookingsScreen(),
          BarberReelsCenterTab(),
          BarberProfileTab(),
        ],
      ),
    );
  }
}

class _BarberHomeTab extends ConsumerWidget {
  const _BarberHomeTab();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(myBarberProvider);
    final kpisValue = ref.watch(barberHomeKpisProvider);
    final weekValue = ref.watch(barberWeekSeriesProvider);
    final upcomingValue = ref.watch(barberDashboardUpcomingAppointmentsProvider);
    final reviewsValue = ref.watch(myBarberReviewsProvider);
    final notificationsValue = ref.watch(myNotificationsProvider);
    final clientsValue = ref.watch(myBarberClientsProvider);
    final myReelsValue = ref.watch(myBarberReelsManageProvider);

    return AsyncValueWidget(
      value: barberValue,
      data: (b) {
        if (b == null) {
          return const Center(
            child: HallaqEmptyState(
              title: 'No barber profile',
              description: 'This account is not linked to a barber yet.',
              compact: true,
              showMascot: true,
            ),
          );
        }

        final shopNameValue = (b.shopId ?? '').trim().isEmpty ? null : ref.watch(_shopNameProvider(b.shopId!));
        final name = b.displayName.trim().isEmpty ? 'Barber' : b.displayName.trim();
        final firstName = name.split(' ').where((e) => e.trim().isNotEmpty).take(1).join(' ');
        final statusLabel = !b.isActive
            ? 'Offline'
            : b.availableNow
                ? 'Available'
                : 'Busy';
        final statusColor = switch (statusLabel) {
          'Available' => AppTheme.success,
          'Busy' => AppTheme.gold,
          _ => AppTheme.textMuted,
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final brand = RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.3),
                    children: const [
                      TextSpan(text: 'HALLAQ ', style: TextStyle(color: AppTheme.gold)),
                      TextSpan(text: 'BARBER', style: TextStyle(color: AppTheme.text)),
                    ],
                  ),
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AsyncValueWidget<List<AppNotification>>(
                      value: notificationsValue,
                      data: (items) {
                        final unread = items.where((e) => !e.read).length;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => context.push('/notifications'),
                              icon: const Icon(Icons.notifications_none_rounded),
                              color: AppTheme.text,
                            ),
                            if (unread > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(999)),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => context.push('/support'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      color: AppTheme.text,
                    ),
                    const SizedBox(width: 6),
                    HallaqAvatar(imageUrl: b.avatarUrl, size: 34),
                  ],
                );

                if (!compact) {
                  return Row(
                    children: [
                      IconButton(
                        onPressed: () => context.push(Routes.barberManageSettings),
                        icon: const Icon(Icons.menu_rounded),
                        color: AppTheme.text,
                      ),
                      const Spacer(),
                      brand,
                      const Spacer(),
                      actions,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push(Routes.barberManageSettings),
                          icon: const Icon(Icons.menu_rounded),
                          color: AppTheme.text,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: brand)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${_greeting()}, $firstName 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text('Let’s make today amazing.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(statusLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (shopNameValue != null)
                  Expanded(
                    child: AsyncValueWidget<String?>(
                      value: shopNameValue,
                      data: (name) => Text(
                        (name ?? '').trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else if ((b.area ?? '').trim().isNotEmpty)
                  Expanded(child: Text(b.area!.trim(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted))),
              ],
            ),
            const SizedBox(height: 14),
            AsyncValueWidget<BarberHomeKpis?>(
              value: kpisValue,
              data: (k) {
                if (k == null) return const SizedBox.shrink();
                return HallaqCard(
                  glass: true,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total from bookings', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'BD ${k.revenueTodayBhd.value.toStringAsFixed(3)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          _GrowthPill(value: k.revenueTodayBhd.growthPct),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AsyncValueWidget<BarberWeekSeries?>(
                        value: weekValue,
                        data: (w) {
                          final values = (w?.bookings ?? const <int>[]).map((e) => e.toDouble()).toList(growable: false);
                          if (values.isEmpty) return const SizedBox.shrink();
                          return LuxuryLineChart(values: values, height: 86);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            AsyncValueWidget<BarberHomeKpis?>(
              value: kpisValue,
              data: (k) {
                if (k == null) return const SizedBox.shrink();
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  children: [
                    _KpiTile(title: 'Today’s Bookings', value: k.todayBookings.value.toInt().toString(), growthPct: k.todayBookings.growthPct, icon: Icons.event_available_outlined),
                    _KpiTile(title: 'Revenue Today', value: 'BD ${k.revenueTodayBhd.value.toStringAsFixed(3)}', growthPct: k.revenueTodayBhd.growthPct, icon: Icons.payments_outlined),
                    _KpiTile(title: 'Tips Today', value: 'BD ${k.tipsTodayBhd.value.toStringAsFixed(3)}', growthPct: k.tipsTodayBhd.growthPct, icon: Icons.volunteer_activism_outlined),
                    _KpiTile(title: 'New Followers', value: k.newFollowers.value.toInt().toString(), growthPct: k.newFollowers.growthPct, icon: Icons.person_add_alt_1_outlined),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text('My Reels', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            AsyncValueWidget<List<Reel>>(
              value: myReelsValue,
              data: (items) {
                final recent = items.where((e) => e.status == 'approved').take(3).toList(growable: false);
                final totalLikes = items.fold<int>(0, (p, e) => p + e.likesCount);
                final totalSaves = items.fold<int>(0, (p, e) => p + e.savesCount);
                final totalShares = items.fold<int>(0, (p, e) => p + e.sharesCount);
                final totalViews = ref.watch(barberPublicStatsProvider(b.id)).valueOrNull?.reelViews ?? 0;

                return HallaqCard(
                  glass: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _MiniMetric(label: 'Views', value: _compact(totalViews))),
                          Expanded(child: _MiniMetric(label: 'Likes', value: _compact(totalLikes))),
                          Expanded(child: _MiniMetric(label: 'Saves', value: _compact(totalSaves))),
                          Expanded(child: _MiniMetric(label: 'Shares', value: _compact(totalShares))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (recent.isNotEmpty)
                        Row(
                          children: List.generate(recent.length, (i) {
                            final r = recent[i];
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i == recent.length - 1 ? 0 : 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: LuxuryNetworkImage(
                                      imageUrl: (r.thumbnailUrl ?? '').trim().isNotEmpty ? r.thumbnailUrl! : r.mediaUrl,
                                      fallbackUrl: '',
                                      bucket: 'reels',
                                      borderRadius: BorderRadius.zero,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: HallaqEmptyState(
                            title: 'No reels yet',
                            description: 'Upload your first reel to reach more clients.',
                            compact: true,
                            showMascot: true,
                          ),
                        ),
                      const SizedBox(height: 12),
                      HallaqButton(label: 'Upload Reel', onPressed: () => context.push(Routes.barberUploadReel), icon: Icons.add_rounded),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Performance This Week', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => context.push(Routes.barberManageEarnings), child: const Text('View report')),
              ],
            ),
            const SizedBox(height: 10),
            AsyncValueWidget<BarberWeekSeries?>(
              value: weekValue,
              data: (w) {
                if (w == null) {
                  return const HallaqEmptyState(
                    title: 'No performance yet',
                    description: 'Charts will appear once you have bookings, followers, and reel views.',
                    compact: true,
                    showMascot: true,
                  );
                }
                return HallaqCard(
                  glass: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SeriesRow(label: 'Views', values: w.views),
                      const SizedBox(height: 12),
                      _SeriesRow(label: 'Followers', values: w.followers),
                      const SizedBox(height: 12),
                      _SeriesRow(label: 'Bookings', values: w.bookings),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Upcoming Clients', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => context.push(Routes.barberManageAppointments), child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 10),
            AsyncValueWidget(
              value: upcomingValue,
              data: (items) {
                if (items.isEmpty) {
                  return const HallaqEmptyState(
                    title: 'No upcoming appointments',
                    description: 'New requests and upcoming bookings will show here.',
                    compact: true,
                    showMascot: true,
                  );
                }
                return Column(
                  children: items.take(5).map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _AppointmentPreviewCard(row: m))).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Recent Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => context.push(Routes.barberManageReviews), child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 10),
            AsyncValueWidget(
              value: reviewsValue,
              data: (items) {
                if (items.isEmpty) {
                  return const HallaqEmptyState(
                    title: 'No reviews yet',
                    description: 'Reviews will appear here after completed bookings.',
                    compact: true,
                    showMascot: true,
                  );
                }
                return Column(children: items.take(3).map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReviewCard(review: r))).toList());
              },
            ),
            const SizedBox(height: 18),
            Text('Loyalty Impact', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            AsyncValueWidget<List<BarberClientSummary>>(
              value: clientsValue,
              data: (clients) {
                final returning = clients.where((c) => c.totalVisits >= 2).length;
                final retained = clients.where((c) => c.totalVisits >= 3).length;
                final tier = b.badgeTopRated
                    ? 'Top Rated'
                    : b.badgeElite
                        ? 'Elite'
                        : b.badgeVerified
                            ? 'Verified'
                            : 'Rising';
                return HallaqCard(
                  glass: true,
                  child: Row(
                    children: [
                      Expanded(child: _MiniMetric(label: 'Tier', value: tier)),
                      Expanded(child: _MiniMetric(label: 'Returning', value: returning.toString())),
                      Expanded(child: _MiniMetric(label: 'Retained', value: retained.toString())),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _GrowthPill extends StatelessWidget {
  final double value;

  const _GrowthPill({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN || value.isInfinite ? 0.0 : value;
    final up = v > 0.01;
    final down = v < -0.01;
    final color = up
        ? AppTheme.success
        : down
            ? AppTheme.error
            : AppTheme.textMuted;
    final prefix = up ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        '$prefix${v.toStringAsFixed(1)}%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final double growthPct;
  final IconData icon;

  const _KpiTile({required this.title, required this.value, required this.growthPct, required this.icon});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, color: AppTheme.gold, size: 20),
              ),
              const Spacer(),
              _GrowthPill(value: growthPct),
            ],
          ),
          const Spacer(),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  final String label;
  final List<int> values;

  const _SeriesRow({required this.label, required this.values});

  @override
  Widget build(BuildContext context) {
    final points = values.map((e) => e.toDouble()).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
              Text(_compact(values.fold<int>(0, (p, e) => p + e)), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          LuxuryLineChart(values: points, height: 72),
        ],
      ),
    );
  }
}

String _compact(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name = (review.customerName ?? '').trim().isEmpty ? 'Customer' : (review.customerName ?? '').trim();
    final text = (review.comment ?? '').trim();
    final rating = review.rating.toDouble();
    return HallaqCard(
      glass: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HallaqAvatar(imageUrl: review.customerAvatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                    HallaqRating(value: rating, showValue: true, iconSize: 14),
                  ],
                ),
                const SizedBox(height: 6),
                Text(text.isEmpty ? '—' : text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentPreviewCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _AppointmentPreviewCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(row['start_at'] as String).toLocal();
    final status = (row['status'] as String?) ?? 'pending';
    final customer = (row['profiles'] as Map?) == null ? null : Map<String, dynamic>.from(row['profiles'] as Map);
    final customerName = (customer?['full_name'] as String?) ?? 'Customer';
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = (service?['name_en'] as String?) ?? (service?['name'] as String?) ?? 'Service';
    final total = (row['total_price'] as num?)?.toDouble();
    final price = total ?? ((service?['price_bhd'] as num?)?.toDouble() ?? 0);

    final dt = DateFormat('EEE, MMM d · h:mm a').format(start);

    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          HallaqAvatar(imageUrl: customer?['avatar_url'] as String?, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('$serviceName · $dt', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BD ${price.toStringAsFixed(3)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
