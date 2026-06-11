import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/my_bookings_repository.dart';
import '../models/my_booking_card.dart';

class MyBookingsController extends AutoDisposeFamilyAsyncNotifier<List<MyBookingCard>, BookingsTab> {
  static const _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  Future<List<MyBookingCard>> build(BookingsTab arg) async {
    _isLoadingMore = false;
    _hasMore = true;

    final items = await ref.watch(myBookingsRepositoryProvider).listMyBookings(
          tab: arg,
          limit: _pageSize,
        );
    if (items.length < _pageSize) _hasMore = false;
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _isLoadingMore = false;
    _hasMore = true;

    state = await AsyncValue.guard(() async {
      final items = await ref.read(myBookingsRepositoryProvider).listMyBookings(tab: arg, limit: _pageSize);
      if (items.length < _pageSize) _hasMore = false;
      return items;
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (_isLoadingMore || !_hasMore) return;
    if (current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final cursor = current.last.startAt;
      final more = await ref.read(myBookingsRepositoryProvider).listMyBookings(
            tab: arg,
            limit: _pageSize,
            cursorStartAt: cursor,
          );
      if (more.length < _pageSize) _hasMore = false;
      if (more.isEmpty) return;

      final seen = current.map((e) => e.id).toSet();
      final merged = [...current, ...more.where((e) => seen.add(e.id))];
      state = AsyncData(merged);
    } catch (e) {
      throw AppException('Failed to load more bookings', cause: e);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final myBookingsControllerProvider =
    AsyncNotifierProvider.family.autoDispose<MyBookingsController, List<MyBookingCard>, BookingsTab>(
  MyBookingsController.new,
);
