import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/network/resilient_request.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../models/nearby_listings.dart';

class NearbyRepository {
  final SupabaseClient _client;
  final MediaService _media;
  final KvStore _kv;
  final bool _isOnline;

  NearbyRepository(this._client, this._media, this._kv, this._isOnline);

  static const _cacheTtlMs = 1000 * 60 * 30;
  static const _barberCardSelect =
      'id, profile_id, slug, display_name, area, address, lat, lng, avatar_url, avatar_path, cover_url, cover_path, rating_avg, rating_count, followers_count, reviews_count, is_independent, home_service, available_now, waiting_time_min, queue_length, is_verified, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, starting_price_bhd, distance_km, status, created_at, shop_id';

  Future<void> _writeCache(String key, Object value) async {
    final payload = <String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'v': value,
    };
    await _kv.write(key, jsonEncode(payload));
  }

  Future<List?> _readCacheList(String key) async {
    final raw = await _kv.read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final t = decoded['t'];
      final v = decoded['v'];
      if (t is! num) return null;
      if (DateTime.now().millisecondsSinceEpoch - t.toInt() > _cacheTtlMs) return null;
      if (v is! List) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<List<NearbyBarber>> _listFallbackBarbers({required int limit, required int offset}) async {
    Future<List> run({
      required bool withDeletedAt,
      required bool withStatus,
      required bool withIsActive,
      required bool verifiedOnly,
    }) async {
      PostgrestFilterBuilder<dynamic> q = _client.from('barbers').select(_barberCardSelect) as PostgrestFilterBuilder<dynamic>;
      if (withDeletedAt) q = q.isFilter('deleted_at', null);
      if (withStatus) q = q.eq('status', 'approved');
      if (withIsActive) q = q.eq('is_active', true);
      if (verifiedOnly) q = q.eq('is_verified', true);
      return await q.order('rating_avg', ascending: false).range(offset, offset + limit - 1);
    }

    Future<List> safeRun({
      required bool withDeletedAt,
      required bool withStatus,
      required bool withIsActive,
      required bool verifiedOnly,
    }) async {
      try {
        return await run(
          withDeletedAt: withDeletedAt,
          withStatus: withStatus,
          withIsActive: withIsActive,
          verifiedOnly: verifiedOnly,
        );
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''}'.toLowerCase();
        return run(
          withDeletedAt: withDeletedAt && !msg.contains('deleted_at'),
          withStatus: withStatus && !msg.contains('status'),
          withIsActive: withIsActive && !msg.contains('is_active'),
          verifiedOnly: verifiedOnly && !msg.contains('is_verified'),
        );
      }
    }

    List data = await safeRun(withDeletedAt: true, withStatus: true, withIsActive: true, verifiedOnly: true);
    if (data.isEmpty) {
      data = await safeRun(withDeletedAt: true, withStatus: true, withIsActive: true, verifiedOnly: false);
    }
    if (data.isEmpty) {
      data = await safeRun(withDeletedAt: true, withStatus: true, withIsActive: false, verifiedOnly: false);
    }
    final resolved = <NearbyBarber>[];
    for (final row in data) {
      final map = Map<String, dynamic>.from(row as Map);
      final avatar = await _media.resolveMediaUrl(
        bucket: 'barber-images',
        path: map['avatar_path'] as String?,
        legacyUrlOrPath: map['avatar_url'] as String?,
      );
      final cover = await _media.resolveMediaUrl(
        bucket: 'barber-images',
        path: map['cover_path'] as String?,
        legacyUrlOrPath: map['cover_url'] as String?,
      );
      map['avatar_url'] = avatar ?? map['avatar_url'];
      map['cover_url'] = cover ?? map['cover_url'];
      resolved.add(
        NearbyBarber.fromJson({
          ...map,
          'distance_km': null,
        }),
      );
    }
    return resolved;
  }

  Future<List<NearbyShop>> listNearbyShops({
    required double lat,
    required double lng,
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'cache:nearby_shops:lat=${lat.toStringAsFixed(3)}:lng=${lng.toStringAsFixed(3)}:limit=$limit:offset=$offset';
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        return cached.map((e) => NearbyShop.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await resilientRequest(() => _client.rpc('list_nearby_shops', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_limit': limit,
        'p_offset': offset,
      }));
      try {
        await _writeCache(cacheKey, data);
      } catch (_) {}
      return (data as List).map((e) => NearbyShop.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        return cached.map((e) => NearbyShop.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
      }
      throw AppException('Failed to load nearby shops', cause: e);
    }
  }

  Future<List<NearbyBarber>> listNearbyBarbers({
    required double lat,
    required double lng,
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'cache:nearby_barbers:lat=${lat.toStringAsFixed(3)}:lng=${lng.toStringAsFixed(3)}:limit=$limit:offset=$offset';
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        return cached.map((e) => NearbyBarber.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await resilientRequest(() => _client.rpc('list_nearby_barbers', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_limit': limit,
        'p_offset': offset,
      }));
      try {
        await _writeCache(cacheKey, data);
      } catch (_) {}
      final list = (data as List).map((e) => NearbyBarber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      if (list.isNotEmpty) return list;
      return _listFallbackBarbers(limit: limit, offset: offset);
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        return cached.map((e) => NearbyBarber.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
      }
      try {
        return await _listFallbackBarbers(limit: limit, offset: offset);
      } catch (_) {
        throw AppException('Failed to load nearby barbers', cause: e);
      }
    }
  }
}

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return NearbyRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(mediaServiceProvider),
    ref.watch(kvStoreProvider),
    ref.watch(networkOnlineProvider),
  );
});
