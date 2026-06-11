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
import '../../barber/data/barber_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../data/barber_dashboard_repository.dart';

class BarberManageAppointmentsScreen extends ConsumerWidget {
  final bool showBack;

  const BarberManageAppointmentsScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setStatus(String bookingId, String status) async {
      try {
        await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: bookingId, status: status);
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('pending'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('confirmed'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('completed'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('cancelled'));
        ref.invalidate(barberDashboardStatsProvider);
        ref.invalidate(barberDashboardUpcomingAppointmentsProvider);
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    Future<void> reschedule(Map<String, dynamic> row) async {
      final barber = await ref.read(myBarberProvider.future);
      if (barber == null) return;
      if (!context.mounted) return;
      final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
      final durationMinutes = ((service?['duration_minutes'] as num?)?.toInt() ?? 30).clamp(10, 360);

      final selectedDate = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        initialDate: DateTime.now(),
      );
      if (selectedDate == null || !context.mounted) return;

      final starts = await ref.read(barberAvailabilityRepositoryProvider).listAvailableStartsForDay(
            barberId: barber.id,
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
        await ref.read(bookingRepositoryProvider).rescheduleBooking(bookingId: row['id'] as String, newStartAt: picked);
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('pending'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('confirmed'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('completed'));
        ref.invalidate(myBarberBookingsDetailedByStatusProvider('cancelled'));
        ref.invalidate(barberDashboardStatsProvider);
        ref.invalidate(barberDashboardUpcomingAppointmentsProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    return LuxuryScaffold(
      header: showBack
          ? LuxuryTopBar(
              leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
              title: Text('Appointments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            )
          : null,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Accepted'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BookingsTab(
                    value: ref.watch(myBarberBookingsDetailedByStatusProvider('pending')),
                    emptyTitle: 'No pending requests',
                    emptyDescription: 'New booking requests will appear here.',
                    onSetStatus: setStatus,
                    onReschedule: reschedule,
                    onRetry: () => ref.invalidate(myBarberBookingsDetailedByStatusProvider('pending')),
                  ),
                  _BookingsTab(
                    value: ref.watch(myBarberBookingsDetailedByStatusProvider('confirmed')),
                    emptyTitle: 'No accepted bookings',
                    emptyDescription: 'Accepted bookings will appear here.',
                    onSetStatus: setStatus,
                    onReschedule: reschedule,
                    onRetry: () => ref.invalidate(myBarberBookingsDetailedByStatusProvider('confirmed')),
                  ),
                  _BookingsTab(
                    value: ref.watch(myBarberBookingsDetailedByStatusProvider('completed')),
                    emptyTitle: 'No completed bookings',
                    emptyDescription: 'Completed bookings will appear here.',
                    onSetStatus: setStatus,
                    onReschedule: reschedule,
                    onRetry: () => ref.invalidate(myBarberBookingsDetailedByStatusProvider('completed')),
                  ),
                  _BookingsTab(
                    value: ref.watch(myBarberBookingsDetailedByStatusProvider('cancelled')),
                    emptyTitle: 'No cancelled bookings',
                    emptyDescription: 'Cancelled bookings will appear here.',
                    onSetStatus: setStatus,
                    onReschedule: reschedule,
                    onRetry: () => ref.invalidate(myBarberBookingsDetailedByStatusProvider('cancelled')),
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

class _BookingsTab extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> value;
  final String emptyTitle;
  final String emptyDescription;
  final Future<void> Function(String bookingId, String status) onSetStatus;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;
  final VoidCallback onRetry;

  const _BookingsTab({
    required this.value,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onSetStatus,
    required this.onReschedule,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<Map<String, dynamic>>>(
      value: value,
      onRetry: onRetry,
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: HallaqEmptyState(
              title: emptyTitle,
              description: emptyDescription,
              compact: true,
              showMascot: true,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: items.map((row) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _BookingCard(row: row, onSetStatus: onSetStatus, onReschedule: onReschedule))).toList(),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<void> Function(String bookingId, String status) onSetStatus;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;

  const _BookingCard({required this.row, required this.onSetStatus, required this.onReschedule});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(row['start_at'] as String).toLocal();
    final end = DateTime.parse(row['end_at'] as String).toLocal();
    final status = (row['status'] as String?) ?? 'pending';

    final customer = (row['profiles'] as Map?) == null ? null : Map<String, dynamic>.from(row['profiles'] as Map);
    final customerName = (customer?['full_name'] as String?) ?? 'Customer';
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = (service?['name_en'] as String?) ?? (service?['name'] as String?) ?? 'Service';
    final total = (row['total_price'] as num?)?.toDouble();
    final price = total ?? ((service?['price_bhd'] as num?)?.toDouble() ?? 0);

    final dt = DateFormat('EEE, MMM d').format(start);
    final time = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HallaqAvatar(imageUrl: customer?['avatar_url'] as String?, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('BD ${price.toStringAsFixed(3)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('$dt · $time', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted))),
              Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'pending' ? () => onSetStatus(row['id'] as String, 'confirmed') : null,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.goldDeep),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'pending' ? () => onSetStatus(row['id'] as String, 'cancelled') : null,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: (status == 'pending' || status == 'confirmed') ? () => onReschedule(row) : null,
            child: const Text('Reschedule'),
          ),
          if (status == 'confirmed') ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => onSetStatus(row['id'] as String, 'completed'),
              child: const Text('Mark completed'),
            ),
          ],
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
