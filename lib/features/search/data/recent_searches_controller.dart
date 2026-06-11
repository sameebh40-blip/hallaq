import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/kv_store.dart';

const _recentKey = 'search.recent';

final recentSearchesProvider = NotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);

class RecentSearchesController extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final raw = await ref.read(kvStoreProvider).read(_recentKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).map((e) => (e as String).trim()).where((e) => e.isNotEmpty).toList();
      state = list.take(8).toList();
    } catch (_) {}
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ...state.where((e) => e.toLowerCase() != q.toLowerCase())].take(8).toList();
    state = next;
    await ref.read(kvStoreProvider).write(_recentKey, jsonEncode(next));
  }

  Future<void> remove(String query) async {
    final next = state.where((e) => e.toLowerCase() != query.toLowerCase()).toList();
    state = next;
    if (next.isEmpty) {
      await ref.read(kvStoreProvider).delete(_recentKey);
      return;
    }
    await ref.read(kvStoreProvider).write(_recentKey, jsonEncode(next));
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(kvStoreProvider).delete(_recentKey);
  }
}

