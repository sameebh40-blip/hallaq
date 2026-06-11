import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/offer.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class MyOfferTarget {
  final String id;
  final String offerId;
  final String customerProfileId;
  final String? barberId;
  final String? shopId;
  final String status;
  final DateTime createdAt;
  final DateTime? redeemedAt;
  final Offer offer;

  const MyOfferTarget({
    required this.id,
    required this.offerId,
    required this.customerProfileId,
    required this.barberId,
    required this.shopId,
    required this.status,
    required this.createdAt,
    required this.redeemedAt,
    required this.offer,
  });
}

class MyOffersRepository {
  final SupabaseClient _client;
  final MediaService _media;

  MyOffersRepository(this._client, this._media);

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

  Future<List<MyOfferTarget>> listMyTargets({int limit = 100}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const <MyOfferTarget>[];
    try {
      final data = await _client
          .from('offer_targets')
          .select(
            'id, offer_id, customer_profile_id, barber_id, shop_id, status, redeemed_at, created_at, offers(id, shop_id, barber_id, title, description, offer_type, discount_percent, discount_amount, package_details, valid_from, valid_to, active, banner_url, banner_path, created_at)',
          )
          .eq('customer_profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final out = <MyOfferTarget>[];
      for (final raw in (data as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final offerRaw = m['offers'];
        if (offerRaw is! Map) continue;
        final offer = await _withSignedMedia(Offer.fromJson(Map<String, dynamic>.from(offerRaw)));
        out.add(
          MyOfferTarget(
            id: m['id'] as String,
            offerId: (m['offer_id'] as String?) ?? offer.id,
            customerProfileId: (m['customer_profile_id'] as String?) ?? user.id,
            barberId: m['barber_id'] as String?,
            shopId: m['shop_id'] as String?,
            status: (m['status'] as String?) ?? 'sent',
            createdAt: DateTime.parse(m['created_at'] as String),
            redeemedAt: (m['redeemed_at'] as String?) == null ? null : DateTime.tryParse(m['redeemed_at'] as String),
            offer: offer,
          ),
        );
      }
      return out;
    } catch (e) {
      throw AppException('Failed to load your offers', cause: e);
    }
  }

  Future<void> markRedeemed(String offerTargetId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('offer_targets').update({'status': 'redeemed', 'redeemed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', offerTargetId);
    } catch (e) {
      throw AppException('Failed to update offer', cause: e);
    }
  }
}

final myOffersRepositoryProvider = Provider<MyOffersRepository>((ref) {
  return MyOffersRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final myOfferTargetsProvider = FutureProvider.autoDispose<List<MyOfferTarget>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(myOffersRepositoryProvider).listMyTargets(limit: 100);
});

