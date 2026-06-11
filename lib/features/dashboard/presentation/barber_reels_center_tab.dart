import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/reel.dart';
import '../../../core/routing/routes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_line_chart.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../barber/data/barber_repository.dart';
import '../../explore/data/reels_repository.dart';
import '../../trending/data/trending_repository.dart';
import 'barber_reel_controller.dart';

class BarberReelsOverview {
  final int totalViews;
  final int totalLikes;
  final int totalSaves;
  final int totalShares;
  final int totalBookingsGenerated;
  final Map<String, int> bookingsByReelId;
  final List<Reel> allReels;
  final List<Reel> topReels;

  const BarberReelsOverview({
    required this.totalViews,
    required this.totalLikes,
    required this.totalSaves,
    required this.totalShares,
    required this.totalBookingsGenerated,
    required this.bookingsByReelId,
    required this.allReels,
    required this.topReels,
  });
}

final barberReelsOverviewProvider = FutureProvider.autoDispose<BarberReelsOverview?>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return null;
  final client = ref.watch(supabaseClientProvider);

  try {
    final publicStats = await ref.watch(barberPublicStatsProvider(barber.id).future);

    List rows;
    try {
      rows = await client
          .from('reels')
          .select(
            'id, created_at, status, media_type, media_url, media_path, media_bucket, thumbnail_url, thumbnail_path, thumbnail_bucket, caption, location, hashtags, likes_count, comments_count, saves_count, shares_count, views_count',
          )
          .eq('barber_id', barber.id)
          .isFilter('deleted_at', null)
          .limit(600);
    } catch (e) {
      rows = await client
          .from('reels')
          .select(
            'id, created_at, status, media_type, media_url, media_path, media_bucket, thumbnail_url, thumbnail_path, thumbnail_bucket, caption, location, hashtags, likes_count, comments_count, saves_count, shares_count',
          )
          .eq('barber_id', barber.id)
          .isFilter('deleted_at', null)
          .limit(600);
    }

    final list = (rows as List).map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
    final views = publicStats?.reelViews ?? 0;
    var likes = 0;
    var saves = 0;
    var shares = 0;
    for (final r in list) {
      likes += r.likesCount;
      saves += r.savesCount;
      shares += r.sharesCount;
    }

    final bookingsByReelId = <String, int>{};
    var totalBookingsGenerated = 0;
    try {
      final data = await client
          .from('bookings')
          .select('source_post_id, status')
          .eq('barber_id', barber.id)
          .not('source_post_id', 'is', null)
          .inFilter('status', const ['pending', 'confirmed', 'in_progress', 'rescheduled', 'completed'])
          .limit(2000);
      for (final raw in (data as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['source_post_id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        bookingsByReelId[id] = (bookingsByReelId[id] ?? 0) + 1;
        totalBookingsGenerated += 1;
      }
    } catch (_) {}

    final sorted = [...list]..sort((a, b) {
        final scoreA = a.viewsCount * 3 + a.likesCount + a.savesCount + a.sharesCount * 2;
        final scoreB = b.viewsCount * 3 + b.likesCount + b.savesCount + b.sharesCount * 2;
        return scoreB.compareTo(scoreA);
      });

    final top = sorted.take(3).toList(growable: false);
    return BarberReelsOverview(
      totalViews: views,
      totalLikes: likes,
      totalSaves: saves,
      totalShares: shares,
      totalBookingsGenerated: totalBookingsGenerated,
      bookingsByReelId: bookingsByReelId,
      allReels: list,
      topReels: top,
    );
  } catch (e) {
    throw AppException('Failed to load reels overview', cause: e);
  }
});

final barberReelsViewsSeriesProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <int>[];
  final client = ref.watch(supabaseClientProvider);

  final start = DateTime.now().toUtc().subtract(const Duration(days: 6));
  final startIso = DateTime(start.year, start.month, start.day).toUtc().toIso8601String();
  try {
    final reelsRows = await client.from('reels').select('id').eq('barber_id', barber.id).isFilter('deleted_at', null).limit(800);
    final reelIds = (reelsRows as List).map((e) => (e as Map)['id'] as String?).whereType<String>().where((e) => e.isNotEmpty).toList(growable: false);
    if (reelIds.isEmpty) return const <int>[];

    final events = <Map<String, dynamic>>[];
    const chunkSize = 120;
    for (var i = 0; i < reelIds.length; i += chunkSize) {
      final chunk = reelIds.sublist(i, math.min(i + chunkSize, reelIds.length));
      final data = await client.from('reel_view_events').select('created_at, reel_id').inFilter('reel_id', chunk).gte('created_at', startIso).limit(5000);
      for (final raw in (data as List)) {
        events.add(Map<String, dynamic>.from(raw as Map));
      }
    }

    final counts = List<int>.filled(7, 0);
    for (final m in events) {
      final createdAt = DateTime.tryParse((m['created_at'] as String?) ?? '');
      if (createdAt == null) continue;
      final day = DateTime(createdAt.toUtc().year, createdAt.toUtc().month, createdAt.toUtc().day);
      final diff = day.difference(DateTime(start.year, start.month, start.day)).inDays;
      if (diff < 0 || diff > 6) continue;
      counts[diff] += 1;
    }
    return counts;
  } catch (_) {
    return const <int>[];
  }
});

