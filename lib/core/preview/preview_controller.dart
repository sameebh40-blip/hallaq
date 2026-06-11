import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kv_store.dart';

const _previewKey = 'app.preview';

final previewControllerProvider = NotifierProvider<PreviewController, bool>(PreviewController.new);

class PreviewController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final store = ref.read(kvStoreProvider);
    final raw = await store.read(_previewKey);
    if (raw == '1') state = true;
  }

  Future<void> setPreview(bool enabled) async {
    final store = ref.read(kvStoreProvider);
    state = enabled;
    if (enabled) {
      await store.write(_previewKey, '1');
    } else {
      await store.delete(_previewKey);
    }
  }
}

