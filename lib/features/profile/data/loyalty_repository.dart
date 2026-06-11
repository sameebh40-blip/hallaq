import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class LoyaltyEntry {
  final String id;
  final int delta;
  final String reason;
  final DateTime createdAt;

  const LoyaltyEntry({required this.id, required this.delta, required this.reason, required this.createdAt});

  factory LoyaltyEntry.fromJson(Map<String, dynamic> json) {
    return LoyaltyEntry(
      id: (json['id'] as String?) ?? '',
      delta: ((json['delta'] as num?) ?? 0).toInt(),
      reason: (json['reason'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class LoyaltyRepository {
  final SupabaseClient _client;

  LoyaltyRepository(this._client);

  Future<List<LoyaltyEntry>> loadMyLedger({int limit = 40}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('loyalty_ledger')
          .select('id, delta, reason, created_at')
          .eq('profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((e) => LoyaltyEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load points history', cause: e);
    }
  }
}

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(ref.watch(supabaseClientProvider));
});

final myLoyaltyLedgerProvider = FutureProvider<List<LoyaltyEntry>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(loyaltyRepositoryProvider).loadMyLedger();
});

