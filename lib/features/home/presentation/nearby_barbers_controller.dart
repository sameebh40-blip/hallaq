import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/localization/area_controller.dart';
import '../data/nearby_repository.dart';
import '../models/nearby_listings.dart';

class NearbyBarbersState {
  final List<NearbyBarber> items;
  final bool hasMore;
  final bool hasLocation;

  const NearbyBarbersState({required this.items, required this.hasMore, required this.hasLocation});

  NearbyBarbersState copyWith({List<NearbyBarber>? items, bool? hasMore, bool? hasLocation}) {
    return NearbyBarbersState(items: items ?? this.items, hasMore: hasMore ?? this.hasMore, hasLocation: hasLocation ?? this.hasLocation);
  }
}

class NearbyBarbersController extends AsyncNotifier<NearbyBarbersState> {
  static const _pageSize = 12;
  bool _isLoadingMore = false;

  @override
  Future<NearbyBarbersState> build() async {
    _isLoadingMore = false;
    ref.watch(areaControllerProvider);
    final loc = await ref.watch(effectiveLatLngProvider.future);
    if (loc == null) return const NearbyBarbersState(items: [], hasMore: false, hasLocation: false);

    final items =
        await ref.watch(nearbyRepositoryProvider).listNearbyBarbers(lat: loc.lat, lng: loc.lng, limit: _pageSize, offset: 0);
    return NearbyBarbersState(items: items, hasMore: items.length >= _pageSize, hasLocation: true);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    state = await AsyncValue.guard(() async {
      final loc = await ref.read(effectiveLatLngProvider.future);
      if (loc == null) return const NearbyBarbersState(items: [], hasMore: false, hasLocation: false);
      final items = await ref.read(nearbyRepositoryProvider).listNearbyBarbers(lat: loc.lat, lng: loc.lng, limit: _pageSize, offset: 0);
      return NearbyBarbersState(items: items, hasMore: items.length >= _pageSize, hasLocation: true);
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
      final more = await ref.read(nearbyRepositoryProvider).listNearbyBarbers(
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
      throw AppException('Failed to load more barbers', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final nearbyBarbersControllerProvider = AsyncNotifierProvider<NearbyBarbersController, NearbyBarbersState>(NearbyBarbersController.new);
