import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/offer.dart';
import '../../../core/network/network_status.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class OffersRepository {
  final SupabaseClient _client;
  final MediaService _media;
  final KvStore _kv;
  final bool _isOnline;

  OffersRepository(this._client, this._media, this._kv, this._isOnline);

  static const _cacheTtlMs = 1000 * 60 * 15;

  String _cacheKey(String name, {Map<String, Object?> params = const {}}) {
    final b = StringBuffer('cache:$name');
    for (final e in params.entries) {
      b.write(':${e.key}=${e.value ?? ''}');
    }
    return b.toString();
  }

  Future<void> _writeCache(String key, Object value) async {
    final payload = <String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'v': value,
    };
    await _kv.write(key, jsonEncode(payload));
  }

  Future<List<dynamic>?> _readCacheList(String key) async {
    final raw = await _kv.read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final t = (payload['t'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - t > _cacheTtlMs) return null;
      final v = payload['v'];
      return v is List ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<Offer> _withSignedMedia(Offer o) async {
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

  Future<List<Offer>> listActive({int limit = 20}) async {
    final cacheKey = _cacheKey('offers_active', params: {'limit': limit});
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return Future.wait(list.map(_withSignedMedia));
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await _client
          .from('offers')
          .select()
          .eq('active', true)
          .eq('is_active', true)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      await _writeCache(cacheKey, data);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return Future.wait(list.map(_withSignedMedia));
      }
      throw AppException('Failed to load offers', cause: e);
    }
  }

  Future<List<Offer>> listActiveForCity(String cityId, {int limit = 20}) async {
    final cacheKey = _cacheKey('offers_active_city', params: {'cityId': cityId, 'limit': limit});
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return Future.wait(list.map(_withSignedMedia));
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await _client
          .from('offers')
          .select('*, barbershops!left(city_id), barbers!left(city_id)')
          .eq('active', true)
          .eq('is_active', true)
          .eq('status', 'approved')
          .or('barbershops.city_id.eq.$cityId,barbers.city_id.eq.$cityId')
          .order('created_at', ascending: false)
          .limit(limit);
      await _writeCache(cacheKey, data);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return Future.wait(list.map(_withSignedMedia));
      }
      throw AppException('Failed to load offers', cause: e);
    }
  }

  Future<List<Offer>> listActiveForShop(String shopId, {int limit = 20}) async {
    try {
      final data = await _client
          .from('offers')
          .select()
          .eq('shop_id', shopId)
          .eq('active', true)
          .eq('is_active', true)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load offers', cause: e);
    }
  }

  Future<Offer?> getById(String offerId) async {
    final id = offerId.trim();
    if (id.isEmpty) return null;
    try {
      final data = await _client.from('offers').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return _withSignedMedia(Offer.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to load offer', cause: e);
    }
  }
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider), ref.watch(kvStoreProvider), ref.watch(networkOnlineProvider));
});

final activeOffersProvider = FutureProvider<List<Offer>>((ref) async {
  return ref.watch(offersRepositoryProvider).listActive();
});

final activeOffersForCityProvider = FutureProvider.family<List<Offer>, String>((ref, cityId) async {
  return ref.watch(offersRepositoryProvider).listActiveForCity(cityId);
});

final activeOffersForShopProvider = FutureProvider.family<List<Offer>, String>((ref, shopId) async {
  return ref.watch(offersRepositoryProvider).listActiveForShop(shopId);
});

final offerByIdProvider = FutureProvider.autoDispose.family<Offer?, String>((ref, offerId) async {
  return ref.watch(offersRepositoryProvider).getById(offerId);
});
