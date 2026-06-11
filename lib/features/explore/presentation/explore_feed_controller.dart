import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../social/data/social_repository.dart';
import '../data/reels_repository.dart';
import '../models/explore_reel.dart';

class ExploreFeedState {
  final List<ExploreReel> items;
  final bool hasMore;

  const ExploreFeedState({required this.items, required this.hasMore});

  ExploreFeedState copyWith({List<ExploreReel>? items, bool? hasMore}) {
    return ExploreFeedState(items: items ?? this.items, hasMore: hasMore ?? this.hasMore);
  }
}

class ExploreFeedController extends AsyncNotifier<ExploreFeedState> {
  static const _pageSize = 30;
  bool _isLoadingMore = false;

  @override
  Future<ExploreFeedState> build() async {
    _isLoadingMore = false;
    final items = await ref.watch(reelsRepositoryProvider).listExploreFeed(limit: _pageSize);
    return ExploreFeedState(items: items, hasMore: items.length >= _pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    state = await AsyncValue.guard(() async {
      final items = await ref.read(reelsRepositoryProvider).listExploreFeed(limit: _pageSize);
      return ExploreFeedState(items: items, hasMore: items.length >= _pageSize);
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;
    if (_isLoadingMore || !current.hasMore) return;

    _isLoadingMore = true;
    try {
      final lastCreatedAt = current.items.last.reel.createdAt;
      final more = await ref.read(reelsRepositoryProvider).listExploreFeed(limit: _pageSize, before: lastCreatedAt);
      final hasMore = more.length >= _pageSize;

      if (more.isEmpty) {
        state = AsyncData(current.copyWith(hasMore: false));
        return;
      }

      final seen = current.items.map((e) => e.reel.id).toSet();
      final merged = [...current.items, ...more.where((e) => seen.add(e.reel.id))];
      state = AsyncData(current.copyWith(items: merged, hasMore: hasMore));
    } catch (e) {
      throw AppException('Failed to load more reels', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> toggleLike(String reelId) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final idx = current.items.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current.items[idx];
    final nextLiked = !item.isLiked;
    final nextLikes = (item.reel.likesCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30).toInt();
    final optimistic = [
      ...current.items.sublist(0, idx),
      item.copyWith(
        isLiked: nextLiked,
        reel: item.reel.copyWith(likesCount: nextLikes),
      ),
      ...current.items.sublist(idx + 1),
    ];

    state = AsyncData(current.copyWith(items: optimistic));
    try {
      final repo = ref.read(reelsRepositoryProvider);
      if (nextLiked) {
        await repo.like(reelId);
      } else {
        await repo.unlike(reelId);
      }
    } catch (e) {
      state = AsyncData(current);
      throw AppException('Failed to update like', cause: e);
    }
  }

  Future<void> toggleSave(String reelId) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final idx = current.items.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current.items[idx];
    final nextSaved = !item.isSaved;
    final nextSaves = (item.reel.savesCount + (nextSaved ? 1 : -1)).clamp(0, 1 << 30).toInt();
    final optimistic = [
      ...current.items.sublist(0, idx),
      item.copyWith(isSaved: nextSaved, reel: item.reel.copyWith(savesCount: nextSaves)),
      ...current.items.sublist(idx + 1),
    ];

    state = AsyncData(current.copyWith(items: optimistic));
    try {
      final repo = ref.read(reelsRepositoryProvider);
      if (nextSaved) {
        await repo.save(reelId);
      } else {
        await repo.unsave(reelId);
      }
    } catch (e) {
      state = AsyncData(current);
      throw AppException('Failed to update save', cause: e);
    }
  }

  Future<void> share(String reelId) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final idx = current.items.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current.items[idx];
    final nextShares = (item.reel.sharesCount + 1).clamp(0, 1 << 30).toInt();
    final optimistic = [
      ...current.items.sublist(0, idx),
      item.copyWith(reel: item.reel.copyWith(sharesCount: nextShares)),
      ...current.items.sublist(idx + 1),
    ];
    state = AsyncData(current.copyWith(items: optimistic));

    try {
      final repo = ref.read(reelsRepositoryProvider);
      final updated = await repo.incrementShare(reelId);
      if (updated <= 0) return;

      final latest = state.valueOrNull;
      if (latest == null) return;
      final finalItems = [
        ...latest.items.sublist(0, idx),
        latest.items[idx].copyWith(reel: latest.items[idx].reel.copyWith(sharesCount: updated)),
        ...latest.items.sublist(idx + 1),
      ];
      state = AsyncData(latest.copyWith(items: finalItems));
    } catch (e) {
      state = AsyncData(current);
      throw AppException('Failed to share', cause: e);
    }
  }

  Future<void> toggleFollow(ExploreAuthor author) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final first =
        current.items.firstWhere((e) => e.author.id == author.id && e.author.type == author.type, orElse: () => current.items.first);
    final nextFollowing = !first.isFollowing;

    final optimistic = current.items
        .map((e) => e.author.id == author.id && e.author.type == author.type ? e.copyWith(isFollowing: nextFollowing) : e)
        .toList(growable: false);

    state = AsyncData(current.copyWith(items: optimistic));
    try {
      final social = ref.read(socialRepositoryProvider);
      final targetType = author.type == ExploreAuthorType.barber ? 'barber' : 'shop';
      if (nextFollowing) {
        await social.follow(targetType: targetType, targetId: author.id);
      } else {
        await social.unfollow(targetType: targetType, targetId: author.id);
      }
    } catch (e) {
      state = AsyncData(current);
      throw AppException('Failed to update follow', cause: e);
    }
  }

  Future<void> hideReel(String reelId) async {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final idx = current.items.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final optimistic = [
      ...current.items.sublist(0, idx),
      ...current.items.sublist(idx + 1),
    ];
    state = AsyncData(current.copyWith(items: optimistic));
    try {
      await ref.read(reelsRepositoryProvider).hide(reelId);
    } catch (e) {
      state = AsyncData(current);
      throw AppException('Failed to hide reel', cause: e);
    }
  }

  void bumpCommentsCount(String reelId, {int delta = 1}) {
    final current = state.valueOrNull;
    if (current == null || current.items.isEmpty) return;

    final idx = current.items.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current.items[idx];
    final next = (item.reel.commentsCount + delta).clamp(0, 1 << 30).toInt();
    final updated = [
      ...current.items.sublist(0, idx),
      item.copyWith(reel: item.reel.copyWith(commentsCount: next)),
      ...current.items.sublist(idx + 1),
    ];
    state = AsyncData(current.copyWith(items: updated));
  }
}

final exploreFeedControllerProvider = AsyncNotifierProvider<ExploreFeedController, ExploreFeedState>(
  ExploreFeedController.new,
);
