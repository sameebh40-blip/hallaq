import 'dart:async';
import 'dart:io';

class InternetCheckerImpl {
  static Future<({bool ok, Object? error})> check({required Duration timeout}) async {
    try {
      final res = await InternetAddress.lookup('one.one.one.one').timeout(timeout);
      final ok = res.isNotEmpty && res.first.rawAddress.isNotEmpty;
      return (ok: ok, error: ok ? null : 'DNS lookup returned empty');
    } on TimeoutException catch (e) {
      return (ok: false, error: e);
    } on SocketException catch (e) {
      return (ok: false, error: e);
    } catch (e) {
      return (ok: false, error: e);
    }
  }
}