class BarberReelsCenterTab extends ConsumerWidget {
  const BarberReelsCenterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Reels Center',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded),
                  color: AppTheme.text,
                ),
              ],
            ),
          ),
          TabBar(
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'My Reels'),
              Tab(text: 'Insights'),
              Tab(text: 'Drafts'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
                _MyReelsTab(),
                _InsightsTab(),
                _DraftsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(myBarberProvider);
    final overviewValue = ref.watch(barberReelsOverviewProvider);

    return AsyncValueWidget(
      value: barberValue,
      data: (barber) {
        if (barber == null) {
          return const Center(child: HallaqEmptyState(title: 'No barber profile', description: 'This account is not linked to a barber yet.', compact: true, showMascot: true));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            AsyncValueWidget(
              value: overviewValue,
              data: (o) {
                if (o == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MetricCard(label: 'Views', value: _formatCompact(o.totalViews), icon: Icons.visibility_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(label: 'Likes', value: _formatCompact(o.totalLikes), icon: Icons.favorite_border_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _MetricCard(label: 'Saves', value: _formatCompact(o.totalSaves), icon: Icons.bookmark_border_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(label: 'Shares', value: _formatCompact(o.totalShares), icon: Icons.ios_share_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _MetricCard(label: 'Bookings', value: _formatCompact(o.totalBookingsGenerated), icon: Icons.event_available_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(label: 'Top Reels', value: '${o.topReels.length}', icon: Icons.trending_up_rounded)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HallaqButton(label: 'Upload New Reel', onPressed: () => context.push(Routes.barberUploadReel), icon: Icons.add_rounded),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top Performing Reels',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        TextButton(onPressed: () => context.push(Routes.barberManageMyReels), child: const Text('View all')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (o.topReels.isEmpty)
                      const HallaqEmptyState(
                        title: 'No reels yet',
                        description: 'Upload your first reel to start getting views.',
                        compact: true,
                        showMascot: true,
                      )
                    else
                      ...o.topReels.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TopReelRow(
                            reel: r,
                            bookingsGenerated: o.bookingsByReelId[r.id] ?? 0,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reels That Generated Bookings',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (o.bookingsByReelId.isEmpty)
                      const HallaqEmptyState(
                        title: 'No booking reels yet',
                        description: 'Bookings generated from your reels will appear here.',
                        compact: true,
                        showMascot: true,
                      )
                    else
                      ...o.bookingsByReelId.entries
                          .where((e) => e.value > 0)
                          .toList(growable: false)
                          .take(8)
                          .map((e) {
                        final reel = listFirstWhere(o.allReels, (r) => r.id == e.key);
                        if (reel == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TopReelRow(reel: reel, bookingsGenerated: e.value),
                        );
                      }),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MyReelsTab extends ConsumerWidget {
  const _MyReelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myBarberReelsManageProvider);
    return AsyncValueWidget<List<Reel>>(
      value: value,
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: HallaqEmptyState(
              title: 'No reels yet',
              description: 'Upload a reel to start reaching more customers.',
              compact: true,
              showMascot: true,
            ),
          );
        }

        final published = items.where((e) => e.status == 'approved').toList(growable: false);
        final pending = items.where((e) => e.status == 'pending').toList(growable: false);
        final hidden = items.where((e) => e.status == 'hidden').toList(growable: false);

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Approved'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Hidden'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ReelsList(items: published),
                    _ReelsList(items: pending),
                    _ReelsList(items: hidden),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesValue = ref.watch(barberReelsViewsSeriesProvider);
    final overviewValue = ref.watch(barberReelsOverviewProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        Text('Views Analytics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        HallaqCard(
          glass: true,
          child: AsyncValueWidget<List<int>>(
            value: seriesValue,
            data: (values) {
              final points = values.isEmpty ? const <double>[] : values.map((e) => e.toDouble()).toList(growable: false);
              if (points.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No views data yet.'),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: LuxuryLineChart(values: points, height: 140),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Engagement', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        HallaqCard(
          glass: true,
          child: AsyncValueWidget(
            value: overviewValue,
            data: (o) {
              if (o == null) return const SizedBox.shrink();
              final total = math.max(1, o.totalLikes + o.totalSaves + o.totalShares);
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _DonutChart(
                      values: [
                        _DonutSlice(value: o.totalLikes / total, color: AppTheme.gold, label: 'Likes'),
                        _DonutSlice(value: o.totalSaves / total, color: AppTheme.goldSoft, label: 'Saves'),
                        _DonutSlice(value: o.totalShares / total, color: AppTheme.goldDeep, label: 'Shares'),
                      ],
                      centerText: _formatCompact(o.totalLikes + o.totalSaves + o.totalShares),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendRow(color: AppTheme.gold, label: 'Likes', value: _formatCompact(o.totalLikes)),
                          const SizedBox(height: 8),
                          _LegendRow(color: AppTheme.goldSoft, label: 'Saves', value: _formatCompact(o.totalSaves)),
                          const SizedBox(height: 8),
                          _LegendRow(color: AppTheme.goldDeep, label: 'Shares', value: _formatCompact(o.totalShares)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Bookings from Reels', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        HallaqCard(
          glass: true,
          child: AsyncValueWidget(
            value: overviewValue,
            data: (o) {
              if (o == null || o.bookingsByReelId.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No bookings attributed to reels yet.'),
                );
              }
              final entries = o.bookingsByReelId.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in entries.take(10))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text('Reel ${e.key.substring(0, 6)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                            Text('${e.value}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DraftsTab extends ConsumerWidget {
  const _DraftsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myBarberReelsDraftsProvider);
    return AsyncValueWidget<List<Reel>>(
      value: value,
      onRetry: () => ref.invalidate(myBarberReelsDraftsProvider),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: HallaqEmptyState(
              title: 'No drafts',
              description: 'Draft reels will appear here if you save them before publishing.',
              compact: true,
              showMascot: true,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: items
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DraftRow(reel: r),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.gold.withValues(alpha: 0.14),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopReelRow extends ConsumerWidget {
  final Reel reel;
  final int bookingsGenerated;

  const _TopReelRow({required this.reel, required this.bookingsGenerated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbPath = (reel.thumbnailPath ?? '').trim();
    final thumbUrl = (reel.thumbnailUrl ?? '').trim();
    final mediaPath = (reel.mediaPath ?? '').trim();
    final mediaUrl = reel.mediaUrl.trim();
    final thumb = thumbPath.isNotEmpty
        ? thumbPath
        : thumbUrl.isNotEmpty
            ? thumbUrl
            : reel.mediaType == 'image'
                ? (mediaPath.isNotEmpty ? mediaPath : mediaUrl)
                : '';
    final caption = (reel.caption ?? '').trim().isEmpty ? 'Reel' : (reel.caption ?? '').trim();
    final date = DateFormat('MMM d').format(reel.createdAt.toLocal());
    final meta =
        '${_formatCompact(reel.viewsCount)} views · ${_formatCompact(reel.likesCount)} likes · ${_formatCompact(reel.sharesCount)} shares · ${_formatCompact(bookingsGenerated)} bookings';

    return HallaqCard(
      glass: true,
      onTap: () => context.push(Routes.barberManageMyReels),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: LuxuryNetworkImage(
                imageUrl: thumb,
                fallbackUrl: '',
                bucket: 'reels',
                borderRadius: BorderRadius.zero,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _DraftRow extends ConsumerWidget {
  final Reel reel;

  const _DraftRow({required this.reel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbPath = (reel.thumbnailPath ?? '').trim();
    final thumbUrl = (reel.thumbnailUrl ?? '').trim();
    final mediaPath = (reel.mediaPath ?? '').trim();
    final mediaUrl = reel.mediaUrl.trim();
    final thumb = thumbPath.isNotEmpty
        ? thumbPath
        : thumbUrl.isNotEmpty
            ? thumbUrl
            : reel.mediaType == 'image'
                ? (mediaPath.isNotEmpty ? mediaPath : mediaUrl)
                : '';
    final caption = (reel.caption ?? '').trim().isEmpty ? 'Draft' : (reel.caption ?? '').trim();
    final date = DateFormat('MMM d, yyyy').format(reel.createdAt.toLocal());

    Future<void> open() async {
      context.push('${Routes.barberUploadReel}?draftId=${reel.id}');
    }

    Future<void> remove() async {
      await ref.read(barberReelControllerProvider.notifier).deleteDraft(reel.id);
    }

    return HallaqCard(
      glass: true,
      onTap: open,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: LuxuryNetworkImage(
                imageUrl: thumb,
                fallbackUrl: '',
                bucket: 'reels',
                borderRadius: BorderRadius.zero,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
          IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

T? listFirstWhere<T>(Iterable<T> items, bool Function(T) test) {
  for (final i in items) {
    if (test(i)) return i;
  }
  return null;
}

class _ReelsList extends ConsumerWidget {
  final List<Reel> items;

  const _ReelsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No reels here',
          description: 'Nothing to show in this section yet.',
          compact: true,
          showMascot: true,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: items.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ManageReelRow(reel: r))).toList(),
    );
  }
}

class _ManageReelRow extends ConsumerWidget {
  final Reel reel;

  const _ManageReelRow({required this.reel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbPath = (reel.thumbnailPath ?? '').trim();
    final thumbUrl = (reel.thumbnailUrl ?? '').trim();
    final mediaPath = (reel.mediaPath ?? '').trim();
    final mediaUrl = reel.mediaUrl.trim();
    final thumb = thumbPath.isNotEmpty
        ? thumbPath
        : thumbUrl.isNotEmpty
            ? thumbUrl
            : reel.mediaType == 'image'
                ? (mediaPath.isNotEmpty ? mediaPath : mediaUrl)
                : '';
    final caption = (reel.caption ?? '').trim().isEmpty ? 'Reel' : (reel.caption ?? '').trim();
    final date = DateFormat('MMM d, yyyy').format(reel.createdAt.toLocal());
    final meta = '${_formatCompact(reel.viewsCount)} views · ${_formatCompact(reel.likesCount)} likes · ${_formatCompact(reel.savesCount)} saves';

    Future<void> edit() async {
      await context.push(Routes.barberManageMyReels);
    }

    Future<void> remove() async {
      await ref.read(reelsRepositoryProvider).softDelete(reel.id);
      ref.invalidate(myBarberReelsManageProvider);
    }

    return HallaqCard(
      glass: true,
      onTap: edit,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 74,
              height: 74,
              child: LuxuryNetworkImage(
                imageUrl: thumb,
                fallbackUrl: '',
                bucket: 'reels',
                borderRadius: BorderRadius.zero,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
          IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

String _formatCompact(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted))),
        Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _DonutSlice {
  final double value;
  final Color color;
  final String label;

  const _DonutSlice({required this.value, required this.color, required this.label});
}

class _DonutChart extends StatelessWidget {
  final List<_DonutSlice> values;
  final String centerText;

  const _DonutChart({required this.values, required this.centerText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(painter: _DonutPainter(values: values)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerText, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('Total', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> values;

  const _DonutPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.22;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppTheme.border.withValues(alpha: 0.85);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - stroke), 0, math.pi * 2, false, bg);

    var start = -math.pi / 2;
    for (final v in values) {
      final sweep = (v.value.clamp(0, 1)) * math.pi * 2;
      if (sweep <= 0) continue;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = v.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - stroke), start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i].value != values[i].value) return true;
      if (oldDelegate.values[i].color != values[i].color) return true;
    }
    return false;
  }
}
