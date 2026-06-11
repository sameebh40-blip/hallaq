import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http/io_client.dart';

import 'trusted_certificates.dart';

class HttpClientFactoryImpl {
  static Client? create() {
    try {
      final ctx = SecurityContext(withTrustedRoots: true);
      try {
        ctx.setTrustedCertificatesBytes(Uint8List.fromList(utf8.encode(isrgRootX1Pem)));
      } catch (_) {}
      final httpClient = HttpClient(context: ctx);
      httpClient.connectionTimeout = const Duration(seconds: 20);
      return IOClient(httpClient);
    } catch (_) {
      return IOClient();
    }
  }
}
