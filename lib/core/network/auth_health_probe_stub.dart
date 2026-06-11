class AuthHealthProbeImpl {
  static Future<({bool ok, int? statusCode, String detail, Object? error})> check(
    String supabaseUrl, {
    required Duration timeout,
  }) async {
    return (ok: false, statusCode: null, detail: 'Unsupported platform', error: 'Unsupported platform');
  }
}

