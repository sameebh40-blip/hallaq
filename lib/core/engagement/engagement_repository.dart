import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../supabase/supabase_client_provider.dart';

class EngagementRepository {
  final SupabaseClient _client;

  EngagementRepository(this._client);

  Future<void> trackProfileView({
    required String targetType,
    required String targetId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('profile_view_events').insert({
        'target_type': targetType,
        'target_id': targetId,
        'viewer_profile_id': user.id,
      });
    } catch (e) {
      throw AppException('Failed to track view', cause: e);
    }
  }

  Future<void> trackReelView({required String reelId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('reel_view_events').insert({
        'reel_id': reelId,
        'viewer_profile_id': user.id,
      });
    } catch (e) {
      throw AppException('Failed to track view', cause: e);
    }
  }

  Future<int> countViewsToday({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final count = await _client
          .from('profile_view_events')
          .count(CountOption.exact)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .gte('created_at', start);
      return count;
    } catch (e) {
      throw AppException('Failed to load views', cause: e);
    }
  }

  Future<int> countViewsLast7Days({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final start = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
      final count = await _client
          .from('profile_view_events')
          .count(CountOption.exact)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .gte('created_at', start);
      return count;
    } catch (e) {
      throw AppException('Failed to load views', cause: e);
    }
  }

  Future<double?> getAvgResponseMinutesForBarber(String barberId) async {
    try {
      final data = await _client.from('barber_response_time_minutes').select('avg_minutes').eq('barber_id', barberId).maybeSingle();
      if (data == null) return null;
      return (data['avg_minutes'] as num?)?.toDouble();
    } catch (e) {
      throw AppException('Failed to load response time', cause: e);
    }
  }
}

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EngagementRepository(client);
});

final viewsTodayProvider = FutureProvider.family<int, ({String targetType, String targetId})>((ref, p) async {
  return ref.watch(engagementRepositoryProvider).countViewsToday(targetType: p.targetType, targetId: p.targetId);
});

final viewsWeekProvider = FutureProvider.family<int, ({String targetType, String targetId})>((ref, p) async {
  return ref.watch(engagementRepositoryProvider).countViewsLast7Days(targetType: p.targetType, targetId: p.targetId);
});

final barberAvgResponseMinutesProvider = FutureProvider.family<double?, String>((ref, barberId) async {
  return ref.watch(engagementRepositoryProvider).getAvgResponseMinutesForBarber(barberId);
});
