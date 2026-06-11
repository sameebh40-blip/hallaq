import 'auth_health_probe_stub.dart' if (dart.library.html) 'auth_health_probe_web.dart' if (dart.library.io) 'auth_health_probe_io.dart';

abstract class AuthHealthProbe {
  static Future<({bool ok, int? statusCode, String detail, Object? error})> check(
    String supabaseUrl, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    return AuthHealthProbeImpl.check(supabaseUrl, timeout: timeout);
  }
}

