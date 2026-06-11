import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kv_store.dart';

const _demoModeKey = 'settings.demo_mode';

final demoModeProvider = NotifierProvider<DemoModeController, bool>(DemoModeController.new);

class DemoModeController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final store = ref.read(kvStoreProvider);
    final raw = await store.read(_demoModeKey);
    if (raw == '1') state = true;
  }

  Future<void> setDemoMode(bool enabled) async {
    final store = ref.read(kvStoreProvider);
    state = enabled;
    if (enabled) {
      await store.write(_demoModeKey, '1');
    } else {
      await store.delete(_demoModeKey);
    }
  }
}
