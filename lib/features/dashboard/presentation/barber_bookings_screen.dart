import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../barber/data/barber_availability_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/presentation/widgets/booking_cancel_reason_sheet.dart';
import '../data/barber_dashboard_repository.dart';

class BarberBookingsScreen extends ConsumerWidget {
  const BarberBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberProfileId = ref.watch(myBarberProvider).maybeWhen(data: (b) => b?.profileId, orElse: () => null);

    String digitsOnly(String input) {
      final s = input.trim();
      if (s.isEmpty) return '';
      return s.replaceAll(RegExp(r'[^0-9+]'), '');
    }

    Future<void> launchTel(String phone) async {
      final cleaned = digitsOnly(phone);
      if (cleaned.isEmpty) return;
      final uri = Uri(scheme: 'tel', path: cleaned);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> launchWhatsApp(String phone) async {
      final cleaned = digitsOnly(phone).replaceAll('+', '');
      if (cleaned.isEmpty) return;
      final uri = Uri.parse('https://wa.me/$cleaned');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> refreshAll() async {
      ref.invalidate(myBarberUpcomingBookingsDetailedProvider);
      ref.invalidate(myBarberCompletedBookingsDetailedProvider);
      ref.invalidate(myBarberCancelledBookingsDetailedProvider);
      ref.invalidate(barberDashboardStatsProvider);
      ref.invalidate(barberDashboardUpcomingAppointmentsProvider);
    }

    Future<void> cancelBooking(String bookingId) async {
      final reason = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const BookingCancelReasonSheet(),
      );
      if (reason == null) return;
      try {
        await ref.read(bookingRepositoryProvider).cancelBooking(bookingId, reason: reason);
        await refreshAll();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    Future<void> setStatus(String bookingId, String status) async {
      try {
        await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: bookingId, status: status);
        await refreshAll();
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
                            .take(28)
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
        await refreshAll();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bookings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: refreshAll, icon: const Icon(Icons.refresh_rounded), color: AppTheme.text),
              ],
            ),
          ),
          TabBar(
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BookingsList(
                  value: ref.watch(myBarberUpcomingBookingsDetailedProvider),
                  emptyTitle: 'No upcoming bookings',
                  emptyDescription: 'Upcoming bookings will appear here.',
                  barberProfileId: barberProfileId,
                  onCancel: cancelBooking,
                  onReschedule: reschedule,
                  onStart: (id) => setStatus(id, 'in_progress'),
                  onMarkDone: (id) => setStatus(id, 'completed'),
                  onCall: launchTel,
                  onWhatsApp: launchWhatsApp,
                  onRetry: () => ref.invalidate(myBarberUpcomingBookingsDetailedProvider),
                ),
                _BookingsList(
                  value: ref.watch(myBarberCompletedBookingsDetailedProvider),
                  emptyTitle: 'No completed bookings',
                  emptyDescription: 'Completed bookings will appear here.',
                  barberProfileId: barberProfileId,
                  onCancel: cancelBooking,
                  onReschedule: reschedule,
                  onStart: (id) => setStatus(id, 'in_progress'),
                  onMarkDone: (id) => setStatus(id, 'completed'),
                  onCall: launchTel,
                  onWhatsApp: launchWhatsApp,
                  onRetry: () => ref.invalidate(myBarberCompletedBookingsDetailedProvider),
                ),
                _BookingsList(
                  value: ref.watch(myBarberCancelledBookingsDetailedProvider),
                  emptyTitle: 'No cancelled bookings',
                  emptyDescription: 'Cancelled bookings will appear here.',
                  barberProfileId: barberProfileId,
                  onCancel: cancelBooking,
                  onReschedule: reschedule,
                  onStart: (id) => setStatus(id, 'in_progress'),
                  onMarkDone: (id) => setStatus(id, 'completed'),
                  onCall: launchTel,
                  onWhatsApp: launchWhatsApp,
                  onRetry: () => ref.invalidate(myBarberCancelledBookingsDetailedProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> value;
  final String emptyTitle;
  final String emptyDescription;
  final String? barberProfileId;
  final Future<void> Function(String bookingId) onCancel;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;
  final Future<void> Function(String bookingId) onStart;
  final Future<void> Function(String bookingId) onMarkDone;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;
  final VoidCallback onRetry;

  const _BookingsList({
    required this.value,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.barberProfileId,
    required this.onCancel,
    required this.onReschedule,
    required this.onStart,
    required this.onMarkDone,
    required this.onCall,
    required this.onWhatsApp,
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
          children: items
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingCard(
                    row: row,
                    barberProfileId: barberProfileId,
                    onCancel: onCancel,
                    onReschedule: onReschedule,
                    onStart: onStart,
                    onMarkDone: onMarkDone,
                    onCall: onCall,
                    onWhatsApp: onWhatsApp,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String? barberProfileId;
  final Future<void> Function(String bookingId) onCancel;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;
  final Future<void> Function(String bookingId) onStart;
  final Future<void> Function(String bookingId) onMarkDone;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;

  const _BookingCard({
    required this.row,
    required this.barberProfileId,
    required this.onCancel,
    required this.onReschedule,
    required this.onStart,
    required this.onMarkDone,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(row['start_at'] as String).toLocal();
    final end = DateTime.parse(row['end_at'] as String).toLocal();
    final status = (row['status'] as String?) ?? 'confirmed';

    final customer = (row['profiles'] as Map?) == null ? null : Map<String, dynamic>.from(row['profiles'] as Map);
    final customerName = (customer?['full_name'] as String?) ?? 'Customer';
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = (service?['name_en'] as String?) ?? (service?['name'] as String?) ?? 'Service';
    final total = (row['total_price'] as num?)?.toDouble();
    final price = total ?? ((service?['price_bhd'] as num?)?.toDouble() ?? 0);
    final durationMinutes = ((row['duration_minutes'] as num?)?.toInt()) ?? end.difference(start).inMinutes;
    final shop = (row['barbershops'] as Map?) == null ? null : Map<String, dynamic>.from(row['barbershops'] as Map);
    final shopName = (shop?['name'] as String?)?.trim();
    final phone = (customer?['phone'] as String?)?.trim();
    final cancelledBy = (row['cancelled_by_profile_id'] as String?)?.trim();
    final cancelReason = (row['cancel_reason'] as String?)?.trim();
    final shopOwnerProfileId = (shop?['owner_profile_id'] as String?)?.trim();
    final customerProfileId = (row['customer_profile_id'] as String?)?.trim();

    final cancelByLabel = () {
      final by = (cancelledBy ?? '').trim();
      if (by.isEmpty) return 'Cancelled';
      if ((barberProfileId ?? '').trim().isNotEmpty && by == barberProfileId) return 'Cancelled by You';
      if ((customerProfileId ?? '').isNotEmpty && by == customerProfileId) return 'Cancelled by Client';
      if ((shopOwnerProfileId ?? '').isNotEmpty && by == shopOwnerProfileId) return 'Cancelled by Shop';
      return 'Cancelled';
    }();

    final dt = DateFormat('EEE, MMM d').format(start);
    final time = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    final canChange = (status == 'confirmed' || status == 'pending' || status == 'rescheduled') && start.isAfter(DateTime.now());
    final canCancel = (status == 'confirmed' || status == 'pending' || status == 'rescheduled') && start.isAfter(DateTime.now());
    final canStart = (status == 'confirmed' || status == 'rescheduled') &&
        DateTime.now().isAfter(start.subtract(const Duration(minutes: 20))) &&
        DateTime.now().isBefore(end);

    Future<void> view() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _BookingDetailsSheet(
          row: row,
          onCancel: onCancel,
          onReschedule: onReschedule,
          onStart: onStart,
          onMarkDone: onMarkDone,
          onCall: onCall,
          onWhatsApp: onWhatsApp,
        ),
      );
    }

    return HallaqCard(
      glass: true,
      onTap: view,
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
              Expanded(
                child: Text(
                  '$dt · $time${durationMinutes > 0 ? ' · ${durationMinutes}m' : ''}${(shopName ?? '').isNotEmpty ? ' · $shopName' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'cancelled') ...[
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
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (phone == null || phone.isEmpty) ? null : () => onCall(phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (phone == null || phone.isEmpty) ? null : () => onWhatsApp(phone),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (status == 'in_progress')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: view,
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('Continue'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HallaqButton(
                    label: 'Mark Done',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () => onMarkDone(row['id'] as String),
                  ),
                ),
              ],
            )
          else if (canStart)
            HallaqButton(label: 'Start', icon: Icons.play_arrow_rounded, onPressed: () => onStart(row['id'] as String))
          else
            OutlinedButton(onPressed: view, child: const Text('View')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canChange ? () => onReschedule(row) : null,
                  child: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: canCancel ? () => onCancel(row['id'] as String) : null,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _BookingDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<void> Function(String bookingId) onCancel;
  final Future<void> Function(Map<String, dynamic> row) onReschedule;
  final Future<void> Function(String bookingId) onStart;
  final Future<void> Function(String bookingId) onMarkDone;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;

  const _BookingDetailsSheet({
    required this.row,
    required this.onCancel,
    required this.onReschedule,
    required this.onStart,
    required this.onMarkDone,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(row['start_at'] as String).toLocal();
    final end = DateTime.parse(row['end_at'] as String).toLocal();
    final status = (row['status'] as String?) ?? 'confirmed';

    final customer = (row['profiles'] as Map?) == null ? null : Map<String, dynamic>.from(row['profiles'] as Map);
    final customerName = (customer?['full_name'] as String?) ?? 'Customer';
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = (service?['name_en'] as String?) ?? (service?['name'] as String?) ?? 'Service';
    final total = (row['total_price'] as num?)?.toDouble();
    final price = total ?? ((service?['price_bhd'] as num?)?.toDouble() ?? 0);
    final durationMinutes = ((row['duration_minutes'] as num?)?.toInt()) ?? end.difference(start).inMinutes;
    final shop = (row['barbershops'] as Map?) == null ? null : Map<String, dynamic>.from(row['barbershops'] as Map);
    final shopName = (shop?['name'] as String?)?.trim();
    final phone = (customer?['phone'] as String?)?.trim();

    final canChange = (status == 'confirmed' || status == 'pending' || status == 'rescheduled') && start.isAfter(DateTime.now());
    final canCancel = (status == 'confirmed' || status == 'pending' || status == 'rescheduled') && start.isAfter(DateTime.now());
    final canStart = (status == 'confirmed' || status == 'rescheduled') &&
        DateTime.now().isAfter(start.subtract(const Duration(minutes: 20))) &&
        DateTime.now().isBefore(end);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Booking Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: false,
                child: Row(
                  children: [
                    HallaqAvatar(imageUrl: customer?['avatar_url'] as String?, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customerName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(serviceName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Text('BD ${price.toStringAsFixed(3)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(DateFormat('EEE, MMM d, yyyy').format(start), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}${durationMinutes > 0 ? ' · ${durationMinutes}m' : ''}${(shopName ?? '').isNotEmpty ? ' · $shopName' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (phone == null || phone.isEmpty) ? null : () => onCall(phone),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (phone == null || phone.isEmpty) ? null : () => onWhatsApp(phone),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (status == 'in_progress')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                        label: const Text('Continue'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: HallaqButton(
                        label: 'Mark Done',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () => onMarkDone(row['id'] as String),
                      ),
                    ),
                  ],
                )
              else if (canStart)
                HallaqButton(label: 'Start', icon: Icons.play_arrow_rounded, onPressed: () => onStart(row['id'] as String))
              else
                const SizedBox.shrink(),
              if (status == 'in_progress' || canStart) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canChange ? () => onReschedule(row) : null,
                      child: const Text('Reschedule'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canCancel ? () => onCancel(row['id'] as String) : null,
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                      child: const Text('Cancel booking'),
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

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim();
    final (label, color) = switch (s) {
      'pending' => ('Pending', AppTheme.gold),
      'confirmed' => ('Confirmed', AppTheme.success),
      'in_progress' => ('In progress', AppTheme.gold),
      'rescheduled' => ('Rescheduled', AppTheme.gold),
      'completed' => ('Completed', AppTheme.success),
      'cancelled' => ('Cancelled', AppTheme.error),
      'no_show' => ('No-show', AppTheme.error),
      _ => (s.isEmpty ? 'Status' : s, AppTheme.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: color)),
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
