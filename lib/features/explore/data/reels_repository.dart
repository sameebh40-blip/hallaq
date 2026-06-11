import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/reel.dart';
import '../../../core/network/network_status.dart';
import '../../../core/network/resilient_request.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../models/explore_reel.dart';
import '../../barber/data/barber_repository.dart';

class ReelsRepository {
  final SupabaseClient _client;
  final MediaService _media;
  final KvStore _kv;
  final bool _isOnline;

  ReelsRepository(this._client, this._media, this._kv, this._isOnline);

  static const _cacheTtlMs = 1000 * 60 * 60 * 6;
  bool _supportsBucketColumns = true;

  String _selectExploreCore() {
    if (_supportsBucketColumns) {
      return 'id, status, rejection_reason, barber_id, shop_id, media_type, media_url, media_path, media_bucket, thumbnail_url, thumbnail_path, thumbnail_bucket, caption, location, hashtags, likes_count, comments_count, saves_count, shares_count, created_at';
    }
    return 'id, status, rejection_reason, barber_id, shop_id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, location, hashtags, likes_count, comments_count, saves_count, shares_count, created_at';
  }

  String _selectExploreWithJoins() {
    return '${_selectExploreCore()}, barbers(id, slug, display_name, avatar_url, area, address, lat, lng, is_verified, badge_verified, shop_id, barbershops(id, name, logo_url, area, address, lat, lng, is_verified, badge_verified)), barbershops(id, name, logo_url, area, address, lat, lng, is_verified, badge_verified)';
  }

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

  ExploreReel _mapExploreRow(Map<String, dynamic> m) {
    final barberId = m['barber_id'] as String?;
    final shopId = m['shop_id'] as String?;
    final status = m['status'] as String?;
    final rejectionReason = m['rejection_reason'] as String?;

    final barberRaw = m['barbers'];
    final barber = barberRaw is Map ? Map<String, dynamic>.from(barberRaw) : <String, dynamic>{};
    final barberShopRaw = barber['barbershops'];
    final barberShop = barberShopRaw is Map ? Map<String, dynamic>.from(barberShopRaw) : <String, dynamic>{};

    final postShopRaw = m['barbershops'];
    final postShop = postShopRaw is Map ? Map<String, dynamic>.from(postShopRaw) : <String, dynamic>{};

    final isBarberPost = barberId != null && barberId.isNotEmpty;

    return ExploreReel(
      reel: Reel.fromJson(m),
      author: ExploreAuthor(
        type: isBarberPost ? ExploreAuthorType.barber : ExploreAuthorType.shop,
        id: isBarberPost ? ((barber['id'] as String?) ?? barberId) : ((postShop['id'] as String?) ?? (shopId ?? '')),
        slug: isBarberPost
            ? ((barber['slug'] as String?) ?? ((barber['id'] as String?) ?? barberId))
            : ((postShop['id'] as String?) ?? (shopId ?? '')),
        displayName: isBarberPost ? ((barber['display_name'] as String?) ?? '') : ((postShop['name'] as String?) ?? ''),
        avatarUrl: isBarberPost ? (barber['avatar_url'] as String?) : (postShop['logo_url'] as String?),
        area: isBarberPost ? (barber['area'] as String?) : (postShop['area'] as String?),
        address: isBarberPost ? ((barber['address'] as String?) ?? (barberShop['address'] as String?)) : (postShop['address'] as String?),
        lat: isBarberPost ? ((barber['lat'] as num?)?.toDouble() ?? (barberShop['lat'] as num?)?.toDouble()) : (postShop['lat'] as num?)?.toDouble(),
        lng: isBarberPost ? ((barber['lng'] as num?)?.toDouble() ?? (barberShop['lng'] as num?)?.toDouble()) : (postShop['lng'] as num?)?.toDouble(),
        verified: isBarberPost
            ? ((barber['is_verified'] as bool?) ?? (barber['badge_verified'] as bool?) ?? false)
            : ((postShop['is_verified'] as bool?) ?? (postShop['badge_verified'] as bool?) ?? false),
        shopId: isBarberPost ? (barber['shop_id'] as String?) : null,
        shopName: isBarberPost ? (barberShop['name'] as String?) : null,
      ),
      status: status ?? 'approved',
      rejectionReason: rejectionReason,
      isLiked: false,
      isSaved: false,
      isFollowing: false,
    );
  }

