import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'search_filters.dart';

class SearchRepository {
  final SupabaseClient _client;
  final Ref _ref;

  SearchRepository(this._client, this._ref);

  static const _barberCardSelect =
      'id, profile_id, slug, display_name, area, address, lat, lng, avatar_url, avatar_path, cover_url, cover_path, rating_avg, rating_count, followers_count, reviews_count, is_independent, home_service, available_now, waiting_time_min, queue_length, is_verified, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, starting_price_bhd, distance_km, status, created_at, shop_id';

  static const _shopCardSelect =
      'id, owner_profile_id, name, area, address, lat, lng, cover_url, cover_path, logo_url, logo_path, opening_hours, home_service, rating_avg, rating_count, is_featured, is_verified, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, starting_price_bhd, distance_km';

  Future<List<Barber>> searchBarbers(String query, {SearchFilters filters = const SearchFilters(), int limit = 30, int offset = 0}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final loc = await _ref.read(effectiveLatLngProvider.future);
      final data = loc == null
          ? await (() {
              var query0 = _client.from('barbers').select(_barberCardSelect).or('display_name.ilike.%$q%,area.ilike.%$q%');
              final minP = filters.minPriceBhd;
              final maxP = filters.maxPriceBhd;
              if (minP != null) query0 = query0.gte('starting_price_bhd', minP);
              if (maxP != null) query0 = query0.lte('starting_price_bhd', maxP);
              return query0.range(offset, offset + limit - 1);
            }())
          : await _client.rpc('search_barbers', params: {
              'p_lat': loc.lat,
              'p_lng': loc.lng,
              'p_query': q,
              'p_limit': limit,
              'p_offset': offset,
              'p_open_now': filters.openNow,
              'p_available_today': filters.availableToday,
              'p_verified_only': filters.verifiedOnly,
              'p_home_service_only': filters.homeServiceOnly,
              'p_sort': filters.toRpcSort(),
              'p_max_distance_km': filters.maxDistanceKm,
              'p_min_price_bhd': filters.minPriceBhd,
              'p_max_price_bhd': filters.maxPriceBhd,
            });
      return (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to search barbers', cause: e);
    }
  }

  Future<List<Barbershop>> searchShops(String query, {SearchFilters filters = const SearchFilters(), int limit = 30, int offset = 0}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final loc = await _ref.read(effectiveLatLngProvider.future);
      final data = loc == null
          ? await (() {
              var query0 = _client.from('barbershops').select(_shopCardSelect).or('name.ilike.%$q%,area.ilike.%$q%');
              final minP = filters.minPriceBhd;
              final maxP = filters.maxPriceBhd;
              if (minP != null) query0 = query0.gte('starting_price_bhd', minP);
              if (maxP != null) query0 = query0.lte('starting_price_bhd', maxP);
              return query0.range(offset, offset + limit - 1);
            }())
          : await _client.rpc('search_shops', params: {
              'p_lat': loc.lat,
              'p_lng': loc.lng,
              'p_query': q,
              'p_limit': limit,
              'p_offset': offset,
              'p_open_now': filters.openNow,
              'p_available_today': filters.availableToday,
              'p_verified_only': filters.verifiedOnly,
              'p_home_service_only': filters.homeServiceOnly,
              'p_sort': filters.toRpcSort(),
              'p_max_distance_km': filters.maxDistanceKm,
              'p_min_price_bhd': filters.minPriceBhd,
              'p_max_price_bhd': filters.maxPriceBhd,
            });
      return (data as List).map((e) => Barbershop.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to search shops', cause: e);
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider), ref);
});
