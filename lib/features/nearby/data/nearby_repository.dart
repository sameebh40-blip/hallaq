import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class NearbyRepository {
  final SupabaseClient _client;

  NearbyRepository(this._client);

  Future<List<Barbershop>> listMappableShops({int limit = 100}) async {
    try {
      final data = await _client
          .from('barbershops')
          .select()
          .not('lat', 'is', null)
          .not('lng', 'is', null)
          .limit(limit);
      return (data as List).map((e) => Barbershop.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load nearby shops', cause: e);
    }
  }
}

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return NearbyRepository(ref.watch(supabaseClientProvider));
});

final mappableShopsProvider = FutureProvider<List<Barbershop>>((ref) async {
  return ref.watch(nearbyRepositoryProvider).listMappableShops();
});

