import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class AdminDashboardRepository {
  final SupabaseClient _client;

  AdminDashboardRepository(this._client);

  Future<Map<String, int>> getStats() async {
    try {
      final users = await _client.from('profiles').count(CountOption.exact);
      final bookings = await _client.from('bookings').count(CountOption.exact);
      final shops = await _client.from('barbershops').count(CountOption.exact);
      final barbers = await _client.from('barbers').count(CountOption.exact);
      final reels = await _client.from('reels').count(CountOption.exact);
      return {
        'users': users,
        'bookings': bookings,
        'shops': shops,
        'barbers': barbers,
        'reels': reels,
      };
    } catch (e) {
      throw AppException('Failed to load admin stats', cause: e);
    }
  }
}

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return AdminDashboardRepository(ref.watch(supabaseClientProvider));
});

final adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(adminDashboardRepositoryProvider).getStats();
});

