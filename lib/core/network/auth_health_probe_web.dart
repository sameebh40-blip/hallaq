class AuthHealthProbeImpl {
  static Future<({bool ok, int? statusCode, String detail, Object? error})> check(
    String supabaseUrl, {
    required Duration timeout,
  }) async {
    return (ok: true, statusCode: null, detail: 'skipped_on_web', error: null);
  }
}

