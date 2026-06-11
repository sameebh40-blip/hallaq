import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class PushTokensRepository {
  final SupabaseClient _client;

  PushTokensRepository(this._client);

  Future<void> upsertMyToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.rpc(
        'upsert_device_token',
        params: {
          'token': token,
          'platform': platform,
          'device_id': deviceId,
        },
      );
    } catch (e) {
      throw AppException('Failed to register push token', cause: e);
    }
  }
}

final pushTokensRepositoryProvider = Provider<PushTokensRepository>((ref) {
  return PushTokensRepository(ref.watch(supabaseClientProvider));
});

