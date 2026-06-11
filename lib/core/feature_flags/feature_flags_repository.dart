import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../persistence/kv_store.dart';
import '../supabase/supabase_client_provider.dart';

class FeatureFlagsRepository {
  final SupabaseClient _client;
  final KvStore _kv;

  FeatureFlagsRepository(this._client, this._kv);

  Future<Map<String, bool>> fetchAll({bool forceRefresh = false}) async {
    const cacheKey = 'feature_flags_v1';
    if (!forceRefresh) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v == true));
          }
        }
      } catch (_) {}
    }

    try {
      final data = await _client.from('feature_flags').select('key, enabled').limit(500);
      final out = <String, bool>{};
      for (final raw in (data as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final key = (m['key'] as String?)?.trim();
        if (key == null || key.isEmpty) continue;
        out[key] = (m['enabled'] as bool?) ?? true;
      }
      try {
        await _kv.write(cacheKey, jsonEncode(out));
      } catch (_) {}
      return out;
    } catch (e) {
      throw AppException('Failed to load feature flags', cause: e);
    }
  }
}

final featureFlagsRepositoryProvider = Provider<FeatureFlagsRepository>((ref) {
  return FeatureFlagsRepository(ref.watch(supabaseClientProvider), ref.watch(kvStoreProvider));
});

final featureFlagsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(featureFlagsRepositoryProvider).fetchAll();
});

final featureFlagProvider = Provider.autoDispose.family<bool, ({String key, bool defaultValue})>((ref, input) {
  final flags = ref.watch(featureFlagsProvider).valueOrNull;
  if (flags == null) return input.defaultValue;
  return flags[input.key] ?? input.defaultValue;
});

