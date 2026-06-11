import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../supabase/supabase_client_provider.dart';

class City {
  final String id;
  final String name;
  final String country;
  final double lat;
  final double lng;

  const City({
    required this.id,
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      country: (json['country'] as String?) ?? 'Bahrain',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class CitiesRepository {
  final SupabaseClient _client;

  CitiesRepository(this._client);

  Future<List<City>> listActive() async {
    try {
      final data = await _client.from('cities').select().eq('is_active', true).order('sort_order', ascending: true).order('created_at', ascending: false);
      return (data as List).map((e) => City.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load cities', cause: e);
    }
  }
}

final citiesRepositoryProvider = Provider<CitiesRepository>((ref) {
  return CitiesRepository(ref.watch(supabaseClientProvider));
});

final activeCitiesProvider = FutureProvider<List<City>>((ref) async {
  return ref.watch(citiesRepositoryProvider).listActive();
});