  Future<Reel> _withSignedMedia(Reel r) async {
    final mediaBucket = (r.mediaBucket ?? '').trim();
    final thumbBucket = (r.thumbnailBucket ?? '').trim();
    final media = mediaBucket.isNotEmpty
        ? await _media.resolveMediaUrl(bucket: mediaBucket, path: r.mediaPath, legacyUrlOrPath: r.mediaUrl)
        : await _media.resolveMediaUrlMulti(
            buckets: const ['reels', 'reels-media'],
            path: r.mediaPath,
            legacyUrlOrPath: r.mediaUrl,
          );
    final thumb = thumbBucket.isNotEmpty
        ? await _media.resolveMediaUrl(bucket: thumbBucket, path: r.thumbnailPath, legacyUrlOrPath: r.thumbnailUrl)
        : await _media.resolveMediaUrlMulti(
            buckets: const ['reels', 'reels-media'],
            path: r.thumbnailPath,
            legacyUrlOrPath: r.thumbnailUrl,
          );
    final resolvedMedia = media ?? r.mediaUrl;
    if (kIsWeb && r.mediaType == 'video') {
      final ref = ((r.mediaPath ?? '').trim().isNotEmpty ? r.mediaPath! : resolvedMedia).toLowerCase();
      if (!ref.contains('.mp4')) {
        final fallback = (thumb ?? '').trim().isNotEmpty ? thumb! : resolvedMedia;
        return r.copyWith(mediaType: 'image', mediaUrl: fallback, thumbnailUrl: thumb);
      }
    }
    return r.copyWith(mediaUrl: resolvedMedia, thumbnailUrl: thumb);
  }

