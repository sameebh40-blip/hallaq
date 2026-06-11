import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/resilient_request.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/time/shop_time.dart';

const _supabaseDebugEnabled =
    bool.fromEnvironment('SUPABASE_DEBUG', defaultValue: false) || bool.fromEnvironment('NEXT_PUBLIC_SUPABASE_DEBUG', defaultValue: false);

class BarberAvailabilityRepository {
  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 8);

  BarberAvailabilityRepository(this._client);

  bool _shouldFallback(Object e) {
    if (e is! PostgrestException) return false;
    if ((e.code ?? '').trim().toUpperCase() == 'PGRST202') return true;
    final msg = (e.message).toLowerCase();
    return msg.contains('could not find the function') || msg.contains('get_available_days') || msg.contains('get_available_times');
  }

  Future<List<DateTime>> _fallbackAvailableStartsForDay({
    required String barberId,
    required DateTime day,
    required int durationMinutes,
    required int slotMinutes,
  }) async {
    final weekday0 = day.weekday % 7;
    final step = Duration(minutes: slotMinutes);
    final duration = Duration(minutes: durationMinutes);

    final day0 = DateTime(day.year, day.month, day.day);
    final dayStartUtc = ShopTime.toUtc(DateTime(day0.year, day0.month, day0.day));
    final dayEndUtc = ShopTime.toUtc(DateTime(day0.year, day0.month, day0.day).add(const Duration(days: 1)));
    final nowShop = ShopTime.now();

    final hoursRaw = await resilientRequest(
      () => _client
          .from('barber_working_hours')
          .select('weekday,start_time,end_time,enabled')
          .eq('barber_id', barberId)
          .eq('enabled', true)
          .eq('weekday', weekday0),
      retries: 0,
      timeout: _timeout,
    );

    Object? timeOffError;
    Object? bookingsError;
    dynamic timeOffRaw;
    dynamic bookingsRaw;
    try {
      timeOffRaw = await resilientRequest(
        () => _client
            .from('barber_time_off')
            .select('starts_at,ends_at')
            .eq('barber_id', barberId)
            .lt('starts_at', dayEndUtc.toIso8601String())
            .gte('ends_at', dayStartUtc.toIso8601String()),
        retries: 0,
        timeout: _timeout,
      );
    } catch (e) {
      timeOffError = e;
      timeOffRaw = const <dynamic>[];
    }

    try {
      bookingsRaw = await resilientRequest(
        () => _client
            .from('bookings')
            .select('start_at,end_at,status')
            .eq('barber_id', barberId)
            .inFilter('status', const ['pending', 'confirmed', 'in_progress', 'rescheduled'])
            .gte('end_at', dayStartUtc.toIso8601String())
            .lt('start_at', dayEndUtc.toIso8601String())
            .limit(500),
        retries: 0,
        timeout: _timeout,
      );
    } catch (e) {
      bookingsError = e;
      bookingsRaw = const <dynamic>[];
    }

    if ((kDebugMode || _supabaseDebugEnabled) && (timeOffError != null || bookingsError != null)) {
      debugPrint('[Availability/fallback] partial (timeOff=$timeOffError bookings=$bookingsError)');
    }

    final windows = <({TimeOfDay start, TimeOfDay end})>[];
    for (final row in (hoursRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final start = _parseTimeOfDay(map['start_time'] as String?);
      final end = _parseTimeOfDay(map['end_time'] as String?);
      if (start == null || end == null) continue;
      windows.add((start: start, end: end));
    }
    windows.sort((a, b) => (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));

    final timeOff = <({DateTime start, DateTime end})>[];
    for (final row in (timeOffRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final start = DateTime.tryParse(map['starts_at'] as String? ?? '');
      final end = DateTime.tryParse(map['ends_at'] as String? ?? '');
      if (start == null || end == null) continue;
      timeOff.add((start: ShopTime.fromUtc(start), end: ShopTime.fromUtc(end)));
    }

    final bookings = <({DateTime start, DateTime end})>[];
    for (final row in (bookingsRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final start = DateTime.tryParse(map['start_at'] as String? ?? '');
      final end = DateTime.tryParse(map['end_at'] as String? ?? '');
      if (start == null || end == null) continue;
      bookings.add((start: ShopTime.fromUtc(start), end: ShopTime.fromUtc(end)));
    }
    bookings.sort((a, b) => a.start.compareTo(b.start));

    final results = <DateTime>[];
    for (final w in windows) {
      final windowStart = DateTime(day0.year, day0.month, day0.day, w.start.hour, w.start.minute);
      final windowEnd = DateTime(day0.year, day0.month, day0.day, w.end.hour, w.end.minute);
      var candidate = windowStart.isAfter(nowShop) ? windowStart : nowShop;
      candidate = _ceilToStep(candidate, step);

      while (candidate.add(duration).isBefore(windowEnd) || candidate.add(duration).isAtSameMomentAs(windowEnd)) {
        final candidateEnd = candidate.add(duration);
        if (!_overlapsBookings(candidate, candidateEnd, timeOff) && !_overlapsBookings(candidate, candidateEnd, bookings)) {
          results.add(candidate);
        }
        candidate = candidate.add(step);
      }
    }
    return results;
  }

  Future<Map<DateTime, bool>> _fallbackAvailableDaysForMonth({
    required String barberId,
    required DateTime month,
    required int durationMinutes,
    required int slotMinutes,
  }) async {
    final month0 = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month0.year, month0.month + 1, 0);
    final todayShop = ShopTime.now();
    final today0 = DateTime(todayShop.year, todayShop.month, todayShop.day);

    final startDay = month0.isAfter(today0) ? month0 : today0;
    if (startDay.isAfter(lastDay)) return const <DateTime, bool>{};

    final step = Duration(minutes: slotMinutes);
    final duration = Duration(minutes: durationMinutes);

    final startUtc = ShopTime.toUtc(DateTime(startDay.year, startDay.month, startDay.day));
    final endUtc = ShopTime.toUtc(DateTime(lastDay.year, lastDay.month, lastDay.day).add(const Duration(days: 1)));

    final hoursRaw = await resilientRequest(
      () => _client.from('barber_working_hours').select('weekday,start_time,end_time,enabled').eq('barber_id', barberId).eq('enabled', true),
      retries: 0,
      timeout: _timeout,
    );

    final workingByWeekday = <int, List<({TimeOfDay start, TimeOfDay end})>>{};
    for (final row in (hoursRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final weekday = (map['weekday'] as num?)?.toInt();
      if (weekday == null) continue;
      final start = _parseTimeOfDay(map['start_time'] as String?);
      final end = _parseTimeOfDay(map['end_time'] as String?);
      if (start == null || end == null) continue;
      (workingByWeekday[weekday] ??= []).add((start: start, end: end));
    }
    for (final list in workingByWeekday.values) {
      list.sort((a, b) => (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));
    }

    Object? timeOffError;
    Object? bookingsError;
    dynamic timeOffRaw;
    dynamic bookingsRaw;
    try {
      timeOffRaw = await resilientRequest(
        () => _client
            .from('barber_time_off')
            .select('starts_at,ends_at')
            .eq('barber_id', barberId)
            .lt('starts_at', endUtc.toIso8601String())
            .gte('ends_at', startUtc.toIso8601String()),
        retries: 0,
        timeout: _timeout,
      );
    } catch (e) {
      timeOffError = e;
      timeOffRaw = const <dynamic>[];
    }

    try {
      bookingsRaw = await resilientRequest(
        () => _client
            .from('bookings')
            .select('start_at,end_at,status')
            .eq('barber_id', barberId)
            .inFilter('status', const ['pending', 'confirmed', 'in_progress', 'rescheduled'])
            .gte('end_at', startUtc.toIso8601String())
            .lt('start_at', endUtc.toIso8601String())
            .limit(500),
        retries: 0,
        timeout: _timeout,
      );
    } catch (e) {
      bookingsError = e;
      bookingsRaw = const <dynamic>[];
    }

    if ((kDebugMode || _supabaseDebugEnabled) && (timeOffError != null || bookingsError != null)) {
      debugPrint('[Availability/fallback] partial (timeOff=$timeOffError bookings=$bookingsError)');
    }

    final timeOff = <({DateTime start, DateTime end})>[];
    for (final row in (timeOffRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final start = DateTime.tryParse(map['starts_at'] as String? ?? '');
      final end = DateTime.tryParse(map['ends_at'] as String? ?? '');
      if (start == null || end == null) continue;
      timeOff.add((start: ShopTime.fromUtc(start), end: ShopTime.fromUtc(end)));
    }

    final bookings = <({DateTime start, DateTime end})>[];
    for (final row in (bookingsRaw as List)) {
      final map = Map<String, dynamic>.from(row);
      final start = DateTime.tryParse(map['start_at'] as String? ?? '');
      final end = DateTime.tryParse(map['end_at'] as String? ?? '');
      if (start == null || end == null) continue;
      bookings.add((start: ShopTime.fromUtc(start), end: ShopTime.fromUtc(end)));
    }
    bookings.sort((a, b) => a.start.compareTo(b.start));

    bool hasSlotForDay(DateTime day0) {
      final weekday0 = day0.weekday % 7;
      final windows = workingByWeekday[weekday0];
      if (windows == null || windows.isEmpty) return false;

      for (final w in windows) {
        final windowStart = DateTime(day0.year, day0.month, day0.day, w.start.hour, w.start.minute);
        final windowEnd = DateTime(day0.year, day0.month, day0.day, w.end.hour, w.end.minute);
        var candidate = windowStart.isAfter(todayShop) ? windowStart : todayShop;
        candidate = _ceilToStep(candidate, step);
        while (candidate.add(duration).isBefore(windowEnd) || candidate.add(duration).isAtSameMomentAs(windowEnd)) {
          final candidateEnd = candidate.add(duration);
          if (!_overlapsBookings(candidate, candidateEnd, timeOff) && !_overlapsBookings(candidate, candidateEnd, bookings)) {
            return true;
          }
          candidate = candidate.add(step);
        }
      }
      return false;
    }

    final map = <DateTime, bool>{};
    for (var d = startDay; !d.isAfter(lastDay); d = d.add(const Duration(days: 1))) {
      map[DateTime(d.year, d.month, d.day)] = hasSlotForDay(DateTime(d.year, d.month, d.day));
    }
    return map;
  }

  Future<Map<DateTime, bool>> listAvailableDaysForMonth({
    required String barberId,
    required DateTime month,
    required int durationMinutes,
    int slotMinutes = 30,
  }) async {
    final month0 = DateTime(month.year, month.month, 1);
    try {
      final data = await resilientRequest(
        () => _client.rpc(
          'get_available_days',
          params: {
            'barber': barberId,
            'month': '${month0.year}-${month0.month.toString().padLeft(2, '0')}-01',
            'duration_minutes': durationMinutes,
            'slot_minutes': slotMinutes,
          },
        ),
        retries: 0,
        timeout: _timeout,
      );
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
      final map = <DateTime, bool>{};
      for (final r in rows) {
        final day0 = DateTime.tryParse(r['day'] as String? ?? '');
        if (day0 == null) continue;
        map[DateTime(day0.year, day0.month, day0.day)] = (r['has_slots'] as bool?) ?? false;
      }
      return map;
    } catch (e) {
      if (_shouldFallback(e) || e is PostgrestException || e is TimeoutException) {
        try {
          return await _fallbackAvailableDaysForMonth(
            barberId: barberId,
            month: month0,
            durationMinutes: durationMinutes,
            slotMinutes: slotMinutes,
          );
        } catch (_) {}
      }
      if (e is PostgrestException && (kDebugMode || _supabaseDebugEnabled)) {
        debugPrint('[Availability/get_available_days] ${e.code ?? ''} ${e.message} details=${e.details ?? ''} hint=${e.hint ?? ''}');
      }
      throw AppException('Failed to load availability', cause: e);
    }
  }

  Future<List<DateTime>> listAvailableStartsForDay({
    required String barberId,
    required DateTime day,
    required int durationMinutes,
    int slotMinutes = 30,
  }) async {
    final day0 = DateTime(day.year, day.month, day.day);
    try {
      final data = await resilientRequest(
        () => _client.rpc(
          'get_available_times',
          params: {
            'barber': barberId,
            'day': '${day0.year}-${day0.month.toString().padLeft(2, '0')}-${day0.day.toString().padLeft(2, '0')}',
            'duration_minutes': durationMinutes,
            'slot_minutes': slotMinutes,
          },
        ),
        retries: 0,
        timeout: _timeout,
      );
      return (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => _parseTimestampToLocal(e['start_at']))
          .whereType<DateTime>()
          .toList(growable: false);
    } catch (e) {
      if (_shouldFallback(e) || e is PostgrestException || e is TimeoutException) {
        try {
          return await _fallbackAvailableStartsForDay(
            barberId: barberId,
            day: day0,
            durationMinutes: durationMinutes,
            slotMinutes: slotMinutes,
          );
        } catch (_) {}
      }
      if (e is PostgrestException && (kDebugMode || _supabaseDebugEnabled)) {
        debugPrint('[Availability/get_available_times] ${e.code ?? ''} ${e.message} details=${e.details ?? ''} hint=${e.hint ?? ''}');
      }
      throw AppException('Failed to load availability', cause: e);
    }
  }

  Future<DateTime?> getNextAvailableStart({
    required String barberId,
    Duration horizon = const Duration(days: 7),
  }) async {
    final list = await suggestAvailableStarts(
      barberId: barberId,
      duration: const Duration(minutes: 30),
      horizon: horizon,
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<List<DateTime>> suggestAvailableStarts({
    required String barberId,
    required Duration duration,
    Duration horizon = const Duration(days: 7),
    int limit = 2,
    Duration step = const Duration(minutes: 30),
  }) async {
    try {
      final now = DateTime.now();
      final until = now.add(horizon);

      final hoursRaw = await _client
          .from('barber_working_hours')
          .select('weekday,start_time,end_time,enabled')
          .eq('barber_id', barberId)
          .eq('enabled', true);

      final timeOffRaw = await _client
          .from('barber_time_off')
          .select('starts_at,ends_at')
          .eq('barber_id', barberId)
          .lte('starts_at', until.toUtc().toIso8601String())
          .gte('ends_at', now.toUtc().toIso8601String());

      final bookingsRaw = await _client
          .from('bookings')
          .select('start_at,end_at')
          .eq('barber_id', barberId)
          .eq('status', 'confirmed')
          .gte('end_at', now.toUtc().toIso8601String())
          .lt('start_at', until.toUtc().toIso8601String())
          .limit(500);

      final workingByWeekday = <int, List<({TimeOfDay start, TimeOfDay end})>>{};
      for (final row in (hoursRaw as List)) {
        final map = Map<String, dynamic>.from(row);
        final weekday = (map['weekday'] as num).toInt();
        final start = _parseTimeOfDay(map['start_time'] as String?);
        final end = _parseTimeOfDay(map['end_time'] as String?);
        if (start == null || end == null) continue;
        (workingByWeekday[weekday] ??= []).add((start: start, end: end));
      }
      for (final list in workingByWeekday.values) {
        list.sort((a, b) => (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));
      }

      final timeOff = <({DateTime start, DateTime end})>[];
      for (final row in (timeOffRaw as List)) {
        final map = Map<String, dynamic>.from(row);
        final start = DateTime.tryParse(map['starts_at'] as String? ?? '');
        final end = DateTime.tryParse(map['ends_at'] as String? ?? '');
        if (start == null || end == null) continue;
        timeOff.add((start: start.toLocal(), end: end.toLocal()));
      }

      final acceptedBookings = <({DateTime start, DateTime end})>[];
      for (final row in (bookingsRaw as List)) {
        final map = Map<String, dynamic>.from(row);
        final start = DateTime.tryParse(map['start_at'] as String? ?? '');
        final end = DateTime.tryParse(map['end_at'] as String? ?? '');
        if (start == null || end == null) continue;
        acceptedBookings.add((start: start.toLocal(), end: end.toLocal()));
      }

      acceptedBookings.sort((a, b) => a.start.compareTo(b.start));

      final results = <DateTime>[];
      final startOfToday = DateTime(now.year, now.month, now.day);
      for (var dayOffset = 0; dayOffset <= horizon.inDays; dayOffset++) {
        final date = startOfToday.add(Duration(days: dayOffset));
        final weekday0 = date.weekday % 7;
        final windows = workingByWeekday[weekday0];
        if (windows == null || windows.isEmpty) continue;

        for (final w in windows) {
          final windowStart = DateTime(date.year, date.month, date.day, w.start.hour, w.start.minute);
          final windowEnd = DateTime(date.year, date.month, date.day, w.end.hour, w.end.minute);
          var candidate = windowStart.isAfter(now) ? windowStart : now;
          candidate = _ceilToStep(candidate, step);

          while (candidate.add(duration).isBefore(windowEnd) || candidate.add(duration).isAtSameMomentAs(windowEnd)) {
            final candidateEnd = candidate.add(duration);
            if (!_isWithinTimeOff(candidate, timeOff) && !_overlapsBookings(candidate, candidateEnd, acceptedBookings)) {
              results.add(candidate);
              if (results.length >= limit) return results;
            }
            candidate = candidate.add(step);
          }
        }
      }

      return results;
    } catch (e) {
      throw AppException('Failed to load availability', cause: e);
    }
  }
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

bool _isWithinTimeOff(DateTime candidate, List<({DateTime start, DateTime end})> timeOff) {
  for (final t in timeOff) {
    if (!candidate.isBefore(t.start) && candidate.isBefore(t.end)) return true;
  }
  return false;
}

DateTime _ceilToStep(DateTime dt, Duration step) {
  final stepMs = step.inMilliseconds;
  final msSinceHour = (dt.minute * 60 * 1000) + (dt.second * 1000) + dt.millisecond;
  final rem = msSinceHour % stepMs;
  final add = rem == 0 ? 0 : (stepMs - rem);
  return DateTime(dt.year, dt.month, dt.day, dt.hour).add(Duration(milliseconds: msSinceHour + add));
}

bool _overlapsBookings(DateTime start, DateTime end, List<({DateTime start, DateTime end})> bookings) {
  for (final b in bookings) {
    if (start.isBefore(b.end) && end.isAfter(b.start)) return true;
  }
  return false;
}

DateTime? _parseTimestampToLocal(Object? value) {
  final raw = (value is String) ? value.trim() : '';
  if (raw.isEmpty) return null;
  try {
    final hasTimezone = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw);
    final dt = DateTime.parse(raw);
    if (hasTimezone) return ShopTime.fromUtc(dt.toUtc());
    final assumedUtc = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
    return ShopTime.fromUtc(assumedUtc);
  } catch (_) {
    return null;
  }
}

final barberAvailabilityRepositoryProvider = Provider<BarberAvailabilityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BarberAvailabilityRepository(client);
});

final nextAvailableForBarberProvider = FutureProvider.family<DateTime?, String>((ref, barberId) async {
  return ref.watch(barberAvailabilityRepositoryProvider).getNextAvailableStart(barberId: barberId);
});

final suggestedStartsProvider = FutureProvider.family<List<DateTime>, ({String barberId, int durationMin})>((ref, p) async {
  return ref.watch(barberAvailabilityRepositoryProvider).suggestAvailableStarts(
        barberId: p.barberId,
        duration: Duration(minutes: p.durationMin),
        limit: 2,
      );
});

final availableTimesForDayProvider =
    FutureProvider.autoDispose.family<List<TimeOfDay>, ({String barberId, DateTime day, int durationMin})>((ref, p) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  final starts = await ref.watch(barberAvailabilityRepositoryProvider).listAvailableStartsForDay(
        barberId: p.barberId,
        day: p.day,
        durationMinutes: p.durationMin,
      );
  return starts.map((dt) => TimeOfDay.fromDateTime(dt)).toList(growable: false);
});

final availableDaysForMonthProvider =
    FutureProvider.autoDispose.family<Map<DateTime, bool>, ({String barberId, int durationMin, DateTime month})>((ref, p) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(barberAvailabilityRepositoryProvider).listAvailableDaysForMonth(
        barberId: p.barberId,
        month: p.month,
        durationMinutes: p.durationMin,
      );
});
