import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../barber/data/barber_repository.dart';

class BarberDashboardStats {
  final String barberId;
  final int todayBookings;
  final int weekBookings;
  final int totalClients;
  final double todayEarningsBhd;

  const BarberDashboardStats({
    required this.barberId,
    required this.todayBookings,
    required this.weekBookings,
    required this.totalClients,
    required this.todayEarningsBhd,
  });

  Map<String, dynamic> toJson() {
    return {
      'barber_id': barberId,
      'today_bookings': todayBookings,
      'week_bookings': weekBookings,
      'total_clients': totalClients,
      'today_earnings_bhd': todayEarningsBhd,
    };
  }

  factory BarberDashboardStats.fromJson(Map<String, dynamic> json) {
    return BarberDashboardStats(
      barberId: (json['barber_id'] as String?) ?? '',
      todayBookings: (json['today_bookings'] as num?)?.toInt() ?? 0,
      weekBookings: (json['week_bookings'] as num?)?.toInt() ?? 0,
      totalClients: (json['total_clients'] as num?)?.toInt() ?? 0,
      todayEarningsBhd: (json['today_earnings_bhd'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BarberHomeKpi {
  final double value;
  final double growthPct;

  const BarberHomeKpi({required this.value, required this.growthPct});
}

class BarberHomeKpis {
  final BarberHomeKpi todayBookings;
  final BarberHomeKpi revenueTodayBhd;
  final BarberHomeKpi tipsTodayBhd;
  final BarberHomeKpi newFollowers;

  const BarberHomeKpis({
    required this.todayBookings,
    required this.revenueTodayBhd,
    required this.tipsTodayBhd,
    required this.newFollowers,
  });
}

class BarberWeekSeries {
  final List<int> views;
  final List<int> followers;
  final List<int> bookings;

  const BarberWeekSeries({required this.views, required this.followers, required this.bookings});
}

class BarberDashboardRepository {
  final SupabaseClient _client;
  final KvStore _kv;

  BarberDashboardRepository(this._client, this._kv);

  Future<BarberDashboardStats> loadStats({required String barberId}) async {
    final cacheKey = 'barber_dashboard_stats_$barberId';
    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final startUtc = startOfDayLocal.toUtc().toIso8601String();
      final endUtc = startOfDayLocal.add(const Duration(days: 1)).toUtc().toIso8601String();

      final todayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('barber_id', barberId)
          .inFilter('status', const ['confirmed', 'completed'])
          .gte('start_at', startUtc)
          .lt('start_at', endUtc);

      final startOfWeekLocal = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final weekStartUtc = startOfWeekLocal.toUtc().toIso8601String();
      final weekEndUtc = startOfWeekLocal.add(const Duration(days: 7)).toUtc().toIso8601String();
      final weekBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('barber_id', barberId)
          .inFilter('status', const ['confirmed', 'completed'])
          .gte('start_at', weekStartUtc)
          .lt('start_at', weekEndUtc);

      final clientsRows = await _client
          .from('bookings')
          .select('customer_profile_id')
          .eq('barber_id', barberId)
          .inFilter('status', const ['confirmed', 'completed'])
          .limit(1200);
      final clientIds = <String>{};
      for (final r in (clientsRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = (m['customer_profile_id'] as String?)?.trim();
        if (id != null && id.isNotEmpty) clientIds.add(id);
      }

      final startDate = startOfDayLocal.toUtc().toIso8601String().substring(0, 10);
      final revenueRows =
          await _client.from('barber_revenue_daily').select('gross_revenue, currency').eq('barber_id', barberId).eq('day', startDate).limit(50);
      var todayEarningsBhd = 0.0;
      for (final r in (revenueRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        if ((m['currency'] as String?) != 'BHD') continue;
        todayEarningsBhd += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
      }

      final stats = BarberDashboardStats(
        barberId: barberId,
        todayBookings: todayBookings,
        weekBookings: weekBookings,
        totalClients: clientIds.length,
        todayEarningsBhd: todayEarningsBhd,
      );
      try {
        await _kv.write(cacheKey, jsonEncode(stats.toJson()));
      } catch (_) {}
      return stats;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          return BarberDashboardStats.fromJson(Map<String, dynamic>.from(jsonDecode(cached)));
        }
      } catch (_) {}
      throw AppException('Failed to load dashboard', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listUpcomingAppointments({required String barberId, int limit = 10}) async {
    final cacheKey = 'barber_dashboard_upcoming_$barberId';
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('bookings')
          .select(
            'id, start_at, end_at, status, total_price, currency, customer_profile_id, service_id, profiles(full_name, avatar_url, avatar_path), services(name, name_en, name_ar, price_bhd, duration_minutes, image_url)',
          )
          .eq('barber_id', barberId)
          .gte('start_at', nowUtc)
          .order('start_at', ascending: true)
          .limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      try {
        await _kv.write(cacheKey, jsonEncode(rows));
      } catch (_) {}
      return rows;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load appointments', cause: e);
    }
  }

  double _growthPct(num today, num yesterday) {
    final y = yesterday.toDouble();
    if (y <= 0.000001) return 0;
    return ((today.toDouble() - y) / y) * 100.0;
  }

  Future<BarberHomeKpis> loadHomeKpis({required String barberId}) async {
    final cacheKey = 'barber_home_kpis_$barberId';
    try {
      final now = DateTime.now();
      final todayStartLocal = DateTime(now.year, now.month, now.day);
      final yStartLocal = todayStartLocal.subtract(const Duration(days: 1));

      final todayStartUtc = todayStartLocal.toUtc().toIso8601String();
      final todayEndUtc = todayStartLocal.add(const Duration(days: 1)).toUtc().toIso8601String();
      final yStartUtc = yStartLocal.toUtc().toIso8601String();
      final yEndUtc = todayStartUtc;

      final todayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('barber_id', barberId)
          .inFilter('status', const ['confirmed', 'completed', 'in_progress'])
          .gte('start_at', todayStartUtc)
          .lt('start_at', todayEndUtc);

      final yesterdayBookings = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('barber_id', barberId)
          .inFilter('status', const ['confirmed', 'completed', 'in_progress'])
          .gte('start_at', yStartUtc)
          .lt('start_at', yEndUtc);

      double revenueToday = 0;
      double revenueYesterday = 0;
      try {
        final todayDay = todayStartLocal.toUtc().toIso8601String().substring(0, 10);
        final yDay = yStartLocal.toUtc().toIso8601String().substring(0, 10);
        final todayRows =
            await _client.from('barber_revenue_daily').select('gross_revenue, currency').eq('barber_id', barberId).eq('day', todayDay).limit(50);
        for (final r in (todayRows as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          if ((m['currency'] as String?) != 'BHD') continue;
          revenueToday += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
        }
        final yRows = await _client.from('barber_revenue_daily').select('gross_revenue, currency').eq('barber_id', barberId).eq('day', yDay).limit(50);
        for (final r in (yRows as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          if ((m['currency'] as String?) != 'BHD') continue;
          revenueYesterday += (m['gross_revenue'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}

      final followersToday = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('target_type', 'barber')
          .eq('target_id', barberId)
          .gte('created_at', todayStartUtc)
          .lt('created_at', todayEndUtc);

      final followersYesterday = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('target_type', 'barber')
          .eq('target_id', barberId)
          .gte('created_at', yStartUtc)
          .lt('created_at', yEndUtc);

      final out = BarberHomeKpis(
        todayBookings: BarberHomeKpi(value: todayBookings.toDouble(), growthPct: _growthPct(todayBookings, yesterdayBookings)),
        revenueTodayBhd: BarberHomeKpi(value: revenueToday, growthPct: _growthPct(revenueToday, revenueYesterday)),
        tipsTodayBhd: const BarberHomeKpi(value: 0, growthPct: 0),
        newFollowers: BarberHomeKpi(value: followersToday.toDouble(), growthPct: _growthPct(followersToday, followersYesterday)),
      );
      try {
        await _kv.write(
          cacheKey,
          jsonEncode({
            'today_bookings': out.todayBookings.value,
            'today_bookings_growth': out.todayBookings.growthPct,
            'revenue_today': out.revenueTodayBhd.value,
            'revenue_growth': out.revenueTodayBhd.growthPct,
            'tips_today': out.tipsTodayBhd.value,
            'tips_growth': out.tipsTodayBhd.growthPct,
            'followers_today': out.newFollowers.value,
            'followers_growth': out.newFollowers.growthPct,
          }),
        );
      } catch (_) {}
      return out;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final m = Map<String, dynamic>.from(jsonDecode(cached));
          return BarberHomeKpis(
            todayBookings: BarberHomeKpi(value: (m['today_bookings'] as num?)?.toDouble() ?? 0, growthPct: (m['today_bookings_growth'] as num?)?.toDouble() ?? 0),
            revenueTodayBhd: BarberHomeKpi(value: (m['revenue_today'] as num?)?.toDouble() ?? 0, growthPct: (m['revenue_growth'] as num?)?.toDouble() ?? 0),
            tipsTodayBhd: BarberHomeKpi(value: (m['tips_today'] as num?)?.toDouble() ?? 0, growthPct: (m['tips_growth'] as num?)?.toDouble() ?? 0),
            newFollowers: BarberHomeKpi(value: (m['followers_today'] as num?)?.toDouble() ?? 0, growthPct: (m['followers_growth'] as num?)?.toDouble() ?? 0),
          );
        }
      } catch (_) {}
      throw AppException('Failed to load home stats', cause: e);
    }
  }

  Future<BarberWeekSeries> loadWeekSeries({required String barberId}) async {
    final cacheKey = 'barber_week_series_$barberId';
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final startUtc = startLocal.toUtc().toIso8601String();
    try {
      final views = List<int>.filled(7, 0);
      final followers = List<int>.filled(7, 0);
      final bookings = List<int>.filled(7, 0);

      try {
        final reelsRows = await _client.from('reels').select('id').eq('barber_id', barberId).isFilter('deleted_at', null).limit(800);
        final reelIds = (reelsRows as List).map((e) => (e as Map)['id'] as String?).whereType<String>().where((e) => e.isNotEmpty).toList(growable: false);
        if (reelIds.isNotEmpty) {
          const chunkSize = 120;
          for (var i = 0; i < reelIds.length; i += chunkSize) {
            final chunk = reelIds.sublist(i, math.min(i + chunkSize, reelIds.length));
            final events = await _client
                .from('reel_view_events')
                .select('created_at')
                .inFilter('reel_id', chunk)
                .gte('created_at', startUtc)
                .limit(5000);
            for (final raw in (events as List)) {
              final m = Map<String, dynamic>.from(raw as Map);
              final createdAt = DateTime.tryParse((m['created_at'] as String?) ?? '');
              if (createdAt == null) continue;
              final day = DateTime(createdAt.toLocal().year, createdAt.toLocal().month, createdAt.toLocal().day);
              final diff = day.difference(startLocal).inDays;
              if (diff < 0 || diff > 6) continue;
              views[diff] += 1;
            }
          }
        }
      } catch (_) {}

      try {
        final followRows = await _client
            .from('follows')
            .select('created_at')
            .eq('target_type', 'barber')
            .eq('target_id', barberId)
            .gte('created_at', startUtc)
            .limit(2000);
        for (final raw in (followRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final createdAt = DateTime.tryParse((m['created_at'] as String?) ?? '');
          if (createdAt == null) continue;
          final day = DateTime(createdAt.toLocal().year, createdAt.toLocal().month, createdAt.toLocal().day);
          final diff = day.difference(startLocal).inDays;
          if (diff < 0 || diff > 6) continue;
          followers[diff] += 1;
        }
      } catch (_) {}

      try {
        final bookingRows = await _client
            .from('bookings')
            .select('start_at, status')
            .eq('barber_id', barberId)
            .gte('start_at', startUtc)
            .inFilter('status', const ['confirmed', 'completed', 'in_progress'])
            .limit(2000);
        for (final raw in (bookingRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final startAt = DateTime.tryParse((m['start_at'] as String?) ?? '');
          if (startAt == null) continue;
          final day = DateTime(startAt.toLocal().year, startAt.toLocal().month, startAt.toLocal().day);
          final diff = day.difference(startLocal).inDays;
          if (diff < 0 || diff > 6) continue;
          bookings[diff] += 1;
        }
      } catch (_) {}

      final out = BarberWeekSeries(views: views, followers: followers, bookings: bookings);
      try {
        await _kv.write(cacheKey, jsonEncode({'views': views, 'followers': followers, 'bookings': bookings}));
      } catch (_) {}
      return out;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = Map<String, dynamic>.from(jsonDecode(cached));
          final views = (decoded['views'] as List?)?.map((e) => (e as num).toInt()).toList(growable: false) ?? List<int>.filled(7, 0);
          final followers = (decoded['followers'] as List?)?.map((e) => (e as num).toInt()).toList(growable: false) ?? List<int>.filled(7, 0);
          final bookings = (decoded['bookings'] as List?)?.map((e) => (e as num).toInt()).toList(growable: false) ?? List<int>.filled(7, 0);
          return BarberWeekSeries(views: views, followers: followers, bookings: bookings);
        }
      } catch (_) {}
      throw AppException('Failed to load weekly performance', cause: e);
    }
  }
}

final barberDashboardRepositoryProvider = Provider<BarberDashboardRepository>((ref) {
  return BarberDashboardRepository(ref.watch(supabaseClientProvider), ref.watch(kvStoreProvider));
});

final barberDashboardStatsProvider = FutureProvider<BarberDashboardStats?>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(barberDashboardRepositoryProvider).loadStats(barberId: barber.id);
});

final barberDashboardUpcomingAppointmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberDashboardRepositoryProvider).listUpcomingAppointments(barberId: barber.id);
});

final barberHomeKpisProvider = FutureProvider.autoDispose<BarberHomeKpis?>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(barberDashboardRepositoryProvider).loadHomeKpis(barberId: barber.id);
});

final barberWeekSeriesProvider = FutureProvider.autoDispose<BarberWeekSeries?>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(barberDashboardRepositoryProvider).loadWeekSeries(barberId: barber.id);
});
