import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../models/public_profile.dart';
import '../supabase/supabase_client_provider.dart';

class SocialProofRepository {
  final SupabaseClient _client;

  SocialProofRepository(this._client);

  Future<int> countFollowers({required String targetType, required String targetId}) async {
    try {
      return await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('target_type', targetType)
          .eq('target_id', targetId);
    } catch (e) {
      throw AppException('Failed to load followers count', cause: e);
    }
  }

  Future<int> countReviews({required String targetType, required String targetId}) async {
    try {
      return await _client
          .from('reviews')
          .count(CountOption.exact)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .eq('status', 'published');
    } catch (e) {
      throw AppException('Failed to load reviews count', cause: e);
    }
  }

  Future<int> countBookings({String? barberId, String? shopId}) async {
    try {
      if (barberId == null && shopId == null) return 0;
      var q = _client.from('bookings').count(CountOption.exact).neq('status', 'cancelled');
      if (barberId != null) q = q.eq('barber_id', barberId);
      if (shopId != null) q = q.eq('shop_id', shopId);
      return await q;
    } catch (e) {
      throw AppException('Failed to load bookings count', cause: e);
    }
  }

  Future<List<PublicProfile>> listFollowers({required String targetType, required String targetId, int limit = 50}) async {
    try {
      final data = await _client
          .from('follows')
          .select('profile_id, profiles(full_name, avatar_url, area)')
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final p = m['profiles'] as Map<String, dynamic>?;
            return PublicProfile(
              id: (m['profile_id'] as String?) ?? '',
              fullName: p?['full_name'] as String?,
              avatarUrl: p?['avatar_url'] as String?,
              area: p?['area'] as String?,
            );
          })
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (e) {
      throw AppException('Failed to load followers', cause: e);
    }
  }
}

final socialProofRepositoryProvider = Provider<SocialProofRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SocialProofRepository(client);
});

final followersCountProvider = FutureProvider.family<int, ({String targetType, String targetId})>((ref, args) async {
  return ref.watch(socialProofRepositoryProvider).countFollowers(targetType: args.targetType, targetId: args.targetId);
});

final reviewsCountProvider = FutureProvider.family<int, ({String targetType, String targetId})>((ref, args) async {
  return ref.watch(socialProofRepositoryProvider).countReviews(targetType: args.targetType, targetId: args.targetId);
});

final bookingsCountForBarberProvider = FutureProvider.family<int, String>((ref, barberId) async {
  return ref.watch(socialProofRepositoryProvider).countBookings(barberId: barberId);
});

final bookingsCountForShopProvider = FutureProvider.family<int, String>((ref, shopId) async {
  return ref.watch(socialProofRepositoryProvider).countBookings(shopId: shopId);
});

final followersListProvider = FutureProvider.family<List<PublicProfile>, ({String targetType, String targetId})>((ref, args) async {
  return ref.watch(socialProofRepositoryProvider).listFollowers(targetType: args.targetType, targetId: args.targetId);
});
