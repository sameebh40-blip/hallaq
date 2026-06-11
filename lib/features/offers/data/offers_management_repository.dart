import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/offer.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class OffersManagementRepository {
  final SupabaseClient _client;
  final MediaService _media;

  OffersManagementRepository(this._client, this._media);

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

  Future<List<Offer>> listForShop(String shopId, {int limit = 100}) async {
    try {
      final data = await _client.from('offers').select().eq('shop_id', shopId).order('created_at', ascending: false).limit(limit);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load offers', cause: e);
    }
  }

  Future<List<Offer>> listForBarber(String barberId, {int limit = 100}) async {
    try {
      final data = await _client.from('offers').select().eq('barber_id', barberId).order('created_at', ascending: false).limit(limit);
      final list = (data as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load offers', cause: e);
    }
  }

  Future<Offer> upsert(Map<String, dynamic> payload) async {
    try {
      final data = await _client.from('offers').upsert(payload).select().single();
      return Offer.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to save offer', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('offers').delete().eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete offer', cause: e);
    }
  }
}

final offersManagementRepositoryProvider = Provider<OffersManagementRepository>((ref) {
  return OffersManagementRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});
