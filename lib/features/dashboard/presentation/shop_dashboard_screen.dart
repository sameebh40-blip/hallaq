import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/routing/routes.dart';
import '../data/shop_dashboard_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Shop dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        trailing: LuxuryIconButton(
          icon: Icons.shopping_bag_rounded,
          onPressed: () => context.push(Routes.shopManageProducts),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: const [_DashboardBody()],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(shopDashboardStatsProvider);
    final upcoming = ref.watch(shopDashboardUpcomingBookingsProvider);
    final orders = ref.watch(shopDashboardOrdersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HallaqCard(
          glass: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Manage', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _ActionTile(title: 'Shop profile', onTap: () => context.push(Routes.shopManageProfile)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Gallery', onTap: () => context.push(Routes.shopManageGallery)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Barbers', onTap: () => context.push(Routes.shopManageBarbers)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Bookings', onTap: () => context.push(Routes.shopManageBookings)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Services', onTap: () => context.push(Routes.shopManageServices)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Products', onTap: () => context.push(Routes.shopManageProducts)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Reels', onTap: () => context.push(Routes.shopManageReels)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Offers', onTap: () => context.push(Routes.shopManageOffers)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Analytics', onTap: () => context.push(Routes.shopManageAnalytics)),
              const SizedBox(height: 10),
              _ActionTile(title: 'Settings', onTap: () => context.push(Routes.shopManageSettings)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AsyncValueWidget(
          value: stats,
          onRetry: () => ref.invalidate(shopDashboardStatsProvider),
          data: (s) {
            if (s == null) {
              return const HallaqCard(glass: true, child: Text('No shop assigned to this account.'));
            }
            return Column(
              children: [
                _StatCard(title: 'Revenue (30d)', value: '${s.revenueBhd30d.toStringAsFixed(0)} BHD'),
                const SizedBox(height: 12),
                _StatCard(title: 'Today bookings', value: '${s.todayBookings}'),
                const SizedBox(height: 12),
                _StatCard(title: 'Upcoming', value: '${s.upcomingBookings}'),
                const SizedBox(height: 12),
                _StatCard(title: 'Posts', value: '${s.posts}'),
                const SizedBox(height: 12),
                _StatCard(title: 'Reviews', value: '${s.reviews}'),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Upcoming bookings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        AsyncValueWidget(
          value: upcoming,
          onRetry: () => ref.invalidate(shopDashboardUpcomingBookingsProvider),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(
                child: HallaqEmptyState(
                  title: 'No upcoming bookings',
                  description: 'New requests and upcoming bookings will appear here.',
                  compact: true,
                  showMascot: true,
                ),
              );
            }
            return Column(
              children: rows.map((r) => _BookingRow(row: r)).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        AsyncValueWidget(
          value: orders,
          onRetry: () => ref.invalidate(shopDashboardOrdersProvider),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(
                child: HallaqEmptyState(
                  title: 'No orders',
                  description: 'Orders will appear here once customers purchase products.',
                  compact: true,
                  showMascot: true,
                ),
              );
            }
            return Column(
              children: rows.map((r) => _OrderRow(row: r)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ActionTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends ConsumerWidget {
  final Map<String, dynamic> row;

  const _BookingRow({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shopDashboardRepositoryProvider);
    final startAtRaw = row['start_at'] as String?;
    final startAt = startAtRaw != null ? DateTime.tryParse(startAtRaw)?.toLocal() : null;
    final status = (row['status'] as String?) ?? 'pending';
    final profiles = row['profiles'] as Map?;
    final name = (profiles?['full_name'] as String?) ?? 'Customer';

    Future<void> set(String s) async {
      try {
        await repo.updateBookingStatus(bookingId: row['id'] as String, status: s);
        ref.invalidate(shopDashboardStatsProvider);
        ref.invalidate(shopDashboardUpcomingBookingsProvider);
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              '${startAt != null ? '${startAt.year}-${startAt.month.toString().padLeft(2, '0')}-${startAt.day.toString().padLeft(2, '0')} ${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}' : '—'} • $status',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'confirmed' ? null : () => set('confirmed'),
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'completed' ? null : () => set('completed'),
                    child: const Text('Complete'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'cancelled' ? null : () => set('cancelled'),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  final Map<String, dynamic> row;

  const _OrderRow({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shopDashboardRepositoryProvider);
    final status = (row['status'] as String?) ?? 'pending';
    final profiles = row['profiles'] as Map?;
    final name = (profiles?['full_name'] as String?) ?? 'Customer';
    final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
    final currency = (row['currency'] as String?) ?? 'BHD';

    Future<void> set(String s) async {
      await repo.updateOrderStatus(orderId: row['id'] as String, status: s);
      ref.invalidate(shopDashboardOrdersProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: () => context.push('${Routes.shopOrderDetails}/${row['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              '$status • ${total.toStringAsFixed(3)} $currency',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'accepted' ? null : () => set('accepted'),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'rejected' ? null : () => set('rejected'),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'shipped' ? null : () => set('shipped'),
                    child: const Text('Shipped'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'delivered' ? null : () => set('delivered'),
                    child: const Text('Delivered'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
