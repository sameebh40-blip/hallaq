import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'trusted_certificates.dart';

class AuthHealthProbeImpl {
  static Future<({bool ok, int? statusCode, String detail, Object? error})> check(
    String supabaseUrl, {
    required Duration timeout,
  }) async {
    final client = _httpClient(timeout: timeout);
    client.connectionTimeout = timeout;

    try {
      final primary = Uri.parse(supabaseUrl).replace(
        path: '/auth/v1/health',
        queryParameters: const {'full': 'true'},
      );
      final res1 = await _get(client, primary, timeout: timeout);
      if (res1.ok || res1.statusCode == 404) {
        if (res1.ok) return res1;
        final fallback = Uri.parse(supabaseUrl).replace(path: '/auth/v1/settings');
        final res2 = await _get(client, fallback, timeout: timeout);
        return res2.ok
            ? (ok: true, statusCode: res2.statusCode, detail: 'fallback_settings_ok ${res2.detail}', error: null)
            : (ok: false, statusCode: res2.statusCode, detail: 'fallback_settings_failed ${res2.detail}', error: res2.error);
      }
      return res1;
    } on TimeoutException catch (e) {
      return (ok: false, statusCode: null, detail: 'timeout', error: e);
    } on SocketException catch (e) {
      return (ok: false, statusCode: null, detail: 'socket', error: e);
    } on HandshakeException catch (e) {
      return (ok: false, statusCode: null, detail: 'tls_handshake', error: e);
    } on TlsException catch (e) {
      return (ok: false, statusCode: null, detail: 'tls', error: e);
    } catch (e) {
      return (ok: false, statusCode: null, detail: 'error', error: e);
    } finally {
      client.close(force: true);
    }
  }

  static HttpClient _httpClient({required Duration timeout}) {
    try {
      final ctx = SecurityContext(withTrustedRoots: true);
      try {
        ctx.setTrustedCertificatesBytes(Uint8List.fromList(utf8.encode(isrgRootX1Pem)));
      } catch (_) {}
      final c = HttpClient(context: ctx);
      c.connectionTimeout = timeout;
      return c;
    } catch (_) {
      final c = HttpClient();
      c.connectionTimeout = timeout;
      return c;
    }
  }

  static Future<({bool ok, int? statusCode, String detail, Object? error})> _get(
    HttpClient client,
    Uri uri, {
    required Duration timeout,
  }) async {
    final req = await client.getUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final res = await req.close().timeout(timeout);
    final status = res.statusCode;
    final body = await utf8.decodeStream(res).timeout(timeout);
    final ok = status >= 200 && status < 300;
    final detail = body.isEmpty ? 'status=$status path=${uri.path}' : 'status=$status path=${uri.path} body=${_trim(body)}';
    return (ok: ok, statusCode: status, detail: detail, error: ok ? null : body);
  }

  static String _trim(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 220) return t;
    return '${t.substring(0, 220)}…';
  }
}