  Future<List<ExploreReel>> _signExploreList(List<ExploreReel> list) async {
    if (list.isEmpty) return list;

    final barberIds = list.where((e) => e.author.type == ExploreAuthorType.barber).map((e) => e.author.id).toSet().toList();
    final shopIds = list.where((e) => e.author.type == ExploreAuthorType.shop).map((e) => e.author.id).toSet().toList();

    final barberAvatars = <String, String?>{};
    if (barberIds.isNotEmpty) {
      try {
        final rows = await _client.from('barbers').select('id, avatar_url, avatar_path').inFilter('id', barberIds);
        for (final row in (rows as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          barberAvatars[id] = await _media.resolveMediaUrl(
            bucket: 'barber-images',
            path: m['avatar_path'] as String?,
            legacyUrlOrPath: m['avatar_url'] as String?,
          );
        }
      } catch (_) {}
    }

    final shopLogos = <String, String?>{};
    if (shopIds.isNotEmpty) {
      try {
        final rows = await _client.from('barbershops').select('id, logo_url, logo_path').inFilter('id', shopIds);
        for (final row in (rows as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          shopLogos[id] = await _media.resolveMediaUrl(
            bucket: 'shop-images',
            path: m['logo_path'] as String?,
            legacyUrlOrPath: m['logo_url'] as String?,
          );
        }
      } catch (_) {}
    }

    final out = <ExploreReel>[];
    for (final e in list) {
      final reel = await _withSignedMedia(e.reel);
      final avatarUrl = e.author.type == ExploreAuthorType.barber ? barberAvatars[e.author.id] : shopLogos[e.author.id];
      out.add(
        e.copyWith(
          reel: reel,
          author: ExploreAuthor(
            type: e.author.type,
            id: e.author.id,
            slug: e.author.slug,
            displayName: e.author.displayName,
            verified: e.author.verified,
            avatarUrl: avatarUrl ?? e.author.avatarUrl,
            area: e.author.area,
            address: e.author.address,
            lat: e.author.lat,
            lng: e.author.lng,
            shopId: e.author.shopId,
            shopName: e.author.shopName,
          ),
        ),
      );
    }
    return out;
  }

  bool _maybeMissingColumn(Object e, String column) {
    if (e is PostgrestException) {
      final msg = e.message;
      final details = e.details;
      return msg.contains(column) || (details?.toString().contains(column) ?? false);
    }
    return e.toString().contains(column);
  }

  Future<List<ExploreReel>> _listExploreFeedFallback({int limit = 30, DateTime? before}) async {
    var baseQuery = _client.from('reels').select(_selectExploreCore()).eq('status', 'approved');

    if (before != null) {
      baseQuery = baseQuery.lt('created_at', before.toIso8601String());
    }

    List data;
    try {
      data = await baseQuery.isFilter('deleted_at', null).order('created_at', ascending: false).limit(limit);
    } catch (e) {
      if (_supportsBucketColumns && (_maybeMissingColumn(e, 'media_bucket') || _maybeMissingColumn(e, 'thumbnail_bucket'))) {
        _supportsBucketColumns = false;
        var retry = _client.from('reels').select(_selectExploreCore()).eq('status', 'approved');
        if (before != null) {
          retry = retry.lt('created_at', before.toIso8601String());
        }
        try {
          data = await retry.isFilter('deleted_at', null).order('created_at', ascending: false).limit(limit);
        } catch (_) {
          data = await retry.order('created_at', ascending: false).limit(limit);
        }
      } else {
        data = await baseQuery.order('created_at', ascending: false).limit(limit);
      }
    }

    final rows = data.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);

    final barberIds = rows.map((r) => (r['barber_id'] as String?) ?? '').where((e) => e.isNotEmpty).toSet().toList(growable: false);
    final shopIdsDirect = rows.map((r) => (r['shop_id'] as String?) ?? '').where((e) => e.isNotEmpty).toSet().toList(growable: false);

    final barbersById = <String, Map<String, dynamic>>{};
    if (barberIds.isNotEmpty) {
      try {
        final barbers = await _client
            .from('barbers')
            .select('id, slug, display_name, avatar_url, avatar_path, area, address, lat, lng, is_verified, badge_verified, shop_id')
            .inFilter('id', barberIds);
        for (final b in (barbers as List)) {
          final m = Map<String, dynamic>.from(b as Map);
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          barbersById[id] = m;
        }
      } catch (_) {}
    }

    final shopIdsFromBarbers = barbersById.values.map((b) => (b['shop_id'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();
    final allShopIds = {...shopIdsDirect, ...shopIdsFromBarbers}.toList(growable: false);

    final shopsById = <String, Map<String, dynamic>>{};
    if (allShopIds.isNotEmpty) {
      try {
        final shops = await _client.from('barbershops').select('id, name, logo_url, logo_path, area, address, lat, lng, is_verified, badge_verified').inFilter('id', allShopIds);
        for (final s in (shops as List)) {
          final m = Map<String, dynamic>.from(s as Map);
          final id = (m['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          shopsById[id] = m;
        }
      } catch (_) {}
    }

    final base = rows.map((m) {
      final barberId = m['barber_id'] as String?;
      final shopId = m['shop_id'] as String?;
      final status = m['status'] as String?;
      final rejectionReason = m['rejection_reason'] as String?;
      final isBarberPost = barberId != null && barberId.isNotEmpty;

      if (isBarberPost) {
        final barber = barbersById[barberId] ?? <String, dynamic>{};
        final barberShopId = barber['shop_id'] as String?;
        final shop = (barberShopId != null && barberShopId.isNotEmpty) ? (shopsById[barberShopId] ?? <String, dynamic>{}) : <String, dynamic>{};

        return ExploreReel(
          reel: Reel.fromJson(m),
          author: ExploreAuthor(
            type: ExploreAuthorType.barber,
            id: (barber['id'] as String?) ?? barberId,
            slug: (barber['slug'] as String?) ?? ((barber['id'] as String?) ?? barberId),
            displayName: (barber['display_name'] as String?) ?? '',
            avatarUrl: barber['avatar_url'] as String?,
            area: barber['area'] as String?,
            address: (barber['address'] as String?) ?? (shop['address'] as String?),
            lat: (barber['lat'] as num?)?.toDouble() ?? (shop['lat'] as num?)?.toDouble(),
            lng: (barber['lng'] as num?)?.toDouble() ?? (shop['lng'] as num?)?.toDouble(),
            verified: (barber['is_verified'] as bool?) ?? (barber['badge_verified'] as bool?) ?? false,
            shopId: barberShopId,
            shopName: shop['name'] as String?,
          ),
          status: status ?? 'approved',
          rejectionReason: rejectionReason,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
        );
      }

      final shop = (shopId != null && shopId.isNotEmpty) ? (shopsById[shopId] ?? <String, dynamic>{}) : <String, dynamic>{};
      return ExploreReel(
        reel: Reel.fromJson(m),
        author: ExploreAuthor(
          type: ExploreAuthorType.shop,
          id: (shop['id'] as String?) ?? (shopId ?? ''),
          slug: (shop['id'] as String?) ?? (shopId ?? ''),
          displayName: (shop['name'] as String?) ?? '',
          avatarUrl: shop['logo_url'] as String?,
          area: shop['area'] as String?,
          address: shop['address'] as String?,
          lat: (shop['lat'] as num?)?.toDouble(),
          lng: (shop['lng'] as num?)?.toDouble(),
          verified: (shop['is_verified'] as bool?) ?? (shop['badge_verified'] as bool?) ?? false,
        ),
        status: status ?? 'approved',
        rejectionReason: rejectionReason,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
      );
    }).toList(growable: false);

    return base;
  }

  Future<List<ExploreReel>> listExploreFeed({int limit = 30, DateTime? before}) async {
    final viewerId = _client.auth.currentUser?.id ?? '';
    final cacheKey = _cacheKey(
      'explore_feed',
      params: {
        'limit': limit,
        'before': before?.millisecondsSinceEpoch ?? 0,
        'viewer': viewerId,
      },
    );
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final base = cached.map((e) => _mapExploreRow(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return _signExploreList(base);
      }
      throw const AppException('Offline mode');
    }
    try {
      List<ExploreReel> base;
      try {
        try {
          var query = _client
              .from('posts')
              .select(_selectExploreWithJoins())
              .eq('status', 'approved')
              .eq('is_active', true)
              .or('media_url.not.is.null,media_path.not.is.null')
              .isFilter('deleted_at', null);

          if (before != null) {
            query = query.lt('created_at', before.toIso8601String());
          }

          final data = await resilientRequest(() => query.order('created_at', ascending: false).limit(limit));
          await _writeCache(cacheKey, data);
          base = (data as List).map((e) => _mapExploreRow(Map<String, dynamic>.from(e))).toList(growable: false);
        } catch (_) {
          Future<List> fetch({required bool withActive}) async {
            var query = _client
                .from('reels')
                .select(_selectExploreWithJoins())
                .eq('status', 'approved')
                .or('media_url.not.is.null,media_path.not.is.null')
                .isFilter('deleted_at', null);

            if (withActive) {
              query = query.eq('is_active', true);
            }

            if (before != null) {
              query = query.lt('created_at', before.toIso8601String());
            }
            return await resilientRequest(() => query.order('created_at', ascending: false).limit(limit));
          }

          List data;
          try {
            data = await fetch(withActive: true);
          } catch (e) {
            if (_maybeMissingColumn(e, 'is_active')) {
              data = await fetch(withActive: false);
            } else {
              rethrow;
            }
          }
          await _writeCache(cacheKey, data);
          base = data
              .whereType<Map>()
              .map((e) => _mapExploreRow(Map<String, dynamic>.from(e)))
              .toList(growable: false);
        }
      } catch (e) {
        if (_supportsBucketColumns && (_maybeMissingColumn(e, 'media_bucket') || _maybeMissingColumn(e, 'thumbnail_bucket'))) {
          _supportsBucketColumns = false;
        }
        try {
          base = await _listExploreFeedFallback(limit: limit, before: before);
        } catch (_) {
          rethrow;
        }
      }

      final user = _client.auth.currentUser;
      base = base.where((e) {
        final r = e.reel;
        return ((r.mediaPath ?? '').trim().isNotEmpty) || (r.mediaUrl.trim().isNotEmpty);
      }).toList(growable: false);
      if (kDebugMode) {
        debugPrint('[Explore] discover_query_count=${base.length}');
        for (final e in base.take(5)) {
          final r = e.reel;
          final hasThumb = ((r.thumbnailPath ?? '').trim().isNotEmpty) || ((r.thumbnailUrl ?? '').trim().isNotEmpty);
          final hasMedia = ((r.mediaPath ?? '').trim().isNotEmpty) || (r.mediaUrl.trim().isNotEmpty);
          debugPrint('[Explore] reel id=${r.id} media_type=${r.mediaType} media_url_loaded=$hasMedia thumbnail_exists=$hasThumb');
        }
      }
      if (base.isEmpty) return <ExploreReel>[];
      if (user == null) return _signExploreList(base);

      final reelIds = base.map((e) => e.reel.id).toList();
      try {
        final hideRows = await _client.from('reel_hides').select('reel_id').eq('profile_id', user.id).inFilter('reel_id', reelIds);
        final hideSet = (hideRows as List).map((e) => e['reel_id'] as String).toSet();
        if (hideSet.isNotEmpty) {
          base = base.where((e) => !hideSet.contains(e.reel.id)).toList(growable: false);
          if (base.isEmpty) return <ExploreReel>[];
        }
      } catch (_) {}
      final barberIds = base.where((e) => e.author.type == ExploreAuthorType.barber).map((e) => e.author.id).toSet().toList();
      final shopIds = base.where((e) => e.author.type == ExploreAuthorType.shop).map((e) => e.author.id).toSet().toList();


      final liked = <String>{};
      try {
        final likedRows =
            await _client.from('reel_likes').select('reel_id').eq('profile_id', user.id).inFilter('reel_id', reelIds);
        liked.addAll((likedRows as List).map((e) => e['reel_id'] as String));
      } catch (_) {}

      final saved = <String>{};
      try {
        final savedRows =
            await _client.from('reel_saves').select('reel_id').eq('profile_id', user.id).inFilter('reel_id', reelIds);
        saved.addAll((savedRows as List).map((e) => e['reel_id'] as String));
      } catch (_) {}

      final followingBarbers = <String>{};
      if (barberIds.isNotEmpty) {
        try {
          final followRows = await _client
              .from('follows')
              .select('target_id')
              .eq('profile_id', user.id)
              .eq('target_type', 'barber')
              .inFilter('target_id', barberIds);
          followingBarbers.addAll((followRows as List).map((e) => e['target_id'] as String));
        } catch (_) {}
      }

      final followingShops = <String>{};
      if (shopIds.isNotEmpty) {
        try {
          final followRows = await _client
              .from('follows')
              .select('target_id')
              .eq('profile_id', user.id)
              .eq('target_type', 'shop')
              .inFilter('target_id', shopIds);
          followingShops.addAll((followRows as List).map((e) => e['target_id'] as String));
        } catch (_) {}
      }

      final withFlags = base
          .map(
            (e) => e.copyWith(
              isLiked: liked.contains(e.reel.id),
              isSaved: saved.contains(e.reel.id),
              isFollowing: e.author.type == ExploreAuthorType.barber
                  ? followingBarbers.contains(e.author.id)
                  : followingShops.contains(e.author.id),
            ),
          )
          .toList(growable: false);

      return _signExploreList(withFlags);
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final base = cached.map((e) => _mapExploreRow(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        return _signExploreList(base);
      }
      throw AppException('Failed to load reels', cause: e);
    }
  }

  Future<List<ExploreReel>> listMyUploadsFeed({int limit = 30, DateTime? before}) async {
    final user = _client.auth.currentUser;
    if (user == null) return <ExploreReel>[];

    List<String> shopIds = const [];
    try {
      final data = await _client.from('barbershops').select('id').eq('owner_profile_id', user.id);
      shopIds = (data as List)
          .map((e) => (e as Map)['id'] as String?)
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } catch (_) {}

    List<String> barberIds = const [];
    try {
      final data = await _client.from('barbers').select('id').eq('profile_id', user.id);
      barberIds = (data as List)
          .map((e) => (e as Map)['id'] as String?)
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } catch (_) {}

    if (shopIds.isEmpty && barberIds.isEmpty) return <ExploreReel>[];

    try {
      final select = _selectExploreWithJoins();
      Future<List> queryForShops() async {
        if (shopIds.isEmpty) return const [];
        try {
          var q = _client.from('posts').select(select).inFilter('shop_id', shopIds).isFilter('deleted_at', null);
          if (before != null) q = q.lt('created_at', before.toIso8601String());
          return await q.order('created_at', ascending: false).limit(limit);
        } catch (_) {
          var q = _client.from('reels').select(select).inFilter('shop_id', shopIds).isFilter('deleted_at', null);
          if (before != null) q = q.lt('created_at', before.toIso8601String());
          return await q.order('created_at', ascending: false).limit(limit);
        }
      }

      Future<List> queryForBarbers() async {
        if (barberIds.isEmpty) return const [];
        try {
          var q = _client.from('posts').select(select).inFilter('barber_id', barberIds).isFilter('deleted_at', null);
          if (before != null) q = q.lt('created_at', before.toIso8601String());
          return await q.order('created_at', ascending: false).limit(limit);
        } catch (_) {
          var q = _client.from('reels').select(select).inFilter('barber_id', barberIds).isFilter('deleted_at', null);
          if (before != null) q = q.lt('created_at', before.toIso8601String());
          return await q.order('created_at', ascending: false).limit(limit);
        }
      }

      final shopRows = await queryForShops();
      final barberRows = await queryForBarbers();

      final mapped = <ExploreReel>[];
      for (final row in [...shopRows, ...barberRows]) {
        final m = Map<String, dynamic>.from(row as Map);
        final barberId = m['barber_id'] as String?;
        final shopId = m['shop_id'] as String?;
        final status = m['status'] as String?;
        final rejectionReason = m['rejection_reason'] as String?;

        final barberRaw = m['barbers'];
        final barber = barberRaw is Map ? Map<String, dynamic>.from(barberRaw) : <String, dynamic>{};
        final barberShopRaw = barber['barbershops'];
        final barberShop = barberShopRaw is Map ? Map<String, dynamic>.from(barberShopRaw) : <String, dynamic>{};

        final postShopRaw = m['barbershops'];
        final postShop = postShopRaw is Map ? Map<String, dynamic>.from(postShopRaw) : <String, dynamic>{};

        final isBarberPost = barberId != null && barberId.isNotEmpty;

        mapped.add(
          ExploreReel(
            reel: Reel.fromJson(m),
            author: ExploreAuthor(
              type: isBarberPost ? ExploreAuthorType.barber : ExploreAuthorType.shop,
              id: isBarberPost ? ((barber['id'] as String?) ?? barberId) : ((postShop['id'] as String?) ?? (shopId ?? '')),
              slug: isBarberPost
                  ? ((barber['slug'] as String?) ?? ((barber['id'] as String?) ?? barberId))
                  : ((postShop['id'] as String?) ?? (shopId ?? '')),
              displayName: isBarberPost ? ((barber['display_name'] as String?) ?? '') : ((postShop['name'] as String?) ?? ''),
              avatarUrl: isBarberPost ? (barber['avatar_url'] as String?) : (postShop['logo_url'] as String?),
              area: isBarberPost ? (barber['area'] as String?) : (postShop['area'] as String?),
              address: isBarberPost ? ((barber['address'] as String?) ?? (barberShop['address'] as String?)) : (postShop['address'] as String?),
              lat: isBarberPost ? ((barber['lat'] as num?)?.toDouble() ?? (barberShop['lat'] as num?)?.toDouble()) : (postShop['lat'] as num?)?.toDouble(),
              lng: isBarberPost ? ((barber['lng'] as num?)?.toDouble() ?? (barberShop['lng'] as num?)?.toDouble()) : (postShop['lng'] as num?)?.toDouble(),
              verified: isBarberPost
                  ? ((barber['is_verified'] as bool?) ?? (barber['badge_verified'] as bool?) ?? false)
                  : ((postShop['is_verified'] as bool?) ?? (postShop['badge_verified'] as bool?) ?? false),
              shopId: isBarberPost ? (barber['shop_id'] as String?) : null,
              shopName: isBarberPost ? (barberShop['name'] as String?) : null,
            ),
            status: status ?? 'pending',
            rejectionReason: rejectionReason,
            isLiked: false,
            isSaved: false,
            isFollowing: false,
          ),
        );
      }

      if (mapped.isEmpty) return <ExploreReel>[];

      mapped.sort((a, b) => b.reel.createdAt.compareTo(a.reel.createdAt));
      final seen = <String>{};
      final base = mapped.where((e) => seen.add(e.reel.id)).take(limit).toList(growable: false);

      final reelIds = base.map((e) => e.reel.id).toList();
      final baseBarberIds = base.where((e) => e.author.type == ExploreAuthorType.barber).map((e) => e.author.id).toSet().toList();
      final baseShopIds = base.where((e) => e.author.type == ExploreAuthorType.shop).map((e) => e.author.id).toSet().toList();

      final liked = <String>{};
      try {
        final likedRows = await _client.from('reel_likes').select('reel_id').eq('profile_id', user.id).inFilter('reel_id', reelIds);
        liked.addAll((likedRows as List).map((e) => e['reel_id'] as String));
      } catch (_) {}

      final saved = <String>{};
      try {
        final savedRows = await _client.from('reel_saves').select('reel_id').eq('profile_id', user.id).inFilter('reel_id', reelIds);
        saved.addAll((savedRows as List).map((e) => e['reel_id'] as String));
      } catch (_) {}

      final followingBarbers = <String>{};
      if (baseBarberIds.isNotEmpty) {
        try {
          final followRows = await _client
              .from('follows')
              .select('target_id')
              .eq('profile_id', user.id)
              .eq('target_type', 'barber')
              .inFilter('target_id', baseBarberIds);
          followingBarbers.addAll((followRows as List).map((e) => e['target_id'] as String));
        } catch (_) {}
      }

      final followingShops = <String>{};
      if (baseShopIds.isNotEmpty) {
        try {
          final followRows =
              await _client.from('follows').select('target_id').eq('profile_id', user.id).eq('target_type', 'shop').inFilter('target_id', baseShopIds);
          followingShops.addAll((followRows as List).map((e) => e['target_id'] as String));
        } catch (_) {}
      }

      final withFlags = base
          .map(
            (e) => e.copyWith(
              isLiked: liked.contains(e.reel.id),
              isSaved: saved.contains(e.reel.id),
              isFollowing: e.author.type == ExploreAuthorType.barber
                  ? followingBarbers.contains(e.author.id)
                  : followingShops.contains(e.author.id),
            ),
          )
          .toList(growable: false);

      return _signExploreList(withFlags);
    } catch (e) {
      if (_supportsBucketColumns && (_maybeMissingColumn(e, 'media_bucket') || _maybeMissingColumn(e, 'thumbnail_bucket'))) {
        _supportsBucketColumns = false;
        return listMyUploadsFeed(limit: limit, before: before);
      }
      throw AppException('Failed to load uploads', cause: e);
    }
  }

  Future<List<Reel>> list({int limit = 30}) async {
    final cacheKey = _cacheKey('reels_list', params: {'limit': limit});
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
        return <Reel>[];
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await _client.from('reels').select().eq('status', 'approved').order('created_at', ascending: false).limit(limit);
      await _writeCache(cacheKey, data);
      final list = (data as List).map((e) => Reel.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
      return <Reel>[];
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
        return <Reel>[];
      }
      throw AppException('Failed to load reels', cause: e);
    }
  }

  Future<List<Reel>> listApproved({int limit = 10, DateTime? before, String? cityId}) async {
    final viewerId = _client.auth.currentUser?.id ?? '';
    final cacheKey = _cacheKey(
      'reels_approved',
      params: {
        'limit': limit,
        'before': before?.millisecondsSinceEpoch ?? 0,
        'cityId': cityId ?? '',
        'viewer': viewerId,
      },
    );
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
        return <Reel>[];
      }
      throw const AppException('Offline mode');
    }
    try {
      Future<List> fetchFromTable(
        String table, {
        required bool withActive,
        required bool withDeletedAt,
        required String? scopedCityId,
      }) async {
        PostgrestFilterBuilder<PostgrestList> q =
            _client.from(table).select('*, barbershops!left(city_id), barbers!left(city_id)').eq('status', 'approved');
        if (withActive) {
          q = q.eq('is_active', true);
        }
        if (scopedCityId != null && scopedCityId.trim().isNotEmpty) {
          q = q.or('barbershops.city_id.eq.$scopedCityId,barbers.city_id.eq.$scopedCityId');
        }
        if (before != null) {
          q = q.lt('created_at', before.toIso8601String());
        }
        if (withDeletedAt) {
          q = q.isFilter('deleted_at', null);
        }
        return await q.order('created_at', ascending: false).limit(limit);
      }

      bool missingColumn(Object error, String column) => _maybeMissingColumn(error, column);

      Future<List> safeFetch(
        String table, {
        required String? scopedCityId,
      }) async {
        try {
          return await fetchFromTable(table, withActive: true, withDeletedAt: true, scopedCityId: scopedCityId);
        } catch (e) {
          if (missingColumn(e, 'is_active')) {
            try {
              return await fetchFromTable(table, withActive: false, withDeletedAt: true, scopedCityId: scopedCityId);
            } catch (e2) {
              if (missingColumn(e2, 'deleted_at')) {
                return await fetchFromTable(table, withActive: false, withDeletedAt: false, scopedCityId: scopedCityId);
              }
              rethrow;
            }
          }
          if (missingColumn(e, 'deleted_at')) {
            return await fetchFromTable(table, withActive: true, withDeletedAt: false, scopedCityId: scopedCityId);
          }
          rethrow;
        }
      }

      Future<List<Map<String, dynamic>>> fetchPreferred({required String? scopedCityId}) async {
        try {
          final data = await safeFetch('posts', scopedCityId: scopedCityId);
          final raw = data.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
          if (raw.isNotEmpty) return raw;
        } catch (_) {}
        final data = await safeFetch('reels', scopedCityId: scopedCityId);
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      }

      var raw = await fetchPreferred(scopedCityId: cityId);
      if (raw.isEmpty && cityId != null && cityId.trim().isNotEmpty) {
        raw = await fetchPreferred(scopedCityId: null);
      }
      raw = raw.where((e) {
        final reel = Reel.fromJson(e);
        return ((reel.mediaPath ?? '').trim().isNotEmpty) || reel.mediaUrl.trim().isNotEmpty;
      }).toList(growable: false);
      if (viewerId.isNotEmpty && raw.isNotEmpty) {
        final ids = raw.map((e) => e['id'] as String).toList(growable: false);
        final hides = await _client.from('reel_hides').select('reel_id').eq('profile_id', viewerId).inFilter('reel_id', ids);
        final hideSet = (hides as List).map((e) => (e as Map)['reel_id'] as String).toSet();
        raw.removeWhere((e) => hideSet.contains(e['id']));
      }
      await _writeCache(cacheKey, raw);
      final list = raw.map(Reel.fromJson).toList(growable: false);
      if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
      return <Reel>[];
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        if (list.isNotEmpty) return Future.wait(list.map(_withSignedMedia));
        return <Reel>[];
      }
      throw AppException('Failed to load reels', cause: e);
    }
  }

  Future<List<Reel>> listForBarber(String barberId, {int limit = 18}) async {
    try {
      final data = await _client
          .from('reels')
          .select()
          .eq('barber_id', barberId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Reel.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load reels', cause: e);
    }
  }

  Future<List<Reel>> listForBarberManage(String barberId, {int limit = 60}) async {
    final cacheKey = 'barber_reels_manage_$barberId';
    try {
      final data = await _client
          .from('reels')
          .select()
          .eq('barber_id', barberId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
      final raw = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      final list = raw.map(Reel.fromJson).toList(growable: false);
      try {
        await _kv.write(cacheKey, jsonEncode(raw));
      } catch (_) {}
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            final list = decoded.map((e) => Reel.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
            return Future.wait(list.map(_withSignedMedia));
          }
        }
      } catch (_) {}
      throw AppException('Failed to load uploads', cause: e);
    }
  }

  Future<Reel> update({
    required String reelId,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (caption != null) 'caption': caption.trim().isEmpty ? null : caption.trim(),
        if (location != null) 'location': location.trim().isEmpty ? null : location.trim(),
        if (hashtags != null) 'hashtags': hashtags.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(growable: false),
      };
      final data = await _client.from('reels').update(payload).eq('id', reelId).select().single();
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to update reel', cause: e);
    }
  }

  Future<void> softDelete(String reelId) async {
    try {
      await _client.from('reels').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', reelId);
    } catch (e) {
      throw AppException('Failed to delete reel', cause: e);
    }
  }

  Future<void> like(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_likes').upsert({'reel_id': reelId, 'profile_id': user.id});
    } catch (e) {
      throw AppException('Failed to like', cause: e);
    }
  }

  Future<void> unlike(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_likes').delete().eq('reel_id', reelId).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to unlike', cause: e);
    }
  }

  Future<void> save(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_saves').upsert({'reel_id': reelId, 'profile_id': user.id});
    } catch (e) {
      throw AppException('Failed to save', cause: e);
    }
  }

  Future<void> unsave(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_saves').delete().eq('reel_id', reelId).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to unsave', cause: e);
    }
  }

  Future<void> hide(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_hides').upsert({'reel_id': reelId, 'profile_id': user.id});
    } catch (e) {
      throw AppException('Failed to hide', cause: e);
    }
  }

  Future<void> unhide(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_hides').delete().eq('reel_id', reelId).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to unhide', cause: e);
    }
  }

  Future<int> incrementShare(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final v = await _client.rpc('increment_reel_share', params: {'reel': reelId});
      if (v is num) return v.toInt();
      return 0;
    } catch (e) {
      throw AppException('Failed to share', cause: e);
    }
  }

  Future<Reel> create({
    String? barberId,
    String? shopId,
    required String mediaType,
    required String mediaPath,
    String? thumbnailPath,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    if ((barberId ?? '').isEmpty && (shopId ?? '').isEmpty) {
      throw const AppException('Missing author');
    }
    try {
      final normalizedMediaPath = mediaPath.trim();
      final normalizedThumbPath = (thumbnailPath ?? '').trim();
      final payload = <String, dynamic>{
        if ((barberId ?? '').isNotEmpty) 'barber_id': barberId,
        if ((shopId ?? '').isNotEmpty) 'shop_id': shopId,
        'media_type': mediaType,
        'media_path': normalizedMediaPath,
        'media_bucket': 'reels',
        'media_url': normalizedMediaPath,
        if (mediaType == 'video') 'video_url': normalizedMediaPath,
        if (mediaType == 'image') 'image_url': normalizedMediaPath,
        'thumbnail_path': normalizedThumbPath.isEmpty ? null : normalizedThumbPath,
        'thumbnail_bucket': 'reels',
        'thumbnail_url': normalizedThumbPath.isEmpty ? null : normalizedThumbPath,
        'caption': (caption ?? '').trim().isEmpty ? null : caption?.trim(),
        'location': (location ?? '').trim().isEmpty ? null : location?.trim(),
        'hashtags': (hashtags ?? const <String>[]).where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(growable: false),
        'status': 'pending',
        'is_active': true,
      };
      final data = await _client.from('posts').insert(payload).select().single();
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to create reel', cause: e);
    }
  }

  Future<Reel> saveDraft({
    String? draftId,
    String? barberId,
    String? shopId,
    required String mediaType,
    required String mediaPath,
    String? thumbnailPath,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    if ((barberId ?? '').isEmpty && (shopId ?? '').isEmpty) {
      throw const AppException('Missing author');
    }
    try {
      final normalizedMediaPath = mediaPath.trim();
      final normalizedThumbPath = (thumbnailPath ?? '').trim();
      final payload = <String, dynamic>{
        if ((draftId ?? '').trim().isNotEmpty) 'id': draftId,
        if ((barberId ?? '').isNotEmpty) 'barber_id': barberId,
        if ((shopId ?? '').isNotEmpty) 'shop_id': shopId,
        'media_type': mediaType,
        'media_path': normalizedMediaPath,
        'media_bucket': 'reels',
        'media_url': normalizedMediaPath,
        if (mediaType == 'video') 'video_url': normalizedMediaPath,
        if (mediaType == 'image') 'image_url': normalizedMediaPath,
        'thumbnail_path': normalizedThumbPath.isEmpty ? null : normalizedThumbPath,
        'thumbnail_bucket': 'reels',
        'thumbnail_url': normalizedThumbPath.isEmpty ? null : normalizedThumbPath,
        'caption': (caption ?? '').trim().isEmpty ? null : caption?.trim(),
        'location': (location ?? '').trim().isEmpty ? null : location?.trim(),
        'hashtags': (hashtags ?? const <String>[]).where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(growable: false),
        'status': 'draft',
        'is_active': false,
      };
      final data = await _client.from('posts').upsert(payload).select().single();
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to save draft', cause: e);
    }
  }

  Future<Reel> publishDraft({
    required String draftId,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final payload = <String, dynamic>{
        'status': 'pending',
        'is_active': true,
        if (caption != null) 'caption': caption.trim().isEmpty ? null : caption.trim(),
        if (location != null) 'location': location.trim().isEmpty ? null : location.trim(),
        if (hashtags != null) 'hashtags': hashtags.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(growable: false),
      };
      final data = await _client.from('posts').update(payload).eq('id', draftId).select().single();
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to publish draft', cause: e);
    }
  }

  Future<void> archiveDraft(String draftId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client
          .from('posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String(), 'is_active': false}).eq('id', draftId);
    } catch (_) {
      try {
        await _client.from('posts').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', draftId);
      } catch (e) {
        throw AppException('Failed to delete draft', cause: e);
      }
    }
  }

  Future<List<Reel>> listDraftsForBarberManage(String barberId, {int limit = 60}) async {
    try {
      final data = await _client
          .from('reels')
          .select()
          .eq('barber_id', barberId)
          .eq('status', 'draft')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Reel.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (_) {
      return const <Reel>[];
    }
  }

  Future<Reel?> getById(String reelId) async {
    try {
      final data = await _client.from('reels').select().eq('id', reelId).single();
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (_) {
      return null;
    }
  }
}

final reelsRepositoryProvider = Provider<ReelsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReelsRepository(client, ref.watch(mediaServiceProvider), ref.watch(kvStoreProvider), ref.watch(networkOnlineProvider));
});

final reelsFeedProvider = FutureProvider<List<Reel>>((ref) async {
  return ref.watch(reelsRepositoryProvider).list();
});

final reelsForBarberProvider = FutureProvider.family<List<Reel>, String>((ref, barberId) async {
  return ref.watch(reelsRepositoryProvider).listForBarber(barberId);
});

final myBarberReelsManageProvider = FutureProvider<List<Reel>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <Reel>[];
  return ref.watch(reelsRepositoryProvider).listForBarberManage(barber.id);
});

final myBarberReelsDraftsProvider = FutureProvider<List<Reel>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <Reel>[];
  return ref.watch(reelsRepositoryProvider).listDraftsForBarberManage(barber.id);
});
