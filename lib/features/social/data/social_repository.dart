import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class SocialRepository {
  final SupabaseClient _client;

  SocialRepository(this._client);

  Future<int> countMyFollowing() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      return await _client.from('follows').count(CountOption.exact).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to load following count', cause: e);
    }
  }

  Future<bool> isFollowing({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final data = await _client
          .from('follows')
          .select('id')
          .eq('profile_id', user.id)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw AppException('Failed to check follow state', cause: e);
    }
  }

  Future<void> follow({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('follows').upsert({
        'profile_id': user.id,
        'target_type': targetType,
        'target_id': targetId,
      });
    } catch (e) {
      throw AppException('Failed to follow', cause: e);
    }
  }

  Future<void> unfollow({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('follows').delete().eq('profile_id', user.id).eq('target_type', targetType).eq('target_id', targetId);
    } catch (e) {
      throw AppException('Failed to unfollow', cause: e);
    }
  }

  Future<bool> isFollowingBarber(String barberId) async {
    return isFollowing(targetType: 'barber', targetId: barberId);
  }

  Future<void> followBarber(String barberId) async {
    return follow(targetType: 'barber', targetId: barberId);
  }

  Future<void> unfollowBarber(String barberId) async {
    return unfollow(targetType: 'barber', targetId: barberId);
  }

  Future<bool> isFollowingShop(String shopId) async {
    return isFollowing(targetType: 'shop', targetId: shopId);
  }

  Future<void> followShop(String shopId) async {
    return follow(targetType: 'shop', targetId: shopId);
  }

  Future<void> unfollowShop(String shopId) async {
    return unfollow(targetType: 'shop', targetId: shopId);
  }
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final isFollowingBarberProvider = FutureProvider.family<bool, String>((ref, barberId) async {
  return ref.watch(socialRepositoryProvider).isFollowingBarber(barberId);
});

final isFollowingShopProvider = FutureProvider.family<bool, String>((ref, shopId) async {
  return ref.watch(socialRepositoryProvider).isFollowingShop(shopId);
});

final myFollowingCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(socialRepositoryProvider).countMyFollowing();
});
