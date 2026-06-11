import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/data/profile_repository.dart';
import '../models/role.dart';
import '../supabase/supabase_client_provider.dart';

class SystemLogsRepository {
  final SupabaseClient _client;
  final ProfileRepository _profiles;
  String _lastSignature = '';
  DateTime _lastLoggedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  SystemLogsRepository(this._client, this._profiles);

  Future<void> logError({
    required String page,
    required String action,
    required Object error,
    String? stackTrace,
    String severity = 'error',
    Map<String, dynamic>? meta,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final signature = '$page|$action|${error.toString()}';
      if (signature == _lastSignature && now.difference(_lastLoggedAt).inSeconds < 5) return;
      _lastSignature = signature;
      _lastLoggedAt = now;
      final user = _client.auth.currentUser;
      final AppUserRole? role = user == null ? null : await _profiles.getMyRoleFast();
      await _client.from('system_logs').insert({
        'user_id': user?.id,
        'role': role?.toDb(),
        'page': page,
        'action': action,
        'error_message': error.toString(),
        'stack_trace': (stackTrace ?? '').trim(),
        'severity': severity,
        'meta': meta ?? const <String, dynamic>{},
      });
    } catch (_) {}
  }

  void logErrorUnawaited({
    required String page,
    required String action,
    required Object error,
    String? stackTrace,
    String severity = 'error',
    Map<String, dynamic>? meta,
  }) {
    unawaited(
      logError(page: page, action: action, error: error, stackTrace: stackTrace, severity: severity, meta: meta),
    );
  }
}

final systemLogsRepositoryProvider = Provider<SystemLogsRepository>((ref) {
  return SystemLogsRepository(ref.watch(supabaseClientProvider), ref.watch(profileRepositoryProvider));
});
