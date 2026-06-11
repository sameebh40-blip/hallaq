import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kv_store.dart';

const _onboardingSeenKey = 'onboarding.seen';

final onboardingSeenFutureProvider = FutureProvider<bool>((ref) async {
  final store = ref.read(kvStoreProvider);
  final raw = await store.read(_onboardingSeenKey);
  return raw == '1';
});

final onboardingSeenProvider = NotifierProvider<OnboardingSeenController, bool>(OnboardingSeenController.new);

class OnboardingSeenController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final store = ref.read(kvStoreProvider);
    final raw = await store.read(_onboardingSeenKey);
    if (raw == '1') state = true;
  }

  Future<void> markSeen() async {
    final store = ref.read(kvStoreProvider);
    state = true;
    await store.write(_onboardingSeenKey, '1');
  }

  Future<void> reset() async {
    final store = ref.read(kvStoreProvider);
    state = false;
    await store.delete(_onboardingSeenKey);
  }
}
