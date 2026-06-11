import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_loader.dart';
import '../network/auth_health_probe.dart';
import '../network/internet_checker.dart';

class SupabasePreflightResult {
  final bool supabaseInitialized;
  final ({bool ok, Object? error}) internet;
  final ({bool ok, int? statusCode, String detail, Object? error}) authHealth;
  final ({bool ok, String detail, Object? error}) database;

  const SupabasePreflightResult({
    required this.supabaseInitialized,
    required this.internet,
    required this.authHealth,
    required this.database,
  });

  bool get ok => supabaseInitialized && internet.ok && authHealth.ok;

  void debugPrintReport({required EnvLoadResult env}) {
    if (!kDebugMode) return;
    final host = Uri.tryParse(env.env.supabaseUrl)?.host ?? '';
    debugPrint(
      '[Preflight] platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} source=${env.source} urlPresent=${env.hasUrl} urlHost=$host keyPresent=${env.hasAnonKey} keyLen=${env.anonKeyLength}',
    );
    debugPrint('[Preflight] supabaseInitialized=$supabaseInitialized');
    debugPrint('[Preflight] internet=${internet.ok} error=${internet.error}');
    debugPrint('[Preflight] authReachable=${authHealth.ok} status=${authHealth.statusCode} detail=${authHealth.detail} error=${authHealth.error}');
    debugPrint('[Preflight] db=${database.ok} detail=${database.detail} error=${database.error}');
  }
}

class SupabasePreflight {
  static Future<SupabasePreflightResult> run({
    required EnvLoadResult env,
    required SupabaseClient client,
  }) async {
    final internet = await InternetChecker.check(timeout: const Duration(seconds: 6));

    var supabaseInitialized = true;
    try {
      Supabase.instance.client;
    } catch (_) {
      supabaseInitialized = false;
    }

    final authHealth = await AuthHealthProbe.check(env.env.supabaseUrl, timeout: const Duration(seconds: 8));

    final database = await _checkDatabase(client);

    return SupabasePreflightResult(
      supabaseInitialized: supabaseInitialized,
      internet: internet,
      authHealth: authHealth,
      database: database,
    );
  }

  static Future<({bool ok, String detail, Object? error})> _checkDatabase(SupabaseClient client) async {
    try {
      await client.from('profiles').select('id').limit(1).timeout(const Duration(seconds: 6));
      return (ok: true, detail: 'query_ok', error: null);
    } on TimeoutException catch (e) {
      return (ok: false, detail: 'timeout', error: e);
    } on PostgrestException catch (e) {
      return (ok: false, detail: 'postgrest status=${e.code} message=${e.message}', error: e);
    } catch (e) {
      return (ok: false, detail: e.runtimeType.toString(), error: e);
    }
  }
}
