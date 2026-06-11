import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class FollowedBarberCard {
  final Barber barber;
  final String? shopName;

  const FollowedBarberCard({required this.barber, this.shopName});
}

class FollowFavoritesRepository {
  final SupabaseClient _client;

  FollowFavoritesRepository(this._client);

  Future<void> unfollow({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('follows').delete().eq('profile_id', user.id).eq('target_type', targetType).eq('target_id', targetId);
    } catch (e) {
      throw AppException('Failed to remove favorite', cause: e);
    }
  }

  Future<List<FollowedBarberCard>> listBarbers({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('follows')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'barber')
          .order('created_at', ascending: false)
          .limit(limit);

      final barberIds = (rows as List).map((e) => e['target_id'] as String).toList(growable: false);
      if (barberIds.isEmpty) return const [];

      final barberRows = await _client.from('barbers').select().inFilter('id', barberIds);
      final barbers = (barberRows as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);

      final shopIds = barbers.map((b) => b.shopId).whereType<String>().toSet().toList(growable: false);
      final shopNameById = <String, String>{};
      if (shopIds.isNotEmpty) {
        final shops = await _client.from('barbershops').select('id,name').inFilter('id', shopIds);
        for (final s in (shops as List)) {
          final m = Map<String, dynamic>.from(s as Map);
          final id = (m['id'] as String?) ?? '';
          final name = (m['name'] as String?) ?? '';
          if (id.isNotEmpty) shopNameById[id] = name;
        }
      }

      final byId = {for (final b in barbers) b.id: b};
      return barberIds
          .map((id) {
            final b = byId[id];
            if (b == null) return null;
            return FollowedBarberCard(barber: b, shopName: b.shopId == null ? null : shopNameById[b.shopId!]);
          })
          .whereType<FollowedBarberCard>()
          .toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }

  Future<List<Barbershop>> listShops({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('follows')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'shop')
          .order('created_at', ascending: false)
          .limit(limit);

      final shopIds = (rows as List).map((e) => e['target_id'] as String).toList(growable: false);
      if (shopIds.isEmpty) return const [];

      final data = await _client.from('barbershops').select().inFilter('id', shopIds);
      return (data as List).map((e) => Barbershop.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }
}

final followFavoritesRepositoryProvider = Provider<FollowFavoritesRepository>((ref) {
  return FollowFavoritesRepository(ref.watch(supabaseClientProvider));
});

final followedBarbersProvider = FutureProvider<List<FollowedBarberCard>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(followFavoritesRepositoryProvider).listBarbers();
});

final followedShopsProvider = FutureProvider<List<Barbershop>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(followFavoritesRepositoryProvider).listShops();
});

