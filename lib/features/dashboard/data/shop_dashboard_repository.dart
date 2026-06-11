import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ShopDashboardStats {
  final String shopId;
  final int todayBookings;
  final int upcomingBookings;
  final int posts;
  final int reviews;
  final double revenueBhd30d;

  const ShopDashboardStats({
    required this.shopId,
    required this.todayBookings,
    required this.upcomingBookings,
    required this.posts,
    required this.reviews,
    required this.revenueBhd30d,
  });
}

class ShopTodayOverview {
  final int bookings;
  final double revenueBhd;
  final int customers;
  final int pendingOrders;

  const ShopTodayOverview({
    required this.bookings,
    required this.revenueBhd,
    required this.customers,
    required this.pendingOrders,
  });
}

class ShopOverviewWithChange {
  final int todayBookings;
  final double todayBookingsChangePct;
  final double todayBookingsVs;
  final double revenueTodayBhd;
  final double revenueTodayChangePct;
  final double revenueTodayVs;
  final int newCustomers;
  final double newCustomersChangePct;
  final double newCustomersVs;
  final int pendingApprovals;
  final double pendingApprovalsChangePct;
  final double pendingApprovalsVs;

  const ShopOverviewWithChange({
    required this.todayBookings,
    required this.todayBookingsChangePct,
    required this.todayBookingsVs,
    required this.revenueTodayBhd,
    required this.revenueTodayChangePct,
    required this.revenueTodayVs,
    required this.newCustomers,
    required this.newCustomersChangePct,
    required this.newCustomersVs,
    required this.pendingApprovals,
    required this.pendingApprovalsChangePct,
    required this.pendingApprovalsVs,
  });
}

class ShopDashboardRepository {
  final SupabaseClient _client;
  final SystemLogsRepository _logs;

  ShopDashboardRepository(this._client, this._logs);

