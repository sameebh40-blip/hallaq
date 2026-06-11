import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kv_store.dart';

const _localeKey = 'settings.locale';

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final store = ref.read(kvStoreProvider);
    final raw = await store.read(_localeKey);
    if (raw == null || raw.isEmpty) return;
    state = Locale(raw);
  }

  Future<void> setLocale(Locale? locale) async {
    final store = ref.read(kvStoreProvider);
    state = locale;
    if (locale == null) {
      await store.delete(_localeKey);
      return;
    }
    await store.write(_localeKey, locale.languageCode);
  }
}

