class InternetCheckerImpl {
  static Future<({bool ok, Object? error})> check({required Duration timeout}) async {
    return (ok: false, error: 'Unsupported platform');
  }
}

