import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/customer.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class CustomerRepository {
  final SupabaseClient _client;

  CustomerRepository(this._client);

  Future<Customer?> getMyCustomer() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client.from('customers').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return Customer.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to load customer', cause: e);
    }
  }

  Future<Customer> upsertMyCustomer({
    required String fullName,
    required String phone,
    required String email,
    required String language,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final payload = <String, dynamic>{
        'id': user.id,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'language': language,
      };
      final data = await _client.from('customers').upsert(payload).select().single();
      return Customer.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to update customer', cause: e);
    }
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerRepository(client);
});

