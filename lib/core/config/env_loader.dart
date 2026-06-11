import 'env.dart';

enum EnvSource {
  dartDefine,
  missing,
}

class EnvLoadResult {
  final Env env;
  final EnvSource source;
  final bool hasUrl;
  final bool hasAnonKey;
  final int urlLength;
  final int anonKeyLength;

  const EnvLoadResult({
    required this.env,
    required this.source,
    required this.hasUrl,
    required this.hasAnonKey,
    required this.urlLength,
    required this.anonKeyLength,
  });
}

class EnvLoader {
  static Future<EnvLoadResult> load() async {
    final fromDefines = Env.fromDartDefines();
    if (_isConfigured(fromDefines)) {
      return _result(fromDefines, EnvSource.dartDefine);
    }

    return _result(fromDefines, EnvSource.missing);
  }

  static EnvLoadResult _result(Env env, EnvSource source) {
    final url = env.supabaseUrl;
    final key = env.supabaseAnonKey;
    return EnvLoadResult(
      env: env,
      source: source,
      hasUrl: url.isNotEmpty,
      hasAnonKey: key.isNotEmpty,
      urlLength: url.length,
      anonKeyLength: key.length,
    );
  }

  static bool _isConfigured(Env env) {
    final url = env.supabaseUrl;
    final key = env.supabaseAnonKey;
    return url.isNotEmpty && key.isNotEmpty && !url.contains('YOUR_PROJECT') && !key.contains('YOUR_ANON_KEY');
  }
}
