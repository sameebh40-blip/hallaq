import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/network_status.dart';
import '../persistence/kv_store.dart';
import '../supabase/supabase_client_provider.dart';

class AnalyticsOutbox {
  final KvStore _kv;
  final SupabaseClient _client;
  final bool _isOnline;

  AnalyticsOutbox(this._kv, this._client, this._isOnline);

  static const _key = 'analytics_outbox_v1';
  static const _max = 200;

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _kv.read(_key);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    final trimmed = items.length <= _max ? items : items.sublist(items.length - _max);
    await _kv.write(_key, jsonEncode(trimmed));
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final list = await _read();
    await _write([...list, payload]);
  }

  Future<void> flush() async {
    if (!_isOnline) return;
    final list = await _read();
    if (list.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final e in list) {
      try {
        await _client.from('analytics_events').insert(e);
      } catch (_) {
        remaining.add(e);
      }
    }
    await _write(remaining);
  }
}

final analyticsOutboxProvider = Provider<AnalyticsOutbox>((ref) {
  return AnalyticsOutbox(ref.watch(kvStoreProvider), ref.watch(supabaseClientProvider), ref.watch(networkOnlineProvider));
});

final analyticsOutboxFlusherProvider = Provider<void>((ref) {
  final online = ref.watch(networkOnlineProvider);
  if (online) {
    Future<void>(() async {
      try {
        await ref.read(analyticsOutboxProvider).flush();
      } catch (_) {}
    });
  }
});
