import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/localization/area_controller.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/models/offer.dart';
import '../../offers/data/offers_repository.dart';
import '../models/city_dashboard_models.dart';

class CityDashboardRepository {
  final SupabaseClient _client;
  final KvStore _kv;
  final bool _isOnline;
  final MediaService _media;
  final OffersRepository _offers;

  CityDashboardRepository(this._client, this._kv, this._isOnline, this._media, this._offers);

  static const _bannerCacheKey = 'cache:city_banner_active_v1';
  static const _bannerTtlMs = 1000 * 60 * 60 * 12;

  Future<void> _writeCache(String key, Object value) async {
    await _kv.write(key, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'v': value}));
  }

  Future<Map<String, dynamic>?> _readCacheMap(String key, int ttlMs) async {
    final raw = await _kv.read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final t = decoded['t'];
      final v = decoded['v'];
      if (t is! num) return null;
      if (DateTime.now().millisecondsSinceEpoch - t.toInt() > ttlMs) return null;
      if (v is! Map) return null;
      return Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
  }

  Future<CityBanner?> loadActiveBanner() async {
    if (!_isOnline) {
      final cached = await _readCacheMap(_bannerCacheKey, _bannerTtlMs);
      return cached == null ? null : CityBanner.fromJson(cached);
    }
    try {
      final row = await _client
          .from('city_banners')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final map = row == null ? null : Map<String, dynamic>.from(row as Map);
      if (map != null) {
        try {
          await _writeCache(_bannerCacheKey, map);
        } catch (_) {}
      }
      return map == null ? null : CityBanner.fromJson(map);
    } catch (e) {
      final cached = await _readCacheMap(_bannerCacheKey, _bannerTtlMs);
      if (cached != null) return CityBanner.fromJson(cached);
      throw AppException('Failed to load city banner', cause: e);
    }
  }

  Future<CityTrendingToday> loadTrendingToday({required String? area}) async {
    try {
      final barbersRaw = await _client.rpc('city_trending_barbers', params: {'p_limit': 30});
      final shopsRaw = await _client.rpc('city_trending_shops', params: {'p_limit': 30});
      final reelsRaw = await _client.rpc('city_trending_reels', params: {'p_limit': 30});

      TrendingBarber? barber;
      for (final row in (barbersRaw as List)) {
        final b = TrendingBarber.fromJson(Map<String, dynamic>.from(row as Map));
        if (area == null || area.trim().isEmpty || (b.area ?? '').trim() == area.trim()) {
          barber = b;
          break;
        }
      }

      TrendingShop? shop;
      for (final row in (shopsRaw as List)) {
        final s = TrendingShop.fromJson(Map<String, dynamic>.from(row as Map));
        if (area == null || area.trim().isEmpty || (s.area ?? '').trim() == area.trim()) {
          shop = s;
          break;
        }
      }

      TrendingReel? reel;
      final reelsList = reelsRaw is List ? reelsRaw : const [];
      if (reelsList.isNotEmpty) {
        final first = reelsList.first;
        if (first is Map) {
          reel = TrendingReel.fromJson(Map<String, dynamic>.from(first));
        }
      }

      final stylesRaw = await _client
          .from('style_library')
          .select('id, slug, name_en, name_ar, cover_url, cover_path, views_count')
          .eq('is_active', true)
          .order('views_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);
      StyleLibraryItem? style;
      if ((stylesRaw as List).isNotEmpty) {
        style = StyleLibraryItem.fromJson(Map<String, dynamic>.from((stylesRaw as List).first as Map));
      }

      return CityTrendingToday(
        mostBookedBarber: barber,
        mostBookedShop: shop,
        mostWatchedReel: reel,
        mostLikedStyle: style,
      );
    } catch (e) {
      throw AppException('Failed to load trending', cause: e);
    }
  }

  Future<List<StyleLibraryItem>> listPopularStyles({int limit = 12}) async {
    try {
      final data = await _client
          .from('style_library')
          .select('id, slug, name_en, name_ar, cover_url, cover_path, views_count')
          .eq('is_active', true)
          .order('views_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => StyleLibraryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
      return Future.wait(list.map((s) async {
        final url = await _media.resolveMediaUrl(bucket: 'style-library', path: s.coverPath, legacyUrlOrPath: s.coverUrl);
        return StyleLibraryItem(
          id: s.id,
          slug: s.slug,
          nameEn: s.nameEn,
          nameAr: s.nameAr,
          coverUrl: url,
          coverPath: s.coverPath,
          viewsCount: s.viewsCount,
        );
      }));
    } catch (e) {
      throw AppException('Failed to load styles', cause: e);
    }
  }

  Future<List<Offer>> listOffersForArea({required String? area, int limit = 20}) async {
    final list = await _offers.listActive(limit: limit);
    final a = (area ?? '').trim();
    if (a.isEmpty) return list;

    final shopIds = list.map((e) => (e.shopId ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    final barberIds = list.map((e) => (e.barberId ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);

    final shopsArea = <String, String>{};
    final barbersArea = <String, String>{};

    if (shopIds.isNotEmpty) {
      final shops = await _client.from('barbershops').select('id, area').inFilter('id', shopIds);
      for (final row in (shops as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        shopsArea[id] = (m['area'] as String?)?.trim() ?? '';
      }
    }

    if (barberIds.isNotEmpty) {
      final barbers = await _client.from('barbers').select('id, area').inFilter('id', barberIds);
      for (final row in (barbers as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        barbersArea[id] = (m['area'] as String?)?.trim() ?? '';
      }
    }

    return list.where((o) {
      final shopArea = o.shopId == null ? '' : (shopsArea[o.shopId] ?? '');
      final barberArea = o.barberId == null ? '' : (barbersArea[o.barberId] ?? '');
      return shopArea == a || barberArea == a;
    }).toList(growable: false);
  }

  Future<CityStats> loadStats({required String? area}) async {
    try {
      final a = (area ?? '').trim();

      final barbersQ = _client.from('barbers').count(CountOption.exact).eq('is_active', true).eq('status', 'approved');
      final shopsQ = _client.from('barbershops').count(CountOption.exact).eq('is_active', true).eq('status', 'approved').isFilter('deleted_at', null);

      final activeBarbers = a.isEmpty ? await barbersQ : await barbersQ.eq('area', a);
      final barberShops = a.isEmpty ? await shopsQ : await shopsQ.eq('area', a);

      final offers = await listOffersForArea(area: a.isEmpty ? null : a, limit: 200);
      final activeOffers = offers.length;

      final start30d = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
      int monthlyBookings = 0;
      if (a.isEmpty) {
        monthlyBookings = await _client
            .from('bookings')
            .count(CountOption.exact)
            .gte('start_at', start30d)
            .inFilter('status', ['confirmed', 'completed']);
      } else {
        final shopIds = await _client.from('barbershops').select('id').eq('area', a).eq('is_active', true).eq('status', 'approved').limit(2000);
        final barberIds = await _client.from('barbers').select('id').eq('area', a).eq('is_active', true).eq('status', 'approved').limit(2000);

        final shopsList = (shopIds as List).map((e) => (e as Map)['id'] as String?).whereType<String>().toList(growable: false);
        final barbersList = (barberIds as List).map((e) => (e as Map)['id'] as String?).whereType<String>().toList(growable: false);

        if (shopsList.isNotEmpty) {
          monthlyBookings += await _client
              .from('bookings')
              .count(CountOption.exact)
              .inFilter('shop_id', shopsList)
              .gte('start_at', start30d)
              .inFilter('status', ['confirmed', 'completed']);
        }
        if (barbersList.isNotEmpty) {
          monthlyBookings += await _client
              .from('bookings')
              .count(CountOption.exact)
              .inFilter('barber_id', barbersList)
              .gte('start_at', start30d)
              .inFilter('status', ['confirmed', 'completed']);
        }
      }

      final ratingsRaw = a.isEmpty
          ? await _client.from('barbershops').select('rating_avg').eq('is_active', true).eq('status', 'approved').limit(5000)
          : await _client.from('barbershops').select('rating_avg').eq('is_active', true).eq('status', 'approved').eq('area', a).limit(5000);

      var sum = 0.0;
      var count = 0;
      for (final r in (ratingsRaw as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        sum += (m['rating_avg'] as num?)?.toDouble() ?? 0;
        count++;
      }
      final averageRating = count == 0 ? 0.0 : sum / count;

      return CityStats(
        activeBarbers: activeBarbers,
        barberShops: barberShops,
        activeOffers: activeOffers,
        monthlyBookings: monthlyBookings,
        averageRating: averageRating.isFinite ? averageRating : 0.0,
      );
    } catch (e) {
      throw AppException('Failed to load city stats', cause: e);
    }
  }
}

final cityDashboardRepositoryProvider = Provider<CityDashboardRepository>((ref) {
  return CityDashboardRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(kvStoreProvider),
    ref.watch(networkOnlineProvider),
    ref.watch(mediaServiceProvider),
    ref.watch(offersRepositoryProvider),
  );
});

final cityBannerProvider = FutureProvider<CityBanner?>((ref) async {
  return ref.watch(cityDashboardRepositoryProvider).loadActiveBanner();
});

final cityTrendingTodayProvider = FutureProvider<CityTrendingToday>((ref) async {
  ref.watch(cityBannerProvider);
  final area = ref.watch(areaControllerProvider);
  return ref.watch(cityDashboardRepositoryProvider).loadTrendingToday(area: area);
});

final cityPopularStylesProvider = FutureProvider<List<StyleLibraryItem>>((ref) async {
  ref.watch(areaControllerProvider);
  return ref.watch(cityDashboardRepositoryProvider).listPopularStyles();
});

final cityStatsProvider = FutureProvider<CityStats>((ref) async {
  final area = ref.watch(areaControllerProvider);
  return ref.watch(cityDashboardRepositoryProvider).loadStats(area: area);
});

final cityOffersProvider = FutureProvider<List<Offer>>((ref) async {
  final area = ref.watch(areaControllerProvider);
  return ref.watch(cityDashboardRepositoryProvider).listOffersForArea(area: area);
});
