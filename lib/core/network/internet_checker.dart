import 'internet_checker_stub.dart' if (dart.library.html) 'internet_checker_web.dart' if (dart.library.io) 'internet_checker_io.dart';

abstract class InternetChecker {
  static Future<({bool ok, Object? error})> check({Duration timeout = const Duration(seconds: 3)}) {
    return InternetCheckerImpl.check(timeout: timeout);
  }
}

