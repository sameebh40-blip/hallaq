import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_outbox.dart';
import '../network/network_status.dart';
import '../persistence/kv_store.dart';
import '../supabase/supabase_client_provider.dart';

class AnalyticsRepository {
  final SupabaseClient _client;
  final AnalyticsOutbox _outbox;
  final KvStore _kv;
  final bool _isOnline;
  final Random _rand = Random.secure();
  String? _sessionId;

  AnalyticsRepository(this._client, this._outbox, this._kv, this._isOnline);

  String _token([int bytes = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final out = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      out.write(chars[_rand.nextInt(chars.length)]);
    }
    return out.toString();
  }

  Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;
    final cached = await _kv.read('analytics_session_id');
    if (cached != null && cached.trim().isNotEmpty) {
      _sessionId = cached.trim();
      return _sessionId!;
    }
    final created = '${DateTime.now().millisecondsSinceEpoch}_${_token()}';
    _sessionId = created;
    await _kv.write('analytics_session_id', created);
    return created;
  }

  Future<void> track({
    required String eventName,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? meta,
  }) async {
    final sessionId = await _getSessionId();
    final payload = <String, dynamic>{
      'profile_id': _client.auth.currentUser?.id,
      'event_name': eventName,
      'entity_type': entityType,
      'entity_id': entityId,
      'meta': meta ?? const <String, dynamic>{},
      'session_id': sessionId,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
    if (!_isOnline) {
      await _outbox.enqueue(payload);
      return;
    }
    try {
      await _client.from('analytics_events').insert(payload);
    } catch (_) {}
    try {
      await _outbox.flush();
    } catch (_) {}
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(analyticsOutboxProvider),
    ref.watch(kvStoreProvider),
    ref.watch(networkOnlineProvider),
  );
});
