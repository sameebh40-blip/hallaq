import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/analytics/analytics_repository.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/reel.dart';
import '../models/explore_reel.dart';

class ExploreReelPlayersState {
  final int? activeIndex;
  final Map<int, VideoPlayerController> controllers;
  final bool muted;
  final Set<int> failed;

  const ExploreReelPlayersState({required this.activeIndex, required this.controllers, required this.muted, required this.failed});

  ExploreReelPlayersState copyWith({int? activeIndex, Map<int, VideoPlayerController>? controllers, bool? muted, Set<int>? failed}) {
    return ExploreReelPlayersState(
      activeIndex: activeIndex,
      controllers: controllers ?? this.controllers,
      muted: muted ?? this.muted,
      failed: failed ?? this.failed,
    );
  }
}

class ExploreReelPlayerWindow extends AutoDisposeNotifier<ExploreReelPlayersState> {
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, int> _initTokens = {};
  final Set<int> _failed = {};
  Timer? _watchTimer;
  String? _watchReelId;
  int _watchMs = 0;
  bool _watchCompleted = false;
  int? _watchDurationMs;
  bool _muted = kIsWeb;

  @override
  ExploreReelPlayersState build() {
    ref.onDispose(() {
      unawaited(_stopWatchAndReport());
      for (final c in _controllers.values) {
        try {
          c.pause();
        } catch (_) {}
        c.dispose();
      }
      _controllers.clear();
      _initTokens.clear();
      _failed.clear();
      _watchTimer?.cancel();
      _watchTimer = null;
    });
    return ExploreReelPlayersState(activeIndex: null, controllers: const {}, muted: _muted, failed: const {});
  }

  void setMuted(bool muted) {
    _muted = muted;
    for (final c in _controllers.values) {
      try {
        unawaited(c.setVolume(muted ? 0 : 1));
      } catch (_) {}
    }
    state = state.copyWith(muted: muted, controllers: Map<int, VideoPlayerController>.from(_controllers), failed: Set<int>.from(_failed));
  }

  Future<void> setActive({required int? index, required List<ExploreReel> items}) async {
    await _stopWatchAndReport();
    if (index == null || index < 0 || index >= items.length) {
      _disposeAll();
      state = state.copyWith(activeIndex: null, controllers: {}, failed: const {});
      return;
    }

    final wanted = <int>{index};
    if (index - 1 >= 0) wanted.add(index - 1);
    if (index + 1 < items.length) wanted.add(index + 1);
    if (index + 2 < items.length) wanted.add(index + 2);

    final toRemove = _controllers.keys.where((k) => !wanted.contains(k)).toList(growable: false);
    for (final k in toRemove) {
      _disposeIndex(k);
    }
    _failed.removeWhere((i) => !wanted.contains(i));

    state = state.copyWith(activeIndex: index, controllers: Map<int, VideoPlayerController>.from(_controllers), failed: Set<int>.from(_failed));

    final activeReel = items[index].reel;
    if (activeReel.mediaType == 'video') {
      _startWatch(index, activeReel);
    }

    for (final i in wanted) {
      final reel = items[i].reel;
      if (reel.mediaType != 'video') {
        if (_controllers.containsKey(i)) _disposeIndex(i);
        continue;
      }
      if (!_controllers.containsKey(i)) {
        unawaited(_createAndInit(i, reel, autoplay: i == index));
      } else {
        final c = _controllers[i]!;
        if (i == index) {
          if (c.value.isInitialized) {
            unawaited(c.play());
          }
        } else {
          unawaited(c.pause());
        }
      }
    }

    state = state.copyWith(activeIndex: index, controllers: Map<int, VideoPlayerController>.from(_controllers), failed: Set<int>.from(_failed));
  }

  Future<void> retryIndex({required int index, required Reel reel, bool autoplay = true}) async {
    if (index < 0) return;
    _disposeIndex(index);
    _failed.remove(index);
    state = state.copyWith(controllers: Map<int, VideoPlayerController>.from(_controllers), failed: Set<int>.from(_failed));
    unawaited(_createAndInit(index, reel, autoplay: autoplay));
  }

