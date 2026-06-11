import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class EarningsRepository {
  final SupabaseClient _client;

  EarningsRepository(this._client);

  Future<List<Map<String, dynamic>>> listBarberDaily(String barberId, {int days = 30}) async {
    try {
      final since = DateTime.now().toUtc().subtract(Duration(days: days));
      final data = await _client
          .from('barber_revenue_daily')
          .select('day, currency, gross_revenue, payments_count')
          .eq('barber_id', barberId)
          .gte('day', since.toIso8601String())
          .order('day', ascending: false);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load earnings', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listShopDaily(String shopId, {int days = 30}) async {
    try {
      final since = DateTime.now().toUtc().subtract(Duration(days: days));
      final data = await _client
          .from('shop_revenue_daily')
          .select('day, currency, gross_revenue, payments_count')
          .eq('shop_id', shopId)
          .gte('day', since.toIso8601String())
          .order('day', ascending: false);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw AppException('Failed to load earnings', cause: e);
    }
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(supabaseClientProvider));
});

