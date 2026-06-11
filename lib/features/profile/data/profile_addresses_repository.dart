import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ProfileAddress {
  final String id;
  final String profileId;
  final String label;
  final String line1;
  final String? line2;
  final String? city;
  final String? country;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileAddress({
    required this.id,
    required this.profileId,
    required this.label,
    required this.line1,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.line2,
    this.city,
    this.country,
  });

  factory ProfileAddress.fromJson(Map<String, dynamic> json) {
    return ProfileAddress(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      label: (json['label'] as String?) ?? '',
      line1: (json['line1'] as String?) ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProfileAddressesRepository {
  final SupabaseClient _client;

  ProfileAddressesRepository(this._client);

  Stream<List<ProfileAddress>> watchMy() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();
    return _client
        .from('profile_addresses')
        .stream(primaryKey: const ['id'])
        .eq('profile_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((e) => ProfileAddress.fromJson(Map<String, dynamic>.from(e))).toList(growable: false));
  }

  Future<void> upsert({
    String? id,
    required String label,
    required String line1,
    String? line2,
    String? city,
    String? country,
    bool isDefault = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final payload = <String, dynamic>{
        if (id != null) 'id': id,
        'profile_id': user.id,
        'label': label.trim(),
        'line1': line1.trim(),
        'line2': (line2 ?? '').trim().isEmpty ? null : line2!.trim(),
        'city': (city ?? '').trim().isEmpty ? null : city!.trim(),
        'country': (country ?? '').trim().isEmpty ? null : country!.trim(),
        'is_default': isDefault,
      };

      if (isDefault) {
        await _client.from('profile_addresses').update({'is_default': false}).eq('profile_id', user.id);
      }

      await _client.from('profile_addresses').upsert(payload);
    } catch (e) {
      throw AppException('Failed to save address', cause: e);
    }
  }

  Future<void> remove(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('profile_addresses').delete().eq('id', id).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to remove address', cause: e);
    }
  }
}

final profileAddressesRepositoryProvider = Provider<ProfileAddressesRepository>((ref) {
  return ProfileAddressesRepository(ref.watch(supabaseClientProvider));
});

final myAddressesProvider = StreamProvider<List<ProfileAddress>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(profileAddressesRepositoryProvider).watchMy();
});

