import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';
import '../persistence/kv_store.dart';

const _areaKey = 'settings.area';

final areaControllerProvider = NotifierProvider<AreaController, String>(AreaController.new);

class AreaController extends Notifier<String> {
  @override
  String build() {
    _load();
    ref.listen(myProfileProvider, (_, next) {
      final area = next.valueOrNull?.area;
      if (area != null && area.trim().isNotEmpty) {
        state = area.trim();
      }
    });
    return 'Seef';
  }

  Future<void> _load() async {
    final raw = await ref.read(kvStoreProvider).read(_areaKey);
    if (raw == null || raw.trim().isEmpty) return;
    state = raw.trim();
  }

  Future<void> setArea(String area) async {
    final a = area.trim();
    if (a.isEmpty) return;
    state = a;
    await ref.read(kvStoreProvider).write(_areaKey, a);
    try {
      await ref.read(profileRepositoryProvider).upsertMyProfile(area: a);
      ref.invalidate(myProfileProvider);
    } catch (_) {}
  }
}