  void _logFailure(String action, Object error, {Map<String, dynamic>? meta}) {
    _logs.logErrorUnawaited(
      page: 'shop_dashboard_repository',
      action: action,
      error: error,
      meta: meta,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _profilesByIds(Iterable<String?> ids) async {
    final unique = ids.map((e) => (e ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final data = await _client.from('profiles').select('id, full_name, phone, avatar_url, avatar_path').inFilter('id', unique);
    final out = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      out[id] = m;
    }
    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _barbersByIds(Iterable<String?> ids) async {
    final unique = ids.map((e) => (e ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final data = await _client.from('barbers').select('id, profile_id, display_name, avatar_url, avatar_path').inFilter('id', unique);
    final out = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      out[id] = m;
    }
    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _servicesByIds(Iterable<String?> ids) async {
    final unique = ids.map((e) => (e ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final data = await _client.from('services').select('id, name_en, name_ar, price_bhd, duration_minutes').inFilter('id', unique);
    final out = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      out[id] = m;
    }
    return out;
  }

  Future<String?> getMyShopId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('barbershops')
          .select('id')
          .eq('owner_profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);
      final list = data as List;
      if (list.isEmpty) return null;
      return (list.first as Map)['id'] as String?;
    } catch (e) {
      throw AppException('Failed to load shop', cause: e);
    }
  }

  Future<ShopDashboardStats?> loadStats() async {
    final shopId = await getMyShopId();
    if (shopId == null) return null;

    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final startUtc = startOfDayLocal.toUtc().toIso8601String();
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final start30d = DateTime.now().toUtc().subtract(const Duration(days: 30));
      final start30dDate = start30d.toIso8601String().substring(0, 10);

      final todayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .gte('start_at', startUtc)
          .lt('start_at', nowUtc);
      final upcomingBookings = await _client.from('bookings').count(CountOption.exact).eq('shop_id', shopId).gte('start_at', nowUtc);
      final posts = await _client.from('reels').count(CountOption.exact).eq('shop_id', shopId);
      final reviews = await _client
          .from('reviews')
          .count(CountOption.exact)
          .eq('target_type', 'shop')
          .eq('target_id', shopId)
          .eq('status', 'published');
      final revenueRows =
          await _client.from('shop_revenue_daily').select('gross_revenue, currency').eq('shop_id', shopId).gte('day', start30dDate).limit(2000);

      var revenueBhd = 0.0;
      for (final r in revenueRows) {
        final m = Map<String, dynamic>.from(r as Map);
        if ((m['currency'] as String?) != 'BHD') continue;
        revenueBhd += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
      }

      return ShopDashboardStats(
        shopId: shopId,
        todayBookings: todayBookings,
        upcomingBookings: upcomingBookings,
        posts: posts,
        reviews: reviews,
        revenueBhd30d: revenueBhd,
      );
    } catch (e) {
      throw AppException('Failed to load dashboard', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listUpcomingBookings({int limit = 20}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('bookings')
          .select('id, start_at, status, customer_profile_id')
          .eq('shop_id', shopId)
          .gte('start_at', nowUtc)
          .order('start_at', ascending: true)
          .limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
      }
      return rows;
    } catch (e) {
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<ShopTodayOverview?> loadTodayOverview() async {
    final shopId = await getMyShopId();
    if (shopId == null) return null;
    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final startUtc = startOfDayLocal.toUtc().toIso8601String();
      final endUtc = startOfDayLocal.add(const Duration(days: 1)).toUtc().toIso8601String();
      final day = startOfDayLocal.toUtc().toIso8601String().substring(0, 10);

      final bookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .gte('start_at', startUtc)
          .lt('start_at', endUtc);

      final customersRows = await _client
          .from('bookings')
          .select('customer_profile_id')
          .eq('shop_id', shopId)
          .gte('start_at', startUtc)
          .lt('start_at', endUtc)
          .limit(5000);
      final customerIds = (customersRows as List)
          .map((e) => (e as Map)['customer_profile_id'] as String?)
          .whereType<String>()
          .toSet();

      final pendingOrders = await _client.from('orders').count(CountOption.exact).eq('shop_id', shopId).eq('status', 'pending');

      final revenueRows =
          await _client.from('shop_revenue_daily').select('gross_revenue, currency').eq('shop_id', shopId).eq('day', day).limit(50);
      var revenueBhd = 0.0;
      for (final r in revenueRows) {
        final m = Map<String, dynamic>.from(r as Map);
        if ((m['currency'] as String?) != 'BHD') continue;
        revenueBhd += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
      }

      return ShopTodayOverview(
        bookings: bookings,
        revenueBhd: revenueBhd,
        customers: customerIds.length,
        pendingOrders: pendingOrders,
      );
    } catch (e) {
      throw AppException('Failed to load overview', cause: e);
    }
  }

  double _pctChange({required num today, required num yesterday}) {
    if (yesterday == 0) return today == 0 ? 0 : 100;
    return ((today - yesterday) / yesterday) * 100;
  }

  Future<ShopOverviewWithChange?> loadTodayOverviewWithChange() async {
    final shopId = await getMyShopId();
    if (shopId == null) return null;
    try {
      final now = DateTime.now();
      final todayLocalStart = DateTime(now.year, now.month, now.day);
      final todayUtcStart = todayLocalStart.toUtc();
      final todayUtcEnd = todayLocalStart.add(const Duration(days: 1)).toUtc();

      final yesterdayLocalStart = todayLocalStart.subtract(const Duration(days: 1));
      final yesterdayUtcStart = yesterdayLocalStart.toUtc();
      final yesterdayUtcEnd = todayLocalStart.toUtc();

      final todayUtcStartIso = todayUtcStart.toIso8601String();
      final todayUtcEndIso = todayUtcEnd.toIso8601String();
      final yesterdayUtcStartIso = yesterdayUtcStart.toIso8601String();
      final yesterdayUtcEndIso = yesterdayUtcEnd.toIso8601String();

      final dayToday = todayUtcStartIso.substring(0, 10);
      final dayYesterday = yesterdayUtcStartIso.substring(0, 10);

      final todayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .gte('start_at', todayUtcStartIso)
          .lt('start_at', todayUtcEndIso);
      final yesterdayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .gte('start_at', yesterdayUtcStartIso)
          .lt('start_at', yesterdayUtcEndIso);

      final todayCustomersRows = await _client
          .from('bookings')
          .select('customer_profile_id')
          .eq('shop_id', shopId)
          .gte('start_at', todayUtcStartIso)
          .lt('start_at', todayUtcEndIso)
          .limit(5000);
      final todayCustomerIds = (todayCustomersRows as List)
          .map((e) => (e as Map)['customer_profile_id'] as String?)
          .whereType<String>()
          .toSet();

      final yesterdayCustomersRows = await _client
          .from('bookings')
          .select('customer_profile_id')
          .eq('shop_id', shopId)
          .gte('start_at', yesterdayUtcStartIso)
          .lt('start_at', yesterdayUtcEndIso)
          .limit(5000);
      final yesterdayCustomerIds = (yesterdayCustomersRows as List)
          .map((e) => (e as Map)['customer_profile_id'] as String?)
          .whereType<String>()
          .toSet();

      final pendingToday = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .gte('start_at', todayUtcStartIso)
          .lt('start_at', todayUtcEndIso);
      final pendingYesterday = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .gte('start_at', yesterdayUtcStartIso)
          .lt('start_at', yesterdayUtcEndIso);

      final todayRevenueRows =
          await _client.from('shop_revenue_daily').select('gross_revenue, currency').eq('shop_id', shopId).eq('day', dayToday).limit(50);
      var revenueTodayBhd = 0.0;
      for (final r in todayRevenueRows) {
        final m = Map<String, dynamic>.from(r as Map);
        if ((m['currency'] as String?) != 'BHD') continue;
        revenueTodayBhd += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
      }

      final yesterdayRevenueRows =
          await _client.from('shop_revenue_daily').select('gross_revenue, currency').eq('shop_id', shopId).eq('day', dayYesterday).limit(50);
      var revenueYesterdayBhd = 0.0;
      for (final r in yesterdayRevenueRows) {
        final m = Map<String, dynamic>.from(r as Map);
        if ((m['currency'] as String?) != 'BHD') continue;
        revenueYesterdayBhd += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
      }

      return ShopOverviewWithChange(
        todayBookings: todayBookings,
        todayBookingsVs: yesterdayBookings.toDouble(),
        todayBookingsChangePct: _pctChange(today: todayBookings, yesterday: yesterdayBookings),
        revenueTodayBhd: revenueTodayBhd,
        revenueTodayVs: revenueYesterdayBhd,
        revenueTodayChangePct: _pctChange(today: revenueTodayBhd, yesterday: revenueYesterdayBhd),
        newCustomers: todayCustomerIds.length,
        newCustomersVs: yesterdayCustomerIds.length.toDouble(),
        newCustomersChangePct: _pctChange(today: todayCustomerIds.length, yesterday: yesterdayCustomerIds.length),
        pendingApprovals: pendingToday,
        pendingApprovalsVs: pendingYesterday.toDouble(),
        pendingApprovalsChangePct: _pctChange(today: pendingToday, yesterday: pendingYesterday),
      );
    } catch (e) {
      throw AppException('Failed to load overview', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listUpcomingAppointments({int limit = 20}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('bookings')
          .select('id, start_at, end_at, status, price_bhd, currency, customer_profile_id, service_id, barber_id')
          .eq('shop_id', shopId)
          .gte('start_at', nowUtc)
          .order('start_at', ascending: true)
          .limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      final barbers = await _barbersByIds(rows.map((e) => e['barber_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        final barberId = (r['barber_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
        r['barbers'] = barberId == null ? null : barbers[barberId];
      }
      return rows;
    } catch (e) {
      throw AppException('Failed to load appointments', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listTodayAppointments({int limit = 40}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final startUtc = startOfDayLocal.toUtc().toIso8601String();
      final endUtc = startOfDayLocal.add(const Duration(days: 1)).toUtc().toIso8601String();
      final data = await _client
          .from('bookings')
          .select('id, start_at, end_at, status, price_bhd, currency, customer_profile_id, service_id, barber_id')
          .eq('shop_id', shopId)
          .gte('start_at', startUtc)
          .lt('start_at', endUtc)
          .order('start_at', ascending: true)
          .limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      final barbers = await _barbersByIds(rows.map((e) => e['barber_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        final barberId = (r['barber_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
        r['barbers'] = barberId == null ? null : barbers[barberId];
      }
      return rows;
    } catch (e) {
      throw AppException('Failed to load appointments', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listShopActivity({int limit = 30}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    bool returnEmpty(PostgrestException e) {
      final code = (e.code ?? '').trim();
      final msg = (e.message).toLowerCase();
      if (code == '42P01') return true;
      if (code == '42501') return true;
      if (msg.contains('permission denied')) return true;
      if (msg.contains('does not exist')) return true;
      return false;
    }
    try {
      final data = await _client.from('activity_logs').select().eq('shop_id', shopId).order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PostgrestException catch (e) {
      if (returnEmpty(e)) return const [];
      try {
        final data = await _client
            .from('activity_logs')
            .select()
            .eq('target_type', 'shop')
            .eq('target_id', shopId)
            .order('created_at', ascending: false)
            .limit(limit);
        return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on PostgrestException catch (e2) {
        if (returnEmpty(e2)) return const [];
        throw AppException('Failed to load activity', cause: e2);
      } catch (e2) {
        throw AppException('Failed to load activity', cause: e2);
      }
    } catch (e) {
      throw AppException('Failed to load activity', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listBookings({required bool upcoming, int limit = 60}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      var q = _client
          .from('bookings')
          .select('id, start_at, end_at, status, customer_profile_id, service_id, barber_id, cancelled_by_profile_id, cancel_reason, cancelled_reason')
          .eq('shop_id', shopId);
      q = upcoming ? q.gte('start_at', nowUtc) : q.lt('start_at', nowUtc);
      final data = await q.order('start_at', ascending: upcoming).limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      final barbers = await _barbersByIds(rows.map((e) => e['barber_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        final barberId = (r['barber_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
        r['barbers'] = barberId == null ? null : barbers[barberId];
      }
      return rows;
    } catch (e) {
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listBookingsByStatus({String? status, int limit = 120}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      var q = _client
          .from('bookings')
          .select('id, start_at, end_at, status, price_bhd, currency, notes, customer_profile_id, barber_id, service_id, cancelled_by_profile_id, cancel_reason, cancelled_reason')
          .eq('shop_id', shopId);
      if (status != null && status != 'all') {
        q = q.eq('status', status);
      }
      final data = await q.order('start_at', ascending: false).limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      final barbers = await _barbersByIds(rows.map((e) => e['barber_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        final barberId = (r['barber_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
        r['barbers'] = barberId == null ? null : barbers[barberId];
      }
      return rows;
    } catch (e) {
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<void> updateBookingStatus({required String bookingId, required String status, String? cancelReason}) async {
    if (!['pending', 'confirmed', 'in_progress', 'rescheduled', 'no_show', 'cancelled', 'completed'].contains(status)) {
      throw const AppException('Invalid status');
    }
    try {
      switch (status) {
        case 'cancelled':
          await _client.rpc('cancel_booking', params: {
            'booking_id': bookingId,
            'reason': (cancelReason ?? '').trim().isEmpty ? null : cancelReason,
          });
          return;
        case 'confirmed':
          await _client.rpc('confirm_booking', params: {'booking_id': bookingId});
          return;
        case 'in_progress':
          await _client.rpc('start_booking', params: {'booking_id': bookingId});
          return;
        case 'completed':
          await _client.rpc('complete_booking', params: {'booking_id': bookingId});
          return;
        case 'no_show':
          await _client.rpc('mark_booking_no_show', params: {'booking_id': bookingId});
          return;
        case 'pending':
        case 'rescheduled':
          throw const AppException('Unsupported manual status change');
      }
    } catch (e) {
      _logFailure('update_booking_status_failed', e, meta: {
        'booking_id': bookingId,
        'status': status,
      });
      throw AppException('Failed to update booking', cause: e);
    }
  }

  Future<void> rescheduleBooking({required String bookingId, required DateTime newStartAt}) async {
    try {
      await _client.rpc(
        'reschedule_booking',
        params: {
          'booking_id': bookingId,
          'new_start_at': newStartAt.toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      _logFailure('reschedule_booking_failed', e, meta: {
        'booking_id': bookingId,
      });
      throw AppException('Failed to reschedule booking', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listShopOrders({int limit = 30}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      final data = await _client
          .from('orders')
          .select('id, customer_profile_id, status, total_amount, currency, payment_method, payment_status, created_at, delivery_address, profiles(full_name, phone)')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load orders', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listShopOrdersByStatus({String? status, int limit = 60}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return const [];
    try {
      var q = _client
          .from('orders')
          .select('id, customer_profile_id, status, total_amount, currency, payment_method, payment_status, created_at, delivery_address, profiles(full_name, phone)')
          .eq('shop_id', shopId);
      if (status != null && status != 'all') {
        q = q.eq('status', status);
      }
      final data = await q.order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load orders', cause: e);
    }
  }

  Future<Map<String, dynamic>?> getShopOrderById({required String orderId}) async {
    final shopId = await getMyShopId();
    if (shopId == null) return null;
    try {
      final data = await _client
          .from('orders')
          .select('id, customer_profile_id, status, total_amount, currency, payment_method, payment_status, created_at, delivery_address, profiles(full_name, phone)')
          .eq('shop_id', shopId)
          .eq('id', orderId)
          .maybeSingle();
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      throw AppException('Failed to load order', cause: e);
    }
  }

  Future<void> updateOrderStatus({required String orderId, required String status}) async {
    if (!['pending', 'accepted', 'rejected', 'shipped', 'delivered', 'cancelled'].contains(status)) {
      throw const AppException('Invalid status');
    }
    try {
      await _client.from('orders').update({'status': status}).eq('id', orderId);
    } catch (e) {
      throw AppException('Failed to update order', cause: e);
    }
  }

  Future<void> updateOrderPaymentStatus({required String orderId, required String paymentStatus}) async {
    if (!['unpaid', 'paid', 'failed', 'refunded'].contains(paymentStatus)) {
      throw const AppException('Invalid status');
    }
    try {
      await _client.from('orders').update({'payment_status': paymentStatus}).eq('id', orderId);
    } catch (e) {
      throw AppException('Failed to update order', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listOrderItems({required String orderId}) async {
    try {
      final data = await _client
          .from('order_items')
          .select('id, order_id, product_id, quantity, unit_price, line_total, created_at, products(name, images)')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load order items', cause: e);
    }
  }
}

final shopDashboardRepositoryProvider = Provider<ShopDashboardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ShopDashboardRepository(client, ref.watch(systemLogsRepositoryProvider));
});

final shopDashboardStatsProvider = FutureProvider<ShopDashboardStats?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).loadStats();
});

final shopDashboardUpcomingBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listUpcomingBookings();
});

final shopDashboardOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listShopOrders();
});

final shopDashboardTodayOverviewProvider = FutureProvider<ShopTodayOverview?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).loadTodayOverview();
});

final shopDashboardTodayOverviewWithChangeProvider = FutureProvider<ShopOverviewWithChange?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).loadTodayOverviewWithChange();
});

final shopDashboardUpcomingAppointmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listUpcomingAppointments();
});

final shopDashboardTodayAppointmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listTodayAppointments();
});

final shopDashboardActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listShopActivity();
});

final shopBookingsByStatusProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  return ref.watch(shopDashboardRepositoryProvider).listBookingsByStatus(status: status == 'all' ? null : status);
});
