import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/data/my_bookings_repository.dart';
import '../../bookings/models/my_booking_card.dart';

final myRecentBookingsProvider = FutureProvider<List<MyBookingCard>>((ref) async {
  return ref.watch(myBookingsRepositoryProvider).listMyRecentBookings(limit: 1);
});

