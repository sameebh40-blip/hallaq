import 'package:http/http.dart';

import 'http_client_factory_stub.dart' if (dart.library.io) 'http_client_factory_io.dart';

abstract class HttpClientFactory {
  static Client? create() {
    return HttpClientFactoryImpl.create();
  }
}
