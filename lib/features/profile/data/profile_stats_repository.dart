import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ProfileStats {
  final int totalBookings;
  final double averageRating;
  final int favoriteBarbers;
  final int loyaltyPoints;
  final int upcomingBookingsCount;
  final int completedBookingsCount;
  final int savedBarbersCount;
  final int savedShopsCount;

  const ProfileStats({
    required this.totalBookings,
    required this.averageRating,
    required this.favoriteBarbers,
    required this.upcomingBookingsCount,
    required this.completedBookingsCount,
    required this.savedBarbersCount,
    required this.savedShopsCount,
    required this.loyaltyPoints,
  });

  static const empty = ProfileStats(
    totalBookings: 0,
    averageRating: 0,
    favoriteBarbers: 0,
    upcomingBookingsCount: 0,
    completedBookingsCount: 0,
    savedBarbersCount: 0,
    savedShopsCount: 0,
    loyaltyPoints: 0,
  );
}

class ProfileStatsRepository {
  final SupabaseClient _client;

  ProfileStatsRepository(this._client);

  Stream<ProfileStats> watchMyStats() async* {
    final user = _client.auth.currentUser;
    if (user == null) {
      yield ProfileStats.empty;
      return;
    }

    yield await loadMyStats();

    final refresh = StreamController<void>();

    var scheduled = false;
    Timer? timer;

    void scheduleRefresh() {
      if (scheduled) return;
      scheduled = true;
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 300), () {
        scheduled = false;
        if (!refresh.isClosed) refresh.add(null);
      });
    }

    final bookingsSub =
        _client.from('bookings').stream(primaryKey: const ['id']).eq('customer_profile_id', user.id).listen((_) => scheduleRefresh());
    final savedItemsSub =
        _client.from('saved_items').stream(primaryKey: const ['id']).eq('user_id', user.id).listen((_) => scheduleRefresh());
    final followsSub = _client.from('follows').stream(primaryKey: const ['id']).eq('profile_id', user.id).listen((_) => scheduleRefresh());
    final ledgerSub = _client.from('loyalty_ledger').stream(primaryKey: const ['id']).eq('profile_id', user.id).listen((_) => scheduleRefresh());
    final reviewsSub =
        _client.from('reviews').stream(primaryKey: const ['id']).eq('customer_profile_id', user.id).listen((_) => scheduleRefresh());
    final membershipSub =
        _client.from('customer_membership').stream(primaryKey: const ['id']).eq('user_id', user.id).listen((_) => scheduleRefresh());
    try {
      await for (final _ in refresh.stream) {
        yield await loadMyStats();
      }
    } finally {
      timer?.cancel();
      await bookingsSub.cancel();
      await savedItemsSub.cancel();
      await followsSub.cancel();
      await ledgerSub.cancel();
      await reviewsSub.cancel();
      await membershipSub.cancel();
      await refresh.close();
    }
  }

  Future<ProfileStats> loadMyStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return ProfileStats.empty;
    try {
      final total = await _client.from('bookings').count(CountOption.exact).eq('customer_profile_id', user.id);

      final upcoming = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('customer_profile_id', user.id)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .gte('start_at', DateTime.now().toUtc().toIso8601String());

      final completed = await _client
          .from('bookings')
          .count(CountOption.exact)
          .eq('customer_profile_id', user.id)
          .eq('status', 'completed');

      final favoriteBarbers = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('profile_id', user.id)
          .eq('target_type', 'barber');

      final savedBarbers = await _client
          .from('saved_items')
          .count(CountOption.exact)
          .eq('user_id', user.id)
          .eq('item_type', 'barber');

      final savedShops = await _client
          .from('saved_items')
          .count(CountOption.exact)
          .eq('user_id', user.id)
          .eq('item_type', 'shop');

      var points = 0;
      try {
        final membership = await _client.from('customer_membership').select('points').eq('user_id', user.id).maybeSingle();
        final fromMembership = (membership == null) ? null : (membership['points'] as num?)?.toInt();
        if (fromMembership != null) points = fromMembership;
      } catch (_) {
        points = 0;
      }

      try {
        final customer = await _client.from('customers').select('loyalty_points').eq('id', user.id).maybeSingle();
        final fromCustomers = (customer == null) ? null : (customer['loyalty_points'] as num?)?.toInt();
        if (fromCustomers != null && points == 0) points = fromCustomers;
      } catch (_) {}

      double avgRating = 0;
      try {
        final rows = await _client.from('reviews').select('rating.avg()').eq('customer_profile_id', user.id).eq('status', 'published');
        final list = (rows as List).cast<dynamic>();
        if (list.isNotEmpty && list.first is Map) {
          final m = Map<String, dynamic>.from(list.first as Map);
          final v = m.values.isEmpty ? null : m.values.first;
          final n = (v as num?)?.toDouble();
          if (n != null) avgRating = double.parse(n.toStringAsFixed(1));
        }
      } catch (_) {}

      return ProfileStats(
        totalBookings: total,
        averageRating: avgRating,
        favoriteBarbers: favoriteBarbers,
        upcomingBookingsCount: upcoming,
        completedBookingsCount: completed,
        savedBarbersCount: savedBarbers,
        savedShopsCount: savedShops,
        loyaltyPoints: points,
      );
    } catch (e) {
      throw AppException('Failed to load profile stats', cause: e);
    }
  }
}

final profileStatsRepositoryProvider = Provider<ProfileStatsRepository>((ref) {
  return ProfileStatsRepository(ref.watch(supabaseClientProvider));
});

final myProfileStatsProvider = StreamProvider<ProfileStats>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(profileStatsRepositoryProvider).watchMyStats();
});
