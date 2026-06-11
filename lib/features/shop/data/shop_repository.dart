import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ShopRepository {
  final SupabaseClient _client;
  final MediaService _media;

  ShopRepository(this._client, this._media);

  static const _shopCardSelect =
      'id, owner_profile_id, name, area, address, lat, lng, cover_url, cover_path, logo_url, logo_path, opening_hours, home_service, rating_avg, rating_count, is_featured, is_verified, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, starting_price_bhd, distance_km';

  Future<Barbershop> _withSignedMedia(Barbershop s) async {
    final cover = await _media.resolveMediaUrl(bucket: 'shop-images', path: s.coverPath, legacyUrlOrPath: s.coverUrl);
    final logo = await _media.resolveMediaUrl(bucket: 'shop-images', path: s.logoPath, legacyUrlOrPath: s.logoUrl);
    return s.copyWith(coverUrl: cover, logoUrl: logo);
  }

  Future<List<Barbershop>> getFeatured({int limit = 10}) async {
    try {
      final data = await _client
          .from('barbershops')
          .select(_shopCardSelect)
          .eq('is_featured', true)
          .eq('status', 'approved')
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('rating_avg', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Barbershop.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load barbershops', cause: e);
    }
  }

  Future<Barbershop> getById(String id) async {
    try {
      final data = await _client.from('barbershops').select().eq('id', id).maybeSingle();
      if (data == null) throw const AppException('Shop not available');
      return _withSignedMedia(Barbershop.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to load barbershop', cause: e);
    }
  }

  Future<Barbershop?> getMyShop() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data =
          await _client.from('barbershops').select().eq('owner_profile_id', user.id).order('created_at', ascending: false).maybeSingle();
      if (data == null) {
        final profile = await _client.from('profiles').select('full_name, email, area').eq('id', user.id).maybeSingle();
        final fullName = profile == null ? '' : ((profile as Map)['full_name'] ?? '').toString().trim();
        final email = profile == null ? '' : ((profile as Map)['email'] ?? '').toString().trim();
        final area = profile == null ? null : ((profile as Map)['area'] as String?);
        final name = fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : '');

        final payload = <String, dynamic>{
          'id': user.id,
          'owner_profile_id': user.id,
          'name': name,
          'area': area,
          'is_active': false,
          'status': 'draft',
        };

        try {
          await _client.from('barbershops').insert(payload);
        } catch (e) {
          throw AppException('Failed to create barbershop', cause: e);
        }

        final created = await _client.from('barbershops').select().eq('owner_profile_id', user.id).order('created_at', ascending: false).maybeSingle();
        if (created == null) return null;
        return _withSignedMedia(Barbershop.fromJson(Map<String, dynamic>.from(created as Map)));
      }
      return _withSignedMedia(Barbershop.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to load barbershop', cause: e);
    }
  }

  Future<Barbershop> updateShop({
    required String shopId,
    String? name,
    String? description,
    String? aboutUs,
    String? story,
    int? yearsInBusiness,
    List<String>? specialties,
    List<String>? awards,
    List<String>? languages,
    String? area,
    String? address,
    String? googleMapsUrl,
    double? lat,
    double? lng,
    Map<String, dynamic>? openingHours,
    bool? homeService,
    String? phone,
    String? whatsapp,
    String? instagram,
    String? logoUrl,
    String? coverUrl,
    String? logoPath,
    String? coverPath,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim().isEmpty ? null : description.trim(),
        if (aboutUs != null) 'about_us': aboutUs.trim().isEmpty ? null : aboutUs.trim(),
        if (story != null) 'story': story.trim().isEmpty ? null : story.trim(),
        if (yearsInBusiness != null) 'years_in_business': yearsInBusiness,
        if (specialties != null) 'specialties': specialties,
        if (awards != null) 'awards': awards,
        if (languages != null) 'languages': languages,
        if (area != null) 'area': area.trim().isEmpty ? null : area.trim(),
        if (address != null) 'address': address.trim().isEmpty ? null : address.trim(),
        if (googleMapsUrl != null) 'google_maps_url': googleMapsUrl.trim().isEmpty ? null : googleMapsUrl.trim(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (openingHours != null) 'opening_hours': openingHours,
        if (homeService != null) 'home_service': homeService,
        if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
        if (whatsapp != null) 'whatsapp': whatsapp.trim().isEmpty ? null : whatsapp.trim(),
        if (instagram != null) 'instagram': instagram.trim().isEmpty ? null : instagram.trim(),
        if (logoUrl != null) 'logo_url': logoUrl.trim().isEmpty ? null : logoUrl.trim(),
        if (coverUrl != null) 'cover_url': coverUrl.trim().isEmpty ? null : coverUrl.trim(),
        if (logoPath != null) 'logo_path': logoPath.trim().isEmpty ? null : logoPath.trim(),
        if (coverPath != null) 'cover_path': coverPath.trim().isEmpty ? null : coverPath.trim(),
      };
      final data = await _client.from('barbershops').update(payload).eq('id', shopId).select().single();
      return _withSignedMedia(Barbershop.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to update barbershop', cause: e);
    }
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ShopRepository(client, ref.watch(mediaServiceProvider));
});

final featuredShopsProvider = FutureProvider<List<Barbershop>>((ref) async {
  return ref.watch(shopRepositoryProvider).getFeatured();
});

final shopByIdProvider = FutureProvider.family<Barbershop, String>((ref, shopId) async {
  return ref.watch(shopRepositoryProvider).getById(shopId);
});

final myShopProvider = FutureProvider<Barbershop?>((ref) async {
  return ref.watch(shopRepositoryProvider).getMyShop();
});
