import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class BarberScheduleRepository {
  final SupabaseClient _client;

  BarberScheduleRepository(this._client);

  Future<List<Map<String, dynamic>>> listWorkingHours(String barberId) async {
    try {
      final data = await _client
          .from('barber_working_hours')
          .select('id, weekday, start_time, end_time, enabled')
          .eq('barber_id', barberId)
          .order('weekday', ascending: true)
          .order('start_time', ascending: true);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load working hours', cause: e);
    }
  }

  Future<void> upsertWorkingHour({
    required String barberId,
    required int weekday,
    required String startTime,
    required String endTime,
    required bool enabled,
  }) async {
    try {
      await _client.from('barber_working_hours').upsert({
        'barber_id': barberId,
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
        'enabled': enabled,
      });
    } catch (e) {
      throw AppException('Failed to save working hours', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listTimeOff(String barberId) async {
    try {
      final data = await _client
          .from('barber_time_off')
          .select('id, starts_at, ends_at, reason, created_at')
          .eq('barber_id', barberId)
          .order('starts_at', ascending: false);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load time off', cause: e);
    }
  }

  Future<void> addTimeOff({
    required String barberId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) async {
    try {
      await _client.from('barber_time_off').insert({
        'barber_id': barberId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'reason': (reason ?? '').trim().isEmpty ? null : reason?.trim(),
      });
    } catch (e) {
      throw AppException('Failed to add time off', cause: e);
    }
  }

  Future<void> deleteTimeOff(String id) async {
    try {
      await _client.from('barber_time_off').delete().eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete time off', cause: e);
    }
  }
}

final barberScheduleRepositoryProvider = Provider<BarberScheduleRepository>((ref) {
  return BarberScheduleRepository(ref.watch(supabaseClientProvider));
});

