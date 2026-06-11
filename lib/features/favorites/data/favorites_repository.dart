import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/models/offer.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class FavoriteBarberCard {
  final Barber barber;
  final String? shopName;

  const FavoriteBarberCard({required this.barber, this.shopName});
}

class FavoritesRepository {
  final SupabaseClient _client;
  final MediaService _media;

  FavoritesRepository(this._client, this._media);

  Future<Offer> _offerWithSignedMedia(Offer o) async {
    final banner = await _media.resolveMediaUrl(bucket: 'offer-images', path: o.bannerPath, legacyUrlOrPath: o.bannerUrl);
    return Offer(
      id: o.id,
      shopId: o.shopId,
      barberId: o.barberId,
      title: o.title,
      description: o.description,
      offerType: o.offerType,
      discountPercent: o.discountPercent,
      discountAmount: o.discountAmount,
      packageDetails: o.packageDetails,
      validFrom: o.validFrom,
      validTo: o.validTo,
      active: o.active,
      bannerUrl: banner,
      bannerPath: o.bannerPath,
      createdAt: o.createdAt,
    );
  }

  Future<void> add({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('favorites').upsert({
        'profile_id': user.id,
        'target_type': targetType,
        'target_id': targetId,
      });
    } catch (e) {
      throw AppException('Failed to favorite', cause: e);
    }
  }

  Future<void> remove({required String targetType, required String targetId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('profile_id', user.id)
          .eq('target_type', targetType)
          .eq('target_id', targetId);
    } catch (e) {
      throw AppException('Failed to unfavorite', cause: e);
    }
  }

  Future<List<Barber>> listFavoriteBarbers() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final rows = await _client
          .from('favorites')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'barber');

      final ids = (rows as List).map((e) => e['target_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _client.from('barbers').select().inFilter('id', ids);
      return (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }

  Future<List<FavoriteBarberCard>> listFavoriteBarbersDetailed() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('favorites')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'barber');

      final ids = (rows as List).map((e) => e['target_id'] as String).toList();
      if (ids.isEmpty) return const [];

      final data = await _client.from('barbers').select('*, barbershops(name)').inFilter('id', ids);
      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      return list.map((m) {
        final shop = m['barbershops'] is Map ? Map<String, dynamic>.from(m['barbershops'] as Map) : null;
        return FavoriteBarberCard(
          barber: Barber.fromJson(m),
          shopName: (shop?['name'] as String?)?.trim(),
        );
      }).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }

  Future<List<Barbershop>> listFavoriteShops() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final rows = await _client
          .from('favorites')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'shop');

      final ids = (rows as List).map((e) => e['target_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _client.from('barbershops').select().inFilter('id', ids);
      return (data as List).map((e) => Barbershop.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }

  Future<List<Offer>> listFavoriteOffers() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final rows = await _client
          .from('favorites')
          .select('target_id')
          .eq('profile_id', user.id)
          .eq('target_type', 'offer');

      final ids = (rows as List).map((e) => e['target_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _client.from('offers').select().inFilter('id', ids);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_offerWithSignedMedia));
    } catch (e) {
      throw AppException('Failed to load favorites', cause: e);
    }
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final favoriteBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  return ref.watch(favoritesRepositoryProvider).listFavoriteBarbers();
});

final favoriteBarberCardsProvider = FutureProvider<List<FavoriteBarberCard>>((ref) async {
  return ref.watch(favoritesRepositoryProvider).listFavoriteBarbersDetailed();
});

final favoriteShopsProvider = FutureProvider<List<Barbershop>>((ref) async {
  return ref.watch(favoritesRepositoryProvider).listFavoriteShops();
});

final favoriteOffersProvider = FutureProvider<List<Offer>>((ref) async {
  return ref.watch(favoritesRepositoryProvider).listFavoriteOffers();
});
