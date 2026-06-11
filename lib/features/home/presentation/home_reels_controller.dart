import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../explore/data/reels_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/reel.dart';

class HomeReelsState {
  final List<Reel> items;
  final bool hasMore;

  const HomeReelsState({required this.items, required this.hasMore});

  HomeReelsState copyWith({List<Reel>? items, bool? hasMore}) {
    return HomeReelsState(items: items ?? this.items, hasMore: hasMore ?? this.hasMore);
  }
}

class HomeReelsController extends FamilyAsyncNotifier<HomeReelsState, String?> {
  static const _pageSize = 10;
  bool _isLoadingMore = false;

  @override
  Future<HomeReelsState> build(String? cityId) async {
    _isLoadingMore = false;
    final items = await ref.watch(reelsRepositoryProvider).listApproved(limit: _pageSize, cityId: cityId);
    return HomeReelsState(items: items, hasMore: items.length >= _pageSize);
  }

  Future<void> refresh(String? cityId) async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    state = await AsyncValue.guard(() async {
      final items = await ref.read(reelsRepositoryProvider).listApproved(limit: _pageSize, cityId: cityId);
      return HomeReelsState(items: items, hasMore: items.length >= _pageSize);
    });
  }

  Future<void> loadMore(String? cityId) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;
    if (_isLoadingMore || !current.hasMore) return;

    _isLoadingMore = true;
    try {
      final lastCreatedAt = current.items.last.createdAt;
      final more = await ref.read(reelsRepositoryProvider).listApproved(limit: _pageSize, before: lastCreatedAt, cityId: cityId);
      final hasMore = more.length >= _pageSize;
      if (more.isEmpty) {
        state = AsyncData(current.copyWith(hasMore: false));
        return;
      }
      final seen = current.items.map((e) => e.id).toSet();
      final merged = [...current.items, ...more.where((e) => seen.add(e.id))];
      state = AsyncData(current.copyWith(items: merged, hasMore: hasMore));
    } catch (e) {
      throw AppException('Failed to load more reels', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final homeReelsControllerProvider = AsyncNotifierProviderFamily<HomeReelsController, HomeReelsState, String?>(HomeReelsController.new);
