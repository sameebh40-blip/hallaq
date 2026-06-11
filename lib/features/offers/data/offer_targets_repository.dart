import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class OfferTargetsRepository {
  final SupabaseClient _client;

  OfferTargetsRepository(this._client);

  Future<void> sendOfferToCustomer({
    required String offerId,
    required String customerProfileId,
    String? barberId,
    String? shopId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('offer_targets').insert({
        'offer_id': offerId.trim(),
        'customer_profile_id': customerProfileId.trim(),
        'barber_id': (barberId ?? '').trim().isEmpty ? null : barberId,
        'shop_id': (shopId ?? '').trim().isEmpty ? null : shopId,
        'sent_by_profile_id': user.id,
        'status': 'sent',
      });
    } catch (e) {
      throw AppException('Failed to send offer', cause: e);
    }
  }
}

final offerTargetsRepositoryProvider = Provider<OfferTargetsRepository>((ref) {
  return OfferTargetsRepository(ref.watch(supabaseClientProvider));
});

