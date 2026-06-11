
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallaq/core/brand/brand_assets_controller.dart';
import 'package:hallaq/core/l10n/app_localizations.dart';
import 'package:hallaq/core/network/network_status.dart';
import 'package:hallaq/core/supabase/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hallaq/core/analytics/analytics_repository.dart';
import 'package:hallaq/core/models/booking.dart';
import 'package:hallaq/core/models/barber.dart';
import 'package:hallaq/core/models/profile.dart';
import 'package:hallaq/core/models/service.dart';
import 'package:hallaq/core/persistence/kv_store.dart';
import 'package:hallaq/core/time/shop_time.dart';
import 'package:hallaq/features/barber/data/barber_availability_repository.dart';
import 'package:hallaq/features/barber/data/barber_repository.dart';
import 'package:hallaq/features/booking/data/booking_repository.dart';
import 'package:hallaq/features/booking/presentation/new_booking_screen.dart';
import 'package:hallaq/features/profile/data/profile_repository.dart';
import 'package:hallaq/features/services/data/services_repository.dart';

class _TestAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<void> track({
    required String eventName,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? meta,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestBookingRepository implements BookingRepository {
  String? lastBarberId;
  String? lastHoldId;
  final List<String> releasedHoldIds = <String>[];

  @override
  Future<({String holdId, DateTime expiresAt})> holdBookingSlot({
    required String serviceId,
    required DateTime startAt,
    required String barberId,
    String? shopId,
    int holdMinutes = 5,
  }) async {
    lastHoldId = 'hold_1';
    return (holdId: lastHoldId!, expiresAt: DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  Future<void> releaseBookingSlot(String holdId) async {
    releasedHoldIds.add(holdId);
  }

  @override
  Future<Booking> createBooking({
    required String serviceId,
    required DateTime startAt,
    required String barberId,
    String? shopId,
    String? holdId,
    String? sourcePostId,
    String? source,
    String? reelId,
    String? offerId,
    double discountAmount = 0,
    String paymentMethod = 'cash',
  }) async {
    lastBarberId = barberId;
    return Booking(
      id: 'bk_1',
      customerProfileId: 'c_1',
      serviceId: serviceId,
      startAt: startAt,
      endAt: startAt.add(const Duration(minutes: 30)),
      status: BookingStatus.confirmed,
      barberId: barberId,
      shopId: shopId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryKvStore implements KvStore {
  final Map<String, String> _m = <String, String>{};

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> write(String key, String value) async {
    _m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _m.remove(key);
  }
}

class _TestAvailabilityRepository implements BarberAvailabilityRepository {
  final List<String> calledBarberIds = <String>[];

  @override
  Future<List<DateTime>> listAvailableStartsForDay({
    required String barberId,
    required DateTime day,
    required int durationMinutes,
    int slotMinutes = 30,
  }) async {
    calledBarberIds.add(barberId);
    if (barberId == 'b1') {
      return <DateTime>[DateTime(day.year, day.month, day.day, 10, 0)];
    }
    return const <DateTime>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestMyProfileController extends MyProfileController {
  @override
  Future<UserProfile?> build() async => null;
}

class _TestNetworkStatusService extends NetworkStatusService {
  @override
  NetworkQuality build() => NetworkQuality.offline;
}

void main() {
  testWidgets('Shop booking flow forces Barber step before Date', (tester) async {
    const shopId = 'shop_1';
    final kv = _MemoryKvStore();
    final supabase = SupabaseClient('https://example.supabase.co', 'anon');
    try {
      supabase.auth.stopAutoRefresh();
    } catch (_) {}
    addTearDown(() {
      try {
        supabase.auth.stopAutoRefresh();
      } catch (_) {}
    });

    final services = <Service>[
      const Service(
        id: 's1',
        shopId: shopId,
        barberId: null,
        nameEn: 'Kids Haircut',
        nameAr: 'Kids Haircut',
        descriptionEn: '',
        descriptionAr: '',
        priceBhd: 5,
        durationMinutes: 30,
        imageUrl: null,
        category: null,
        isPopular: false,
        isActive: true,
        createdAt: null,
      ),
    ];

    final barbers = <Barber>[
      const Barber(
        id: 'b1',
        profileId: 'p1',
        slug: 'b1',
        displayName: 'Barber One',
        ratingAvg: 0,
        ratingCount: 0,
        followersCount: 0,
        reviewsCount: 0,
        isIndependent: false,
        availableNow: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kvStoreProvider.overrideWithValue(kv),
          analyticsRepositoryProvider.overrideWithValue(_TestAnalyticsRepository()),
          supabaseClientProvider.overrideWithValue(supabase),
          networkStatusProvider.overrideWith(_TestNetworkStatusService.new),
          brandAssetUrlProvider.overrideWith((ref, key) => null),
          brandAssetUrlLocalizedProvider.overrideWith((ref, args) => null),
          shopServicesProvider.overrideWith((ref, id) async => services),
          barbersForShopProvider.overrideWith((ref, id) async => barbers),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const NewBookingScreen(shopId: shopId),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Kids Haircut'), findsOneWidget);
    await tester.tap(find.text('Kids Haircut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Any barber'), findsOneWidget);
  });

  testWidgets('Any-barber confirm uses candidate barber id', (tester) async {
    const shopId = 'shop_1';
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final now = ShopTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(today.year, today.month, today.day + 1);
    final supabase = SupabaseClient('https://example.supabase.co', 'anon');
    try {
      supabase.auth.stopAutoRefresh();
    } catch (_) {}
    addTearDown(() {
      try {
        supabase.auth.stopAutoRefresh();
      } catch (_) {}
    });

    final services = <Service>[
      const Service(
        id: 's1',
        shopId: shopId,
        barberId: null,
        nameEn: 'Kids Haircut',
        nameAr: 'Kids Haircut',
        descriptionEn: '',
        descriptionAr: '',
        priceBhd: 5,
        durationMinutes: 30,
        imageUrl: null,
        category: null,
        isPopular: false,
        isActive: true,
        createdAt: null,
      ),
    ];

    final barbers = <Barber>[
      const Barber(
        id: 'b1',
        profileId: 'p1',
        slug: 'b1',
        displayName: 'Barber One',
        ratingAvg: 0,
        ratingCount: 0,
        followersCount: 0,
        reviewsCount: 0,
        isIndependent: false,
        availableNow: false,
      ),
      const Barber(
        id: 'b2',
        profileId: 'p2',
        slug: 'b2',
        displayName: 'Barber Two',
        ratingAvg: 0,
        ratingCount: 0,
        followersCount: 0,
        reviewsCount: 0,
        isIndependent: false,
        availableNow: false,
      ),
    ];

    final bookingRepo = _TestBookingRepository();
    final availRepo = _TestAvailabilityRepository();
    final kv = _MemoryKvStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kvStoreProvider.overrideWithValue(kv),
          analyticsRepositoryProvider.overrideWithValue(_TestAnalyticsRepository()),
          supabaseClientProvider.overrideWithValue(supabase),
          networkStatusProvider.overrideWith(_TestNetworkStatusService.new),
          brandAssetUrlProvider.overrideWith((ref, key) => null),
          brandAssetUrlLocalizedProvider.overrideWith((ref, args) => null),
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          barberAvailabilityRepositoryProvider.overrideWithValue(availRepo),
          myProfileProvider.overrideWith(_TestMyProfileController.new),
          shopServicesProvider.overrideWith((ref, id) async => services),
          barbersForShopProvider.overrideWith((ref, id) async => barbers),
          shopAvailableDaysForMonthProvider.overrideWith((ref, p) async {
            final d = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
            return <DateTime, bool>{d: true};
          }),
          shopAvailableTimesWithBarberProvider.overrideWith((ref, p) async {
            return (
              times: const <TimeOfDay>[TimeOfDay(hour: 10, minute: 0)],
              barberByMinute: <int, String>{(10 * 60): 'b1'},
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const NewBookingScreen(shopId: shopId),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Kids Haircut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Any barber'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final dayKey = ValueKey('booking_day_${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}');
    await tester.ensureVisible(find.byKey(dayKey));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(dayKey), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.byKey(const ValueKey('time')), findsOneWidget);

    final timeChip = find.descendant(of: find.byKey(const ValueKey('time')), matching: find.byType(InkWell)).first;
    await tester.tap(timeChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text(l10n.confirmBooking));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(bookingRepo.lastBarberId, 'b1');
    expect(availRepo.calledBarberIds, everyElement('b1'));
  });
}
