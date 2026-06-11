import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_availability_repository.dart';
import '../../booking/presentation/widgets/booking_cancel_reason_sheet.dart';
import '../data/shop_dashboard_repository.dart';

final _shopUpcomingBookingsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listBookings(upcoming: true);
});

final _shopPastBookingsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listBookings(upcoming: false);
});

class ShopManageBookingsScreen extends ConsumerWidget {
  const ShopManageBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(_shopUpcomingBookingsListProvider);
    final past = ref.watch(_shopPastBookingsListProvider);

    Future<void> setStatus(String bookingId, String status) async {
      try {
        String? cancelReason;
        if (status == 'cancelled') {
          cancelReason = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const BookingCancelReasonSheet(),
          );
          if (cancelReason == null || !context.mounted) return;
        }
        await ref.read(shopDashboardRepositoryProvider).updateBookingStatus(bookingId: bookingId, status: status, cancelReason: cancelReason);
        ref.invalidate(_shopUpcomingBookingsListProvider);
        ref.invalidate(_shopPastBookingsListProvider);
        ref.invalidate(shopDashboardUpcomingBookingsProvider);
        ref.invalidate(shopDashboardStatsProvider);
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    Future<void> reschedule(Map<String, dynamic> row) async {
      final bookingId = row['id'] as String;
      final barber = row['barbers'] as Map?;
      final barberId = (barber?['id'] as String?)?.trim();
      if (barberId == null || barberId.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot reschedule: missing barber.')));
        return;
      }

      final service = row['services'] as Map?;
      final durationMinutes = ((service?['duration_minutes'] as num?)?.toInt() ?? 30).clamp(10, 360);

      final selectedDate = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        initialDate: DateTime.now(),
      );
      if (selectedDate == null || !context.mounted) return;

      final starts = await ref.read(barberAvailabilityRepositoryProvider).listAvailableStartsForDay(
            barberId: barberId,
            day: selectedDate,
            durationMinutes: durationMinutes,
          );

      if (!context.mounted) return;
      if (starts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available slots for this day.')));
        return;
      }

      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: HallaqCard(
                glass: true,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select a time', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: starts
                            .take(24)
                            .map(
                              (dt) => _TimeChip(
                                label: DateFormat('h:mm a').format(dt),
                                onTap: () => Navigator.of(context).pop(dt),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (picked == null || !context.mounted) return;

      try {
        await ref.read(shopDashboardRepositoryProvider).rescheduleBooking(bookingId: bookingId, newStartAt: picked);
        ref.invalidate(_shopUpcomingBookingsListProvider);
        ref.invalidate(_shopPastBookingsListProvider);
        ref.invalidate(shopDashboardUpcomingBookingsProvider);
        ref.invalidate(shopDashboardStatsProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Bookings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')]),
            Expanded(
              child: TabBarView(
                children: [
                  AsyncValueWidget<List<Map<String, dynamic>>>(
                    value: upcoming,
                    onRetry: () => ref.invalidate(_shopUpcomingBookingsListProvider),
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
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        children: rows.map((r) => _BookingRow(row: r, onSetStatus: setStatus, onReschedule: reschedule)).toList(),
                      );
                    },
                  ),
                  AsyncValueWidget<List<Map<String, dynamic>>>(
                    value: past,
                    onRetry: () => ref.invalidate(_shopPastBookingsListProvider),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return const Center(
                          child: HallaqEmptyState(
                            title: 'No past bookings',
                            description: 'Completed and cancelled bookings will appear here.',
                            compact: true,
                            showMascot: true,
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        children: rows.map((r) => _BookingRow(row: r, onSetStatus: setStatus, onReschedule: reschedule)).toList(),
                      );
                    },
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

class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<void> Function(String bookingId, String status) onSetStatus;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;

  const _BookingRow({required this.row, required this.onSetStatus, required this.onReschedule});

  @override
  Widget build(BuildContext context) {
    final id = row['id'] as String;
    final start = DateTime.tryParse(row['start_at'] as String? ?? '')?.toLocal();
    final status = (row['status'] as String?) ?? 'pending';
    final profiles = row['profiles'] as Map?;
    final customerName = (profiles?['full_name'] as String?) ?? 'Customer';
    final barber = row['barbers'] as Map?;
    final barberName = (barber?['display_name'] as String?) ?? '';
    final customerProfileId = (row['customer_profile_id'] as String?)?.trim();
    final cancelledBy = (row['cancelled_by_profile_id'] as String?)?.trim();
    final cancelReason = ((row['cancelled_reason'] as String?) ?? (row['cancel_reason'] as String?))?.trim();
    final barberProfileId = (barber?['profile_id'] as String?)?.trim();

    final cancelByLabel = () {
      final by = (cancelledBy ?? '').trim();
      if (by.isEmpty) return 'Cancelled';
      if ((customerProfileId ?? '').isNotEmpty && by == customerProfileId) return 'Cancelled by Client';
      if ((barberProfileId ?? '').isNotEmpty && by == barberProfileId) return 'Cancelled by Barber';
      return 'Cancelled by Shop';
    }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customerName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              '${start == null ? '' : start.toString().substring(0, 16)} • $status${barberName.isEmpty ? '' : ' • $barberName'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            if (status == 'cancelled') ...[
              const SizedBox(height: 6),
              Text(
                cancelByLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error, fontWeight: FontWeight.w900),
              ),
              if ((cancelReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  cancelReason!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                ),
              ],
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: status == 'confirmed' ? null : () => onSetStatus(id, 'confirmed'), child: const Text('Accept'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: status == 'cancelled' ? null : () => onSetStatus(id, 'cancelled'), child: const Text('Reject'))),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: (status == 'pending' || status == 'confirmed') ? () => onReschedule(row) : null,
              child: const Text('Reschedule'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: status == 'completed' ? null : () => onSetStatus(id, 'completed'), child: const Text('Mark completed')),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
