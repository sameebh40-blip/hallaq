import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/booking/data/booking_repository.dart';
import '../../features/bookings/presentation/my_bookings_controller.dart';
import '../../features/bookings/models/my_booking_card.dart';
import '../../features/dashboard/data/admin_dashboard_repository.dart';
import '../../features/dashboard/data/barber_dashboard_repository.dart';
import '../../features/dashboard/data/shop_dashboard_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/trending/data/trending_repository.dart';
import '../supabase/supabase_client_provider.dart';

final realtimeBootstrapProvider = Provider.autoDispose<void>((ref) {
  ref.watch(authStateChangesProvider);

  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return;

  final channels = <RealtimeChannel>[];
  final debouncer = _Debouncer();

  void invalidateBookings() {
    ref.invalidate(myUpcomingBookingsProvider);
    ref.invalidate(myPastBookingsProvider);
    ref.invalidate(myLastCompletedBookingForBarberProvider);
    ref.invalidate(myBookingsControllerProvider(BookingsTab.upcoming));
    ref.invalidate(myBookingsControllerProvider(BookingsTab.completed));
    ref.invalidate(myBookingsControllerProvider(BookingsTab.cancelled));
    ref.invalidate(myBarberBookingsDetailedByStatusProvider('pending'));
    ref.invalidate(myBarberBookingsDetailedByStatusProvider('confirmed'));
    ref.invalidate(myBarberBookingsDetailedByStatusProvider('completed'));
    ref.invalidate(myBarberBookingsDetailedByStatusProvider('cancelled'));
    ref.invalidate(barberDashboardStatsProvider);
    ref.invalidate(barberDashboardUpcomingAppointmentsProvider);
    ref.invalidate(shopDashboardStatsProvider);
    ref.invalidate(shopDashboardUpcomingBookingsProvider);
    ref.invalidate(shopBookingsByStatusProvider('all'));
    ref.invalidate(shopBookingsByStatusProvider('pending'));
    ref.invalidate(shopBookingsByStatusProvider('confirmed'));
    ref.invalidate(shopBookingsByStatusProvider('in_progress'));
    ref.invalidate(shopBookingsByStatusProvider('completed'));
    ref.invalidate(shopBookingsByStatusProvider('cancelled'));
    ref.invalidate(shopBookingsByStatusProvider('rescheduled'));
    ref.invalidate(shopBookingsByStatusProvider('no_show'));
    ref.invalidate(adminStatsProvider);
    ref.invalidate(trendingThisWeekProvider);
    ref.invalidate(barberPublicStatsProvider);
  }

  void invalidateCatalog() {
    ref.invalidate(trendingThisWeekProvider);
    ref.invalidate(barberPublicStatsProvider);
  }

  void invalidateNotifications() {
    ref.invalidate(myNotificationsProvider);
  }

  final bookingsChannel = client
      .channel('rt_bookings_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        callback: (_) => debouncer.run('bookings', invalidateBookings),
      )
      .subscribe();
  channels.add(bookingsChannel);

  final paymentsChannel = client
      .channel('rt_payments_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'payments',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'payer_profile_id', value: user.id),
        callback: (_) => debouncer.run('bookings', invalidateBookings),
      )
      .subscribe();
  channels.add(paymentsChannel);

  final followsChannel = client
      .channel('rt_follows_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'profile_id', value: user.id),
        callback: (_) => debouncer.run('catalog', invalidateCatalog),
      )
      .subscribe();
  channels.add(followsChannel);

  final notificationsChannel = client
      .channel('rt_notifications_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: user.id,
        ),
        callback: (_) => invalidateNotifications(),
      )
      .subscribe();
  channels.add(notificationsChannel);

  ref.onDispose(() {
    debouncer.dispose();
    for (final ch in channels) {
      client.removeChannel(ch);
    }
  });
});

class _Debouncer {
  final Map<String, Timer> _timers = {};

  void run(String key, void Function() action, {Duration delay = const Duration(milliseconds: 350)}) {
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(delay, action);
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