  void _startWatch(int index, Reel reel) {
    _watchTimer?.cancel();
    _watchTimer = null;
    _watchReelId = reel.id;
    _watchMs = 0;
    _watchCompleted = false;
    _watchDurationMs = null;

    _watchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final active = state.activeIndex;
      if (active != index) return;
      final c = _controllers[index];
      if (c == null) return;
      final v = c.value;
      if (!v.isInitialized) return;
      _watchDurationMs = v.duration.inMilliseconds;
      if (!v.isPlaying) return;
      _watchMs += 500;
      final dur = v.duration.inMilliseconds;
      if (dur > 0) {
        final pos = v.position.inMilliseconds;
        if (pos / dur >= 0.95) _watchCompleted = true;
      }
    });
  }

  Future<void> _stopWatchAndReport() async {
    _watchTimer?.cancel();
    _watchTimer = null;
    final reelId = _watchReelId;
    final watched = _watchMs;
    final completed = _watchCompleted;
    final durationMs = _watchDurationMs;
    _watchReelId = null;
    _watchMs = 0;
    _watchCompleted = false;
    _watchDurationMs = null;

    if (reelId == null || watched <= 0) return;
    try {
      await ref.read(analyticsRepositoryProvider).track(
            eventName: 'reel_watch',
            entityType: 'reel',
            entityId: reelId,
            meta: {
              'watched_ms': watched,
              'completed': completed,
              if (durationMs != null) 'duration_ms': durationMs,
            },
          );
    } catch (_) {}
  }

  void _disposeAll() {
    for (final k in _controllers.keys.toList(growable: false)) {
      _disposeIndex(k);
    }
  }

  void _disposeIndex(int index) {
    final c = _controllers.remove(index);
    _initTokens.remove(index);
    if (c == null) return;
    try {
      c.pause();
    } catch (_) {}
    c.dispose();
  }

  Future<void> _createAndInit(int index, Reel reel, {required bool autoplay}) async {
    final token = (_initTokens[index] ?? 0) + 1;
    _initTokens[index] = token;

    final legacy = reel.mediaUrl.trim();
    final bucket = (reel.mediaBucket ?? '').trim();
    final url = legacy.startsWith('http://') || legacy.startsWith('https://')
        ? legacy
        : (bucket.isNotEmpty)
            ? await ref.read(mediaServiceProvider).resolveMediaUrl(
                  bucket: bucket,
                  path: reel.mediaPath,
                  legacyUrlOrPath: reel.mediaUrl,
                )
            : await ref.read(mediaServiceProvider).resolveMediaUrlMulti(
                  buckets: const ['reels', 'reels-media'],
                  path: reel.mediaPath,
                  legacyUrlOrPath: reel.mediaUrl,
                );

    if (kDebugMode) {
      debugPrint('[Explore] video_url_resolve index=$index reel=${reel.id} ok=${url != null && url.trim().isNotEmpty}');
    }
    if (url == null || url.trim().isEmpty) {
      _failed.add(index);
      state = state.copyWith(failed: Set<int>.from(_failed), controllers: Map<int, VideoPlayerController>.from(_controllers));
      return;
    }
    if (_initTokens[index] != token) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;
    state = state.copyWith(controllers: Map<int, VideoPlayerController>.from(_controllers));

    try {
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('[Explore] video_init_success index=$index reel=${reel.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Explore] video_init_fail index=$index reel=${reel.id}');
      }
      try {
        await ref.read(analyticsRepositoryProvider).track(
              eventName: 'reel_video_init_fail',
              entityType: 'reel',
              entityId: reel.id,
              meta: {'index': index, 'error': e.toString()},
            );
      } catch (_) {}
      if (_controllers[index] == controller) {
        _disposeIndex(index);
        state = state.copyWith(controllers: Map<int, VideoPlayerController>.from(_controllers));
      }
      _failed.add(index);
      state = state.copyWith(failed: Set<int>.from(_failed), controllers: Map<int, VideoPlayerController>.from(_controllers));
      return;
    }

    if (_initTokens[index] != token) {
      controller.dispose();
      if (_controllers[index] == controller) {
        _controllers.remove(index);
        state = state.copyWith(controllers: Map<int, VideoPlayerController>.from(_controllers));
      }
      return;
    }

    unawaited(controller.setLooping(true));
    unawaited(controller.setVolume(_muted ? 0 : 1));

    final active = state.activeIndex;
    if (autoplay && active == index) {
      unawaited(controller.play().catchError((_) {}));
    } else {
      unawaited(controller.pause().catchError((_) {}));
    }

    state = state.copyWith(controllers: Map<int, VideoPlayerController>.from(_controllers));
  }
}

final exploreReelPlayerWindowProvider = AutoDisposeNotifierProvider<ExploreReelPlayerWindow, ExploreReelPlayersState>(
  ExploreReelPlayerWindow.new,
);
