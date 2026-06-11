import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kv_store.dart';

const _themeModeKey = 'settings.themeMode';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final store = ref.read(kvStoreProvider);
    final raw = await store.read(_themeModeKey);
    if (raw == null) return;
    state = ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final store = ref.read(kvStoreProvider);
    state = ThemeMode.light;
    await store.write(_themeModeKey, 'light');
  }
}
