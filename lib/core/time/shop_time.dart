import 'package:flutter/foundation.dart';

class ShopTime {
  static const timezoneName = 'Asia/Bahrain';
  static const utcOffset = Duration(hours: 3);

  static DateTime now() {
    return DateTime.now().toUtc().add(utcOffset);
  }

  static DateTime fromUtc(DateTime utc) {
    final u = utc.toUtc();
    final s = u.add(utcOffset);
    return DateTime(s.year, s.month, s.day, s.hour, s.minute, s.second, s.millisecond, s.microsecond);
  }

  static DateTime toUtc(DateTime shopLocal) {
    final s = DateTime.utc(
      shopLocal.year,
      shopLocal.month,
      shopLocal.day,
      shopLocal.hour,
      shopLocal.minute,
      shopLocal.second,
      shopLocal.millisecond,
      shopLocal.microsecond,
    );
    return s.subtract(utcOffset);
  }

  static DateTime dateTime(int year, int month, int day, int hour, int minute) {
    return DateTime(year, month, day, hour, minute);
  }

  static void debugLog(String message) {
    if (kDebugMode) debugPrint('[ShopTime/$timezoneName] $message');
  }
}

