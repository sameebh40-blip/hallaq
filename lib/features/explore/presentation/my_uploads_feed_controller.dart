import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../social/data/social_repository.dart';
import '../data/reels_repository.dart';
import '../models/explore_reel.dart';

class MyUploadsFeedController extends AsyncNotifier<List<ExploreReel>> {
  static const _pageSize = 30;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  Future<List<ExploreReel>> build() async {
    _isLoadingMore = false;
    _hasMore = true;
    final items = await ref.watch(reelsRepositoryProvider).listMyUploadsFeed(limit: _pageSize);
    if (items.length < _pageSize) _hasMore = false;
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    _hasMore = true;
    state = await AsyncValue.guard(() async {
      final items = await ref.read(reelsRepositoryProvider).listMyUploadsFeed(limit: _pageSize);
      if (items.length < _pageSize) _hasMore = false;
      return items;
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    try {
      final lastCreatedAt = current.last.reel.createdAt;
      final more = await ref.read(reelsRepositoryProvider).listMyUploadsFeed(limit: _pageSize, before: lastCreatedAt);
      if (more.length < _pageSize) _hasMore = false;

      if (more.isEmpty) return;

      final seen = current.map((e) => e.reel.id).toSet();
      final merged = [...current, ...more.where((e) => seen.add(e.reel.id))];
      state = AsyncData(merged);
    } catch (e) {
      throw AppException('Failed to load more uploads', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> toggleLike(String reelId) async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final idx = current.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current[idx];
    final nextLiked = !item.isLiked;
    final nextLikes = (item.reel.likesCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30).toInt();
    final optimistic = [
      ...current.sublist(0, idx),
      item.copyWith(
        isLiked: nextLiked,
        reel: item.reel.copyWith(likesCount: nextLikes),
      ),
      ...current.sublist(idx + 1),
    ];

    state = AsyncData(optimistic);
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
    if (current == null || current.isEmpty) return;

    final idx = current.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current[idx];
    final nextSaved = !item.isSaved;
    final nextSaves = (item.reel.savesCount + (nextSaved ? 1 : -1)).clamp(0, 1 << 30).toInt();
    final optimistic = [
      ...current.sublist(0, idx),
      item.copyWith(isSaved: nextSaved, reel: item.reel.copyWith(savesCount: nextSaves)),
      ...current.sublist(idx + 1),
    ];

    state = AsyncData(optimistic);
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

  Future<void> toggleFollow(ExploreAuthor author) async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final first =
        current.firstWhere((e) => e.author.id == author.id && e.author.type == author.type, orElse: () => current.first);
    final nextFollowing = !first.isFollowing;

    final optimistic = current
        .map((e) => e.author.id == author.id && e.author.type == author.type ? e.copyWith(isFollowing: nextFollowing) : e)
        .toList(growable: false);

    state = AsyncData(optimistic);
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

  void bumpCommentsCount(String reelId, {int delta = 1}) {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final idx = current.indexWhere((e) => e.reel.id == reelId);
    if (idx == -1) return;

    final item = current[idx];
    final next = (item.reel.commentsCount + delta).clamp(0, 1 << 30).toInt();
    final updated = [
      ...current.sublist(0, idx),
      item.copyWith(reel: item.reel.copyWith(commentsCount: next)),
      ...current.sublist(idx + 1),
    ];
    state = AsyncData(updated);
  }
}

final myUploadsFeedControllerProvider = AsyncNotifierProvider<MyUploadsFeedController, List<ExploreReel>>(
  MyUploadsFeedController.new,
);
