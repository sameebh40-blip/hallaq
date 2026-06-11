import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/localization/area_controller.dart';
import '../data/nearby_repository.dart';
import '../models/nearby_listings.dart';

class NearbyShopsState {
  final List<NearbyShop> items;
  final bool hasMore;
  final bool hasLocation;

  const NearbyShopsState({required this.items, required this.hasMore, required this.hasLocation});

  NearbyShopsState copyWith({List<NearbyShop>? items, bool? hasMore, bool? hasLocation}) {
    return NearbyShopsState(items: items ?? this.items, hasMore: hasMore ?? this.hasMore, hasLocation: hasLocation ?? this.hasLocation);
  }
}

class NearbyShopsController extends AsyncNotifier<NearbyShopsState> {
  static const _pageSize = 12;
  bool _isLoadingMore = false;

  @override
  Future<NearbyShopsState> build() async {
    _isLoadingMore = false;
    ref.watch(areaControllerProvider);
    final loc = await ref.watch(effectiveLatLngProvider.future);
    if (loc == null) return const NearbyShopsState(items: [], hasMore: false, hasLocation: false);

    final items =
        await ref.watch(nearbyRepositoryProvider).listNearbyShops(lat: loc.lat, lng: loc.lng, limit: _pageSize, offset: 0);
    return NearbyShopsState(items: items, hasMore: items.length >= _pageSize, hasLocation: true);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    state = await AsyncValue.guard(() async {
      final loc = await ref.read(effectiveLatLngProvider.future);
      if (loc == null) return const NearbyShopsState(items: [], hasMore: false, hasLocation: false);
      final items = await ref.read(nearbyRepositoryProvider).listNearbyShops(lat: loc.lat, lng: loc.lng, limit: _pageSize, offset: 0);
      return NearbyShopsState(items: items, hasMore: items.length >= _pageSize, hasLocation: true);
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (_isLoadingMore || !current.hasMore) return;

    final loc = await ref.read(effectiveLatLngProvider.future);
    if (loc == null) return;

    _isLoadingMore = true;
    try {
      final more = await ref.read(nearbyRepositoryProvider).listNearbyShops(
            lat: loc.lat,
            lng: loc.lng,
            limit: _pageSize,
            offset: current.items.length,
          );
      final hasMore = more.length >= _pageSize;
      if (more.isEmpty) {
        state = AsyncData(current.copyWith(hasMore: false));
        return;
      }
      state = AsyncData(current.copyWith(items: [...current.items, ...more], hasMore: hasMore));
    } catch (e) {
      throw AppException('Failed to load more shops', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final nearbyShopsControllerProvider = AsyncNotifierProvider<NearbyShopsController, NearbyShopsState>(NearbyShopsController.new);
