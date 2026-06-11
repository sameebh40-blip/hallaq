import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/network_status.dart';
import '../persistence/kv_store.dart';
import '../supabase/supabase_client_provider.dart';

class BrandAssetsCachePayload {
  final String? version;
  final Map<String, String> assets;

  const BrandAssetsCachePayload({required this.version, required this.assets});
}

BrandAssetsCachePayload? _safeParseCache(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  try {
    final decoded = jsonDecode(v);
    if (decoded is! Map) return null;
    final version = decoded['version'];
    final assetsRaw = decoded['assets'];
    if (version != null && version is! String) return null;
    if (assetsRaw is! Map) return null;
    final out = <String, String>{};
    for (final entry in assetsRaw.entries) {
      final k = (entry.key ?? '').toString().trim();
      final val = (entry.value ?? '').toString().trim();
      if (k.isNotEmpty && val.isNotEmpty) out[k] = val;
    }
    return BrandAssetsCachePayload(version: version as String?, assets: out);
  } catch (_) {
    return null;
  }
}

String resolveBrandAssetKey(String key) {
  final k = key.trim();
  if (k == 'default_profile_image') return 'default_profile_avatar';
  return k;
}

String localizedBrandAssetKey(String baseKey, String locale) {
  final base = resolveBrandAssetKey(baseKey);
  final loc = locale.trim().toLowerCase();
  if (base.isEmpty || loc.isEmpty) return base;
  return '${base}_$loc';
}

class BrandAssetsController extends AsyncNotifier<Map<String, String>> {
  static const _cacheKey = 'cache:brand_assets_v1';
  RealtimeChannel? _channel;

  @override
  Future<Map<String, String>> build() async {
    final kv = ref.watch(kvStoreProvider);
    final client = ref.watch(supabaseClientProvider);
    final isOnline = ref.watch(networkOnlineProvider);

    ref.onDispose(() {
      final ch = _channel;
      if (ch != null) {
        client.removeChannel(ch);
      }
      _channel = null;
    });

    final cached = _safeParseCache(await kv.read(_cacheKey));
    if (!isOnline) {
      return cached?.assets ?? const <String, String>{};
    }

    try {
      final latest = await client
          .from('brand_assets')
          .select('updated_at')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final latestVersion = latest == null ? null : (Map<String, dynamic>.from(latest as Map))['updated_at'] as String?;

      if (cached != null && cached.version != null && latestVersion != null && cached.version == latestVersion && cached.assets.isNotEmpty) {
        _ensureRealtime(client);
        return cached.assets;
      }

      final data = await client.from('brand_assets').select('asset_key, asset_url').eq('is_active', true);
      final out = <String, String>{};
      for (final row in (data as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final k = (m['asset_key'] as String?)?.trim() ?? '';
        final url = (m['asset_url'] as String?)?.trim() ?? '';
        if (k.isEmpty || url.isEmpty) continue;
        out[k] = url;
      }

      try {
        await kv.write(_cacheKey, jsonEncode({'version': latestVersion, 'assets': out}));
      } catch (_) {}

      _ensureRealtime(client);
      return out;
    } catch (_) {
      _ensureRealtime(client);
      return cached?.assets ?? const <String, String>{};
    }
  }

  void _ensureRealtime(SupabaseClient client) {
    if (_channel != null) return;
    final ch = client
        .channel('brand-assets-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'brand_assets',
          callback: (_) => refresh(),
        )
        .subscribe();
    _channel = ch;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => build());
  }
}

final brandAssetsControllerProvider = AsyncNotifierProvider<BrandAssetsController, Map<String, String>>(BrandAssetsController.new);

final brandAssetUrlProvider = Provider.family<String?, String>((ref, key) {
  final assets = ref.watch(brandAssetsControllerProvider).valueOrNull;
  return assets?[resolveBrandAssetKey(key)];
});

final brandAssetUrlLocalizedProvider = Provider.family<String?, ({String baseKey, String locale})>((ref, args) {
  final assets = ref.watch(brandAssetsControllerProvider).valueOrNull;
  final localized = localizedBrandAssetKey(args.baseKey, args.locale);
  return assets?[localized] ?? assets?[resolveBrandAssetKey(args.baseKey)];
});
