import 'package:flutter/foundation.dart';

class AppLinks {
  static const _fallbackOrigin = String.fromEnvironment('APP_ORIGIN', defaultValue: 'https://app.hallaq.com');

  static String origin() {
    if (kIsWeb) return Uri.base.origin;
    return _fallbackOrigin;
  }

  static String barberProfile(String slug) => '${origin()}/barber/$slug';
  static String shopProfile(String id) => '${origin()}/shop/$id';
  static String reel(String id) => '${origin()}/discover?reel=$id';
}
