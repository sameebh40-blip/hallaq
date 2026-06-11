import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HallaqHaptics {
  static bool get _enabled {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  static void tap() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  static void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void error() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }
}
