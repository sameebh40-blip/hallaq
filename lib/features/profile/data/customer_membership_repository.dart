import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class CustomerMembership {
  final String id;
  final String userId;
  final int points;
  final String tier;
  final DateTime updatedAt;

  const CustomerMembership({
    required this.id,
    required this.userId,
    required this.points,
    required this.tier,
    required this.updatedAt,
  });

  factory CustomerMembership.fromJson(Map<String, dynamic> json) {
    return CustomerMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      points: (json['points'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as String?) ?? 'Silver',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CustomerMembershipRepository {
  final SupabaseClient _client;

  CustomerMembershipRepository(this._client);

  Future<CustomerMembership?> getMyMembership() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client.from('customer_membership').select().eq('user_id', user.id).maybeSingle();
      if (row == null) return null;
      return CustomerMembership.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      throw AppException('Failed to load membership', cause: e);
    }
  }

  Stream<CustomerMembership?> watchMyMembership() async* {
    final user = _client.auth.currentUser;
    if (user == null) {
      yield null;
      return;
    }

    yield await getMyMembership();

    final refresh = StreamController<void>();

    var scheduled = false;
    Timer? timer;

    void scheduleRefresh() {
      if (scheduled) return;
      scheduled = true;
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 300), () {
        scheduled = false;
        if (!refresh.isClosed) refresh.add(null);
      });
    }

    final membershipSub =
        _client.from('customer_membership').stream(primaryKey: const ['id']).eq('user_id', user.id).listen((_) => scheduleRefresh());
    final ledgerSub = _client.from('loyalty_ledger').stream(primaryKey: const ['id']).eq('profile_id', user.id).listen((_) => scheduleRefresh());

    try {
      await for (final _ in refresh.stream) {
        yield await getMyMembership();
      }
    } finally {
      timer?.cancel();
      await membershipSub.cancel();
      await ledgerSub.cancel();
      await refresh.close();
    }
  }
}

final customerMembershipRepositoryProvider = Provider<CustomerMembershipRepository>((ref) {
  return CustomerMembershipRepository(ref.watch(supabaseClientProvider));
});

final myCustomerMembershipProvider = StreamProvider<CustomerMembership?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(customerMembershipRepositoryProvider).watchMyMembership();
});
