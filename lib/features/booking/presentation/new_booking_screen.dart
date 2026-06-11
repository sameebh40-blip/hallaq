import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/last_error.dart';
import '../../../core/geo/maps_launcher.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/models/offer.dart';
import '../../../core/models/service.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/time/shop_time.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/booking_repository.dart';
import '../../barber/data/barber_availability_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../bookings/models/my_booking_card.dart';
import '../../bookings/presentation/my_bookings_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/recent_bookings_provider.dart';
import '../../shop/data/shop_repository.dart';
import '../../offers/data/offers_repository.dart';
import '../../services/data/services_repository.dart';
import '../../../core/analytics/analytics_repository.dart';

class NewBookingScreen extends ConsumerStatefulWidget {
  final String? barberId;
  final String? shopId;
  final String? serviceId;
  final String? sourcePostId;
  final String? reelId;
  final String? offerId;
  final String? source;
  final bool bookAgain;

  const NewBookingScreen({
    super.key,
    this.barberId,
    this.shopId,
    this.serviceId,
    this.sourcePostId,
    this.reelId,
    this.offerId,
    this.source,
    this.bookAgain = false,
  });

  @override
  ConsumerState<NewBookingScreen> createState() => _NewBookingScreenState();
}

final _bookingBarberProvider = FutureProvider.family<Barber, String>((ref, id) async {
  return ref.watch(barberRepositoryProvider).getById(id);
});

final _bookingShopProvider = FutureProvider.family<Barbershop, String>((ref, id) async {
  return ref.watch(shopRepositoryProvider).getById(id);
});

const _anyBarberKey = '__ANY__';
const _bookingDebugPanelEnabled = bool.fromEnvironment('BOOKING_DEBUG_PANEL', defaultValue: false);

({String shopId, String? serviceId, int durationMin, DateTime month}) _shopDaysArgs({
  required String shopId,
  required String? serviceId,
  required int durationMin,
  required DateTime month,
}) {
  return (shopId: shopId, serviceId: serviceId, durationMin: durationMin, month: month);
}

({String shopId, String? serviceId, DateTime day, int durationMin}) _shopTimesArgs({
  required String shopId,
  required String? serviceId,
  required DateTime day,
  required int durationMin,
}) {
  return (shopId: shopId, serviceId: serviceId, day: day, durationMin: durationMin);
}

final shopEligibleBarbersForServiceProvider =
    FutureProvider.autoDispose.family<List<Barber>, ({String shopId, String? serviceId})>((ref, p) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  final barbers = await ref.watch(barbersForShopProvider(p.shopId).future);
  final serviceId = (p.serviceId ?? '').trim();
  if (barbers.isEmpty || serviceId.isEmpty) {
    return barbers;
  }

  final client = ref.watch(supabaseClientProvider);
  final raw = await client.from('services').select('shop_id, barber_id').eq('id', serviceId).maybeSingle();
  if (raw == null) {
    return barbers;
  }

  final service = Map<String, dynamic>.from(raw as Map);
  final directBarberId = (service['barber_id'] as String?)?.trim();
  if ((directBarberId ?? '').isNotEmpty) {
    return barbers.where((b) => b.id == directBarberId).toList(growable: false);
  }

  final serviceShopId = (service['shop_id'] as String?)?.trim();
  if ((serviceShopId ?? '').isNotEmpty && serviceShopId != p.shopId.trim()) {
    return const <Barber>[];
  }

  try {
    final mappedRaw = await client.from('service_barbers').select('barber_id').eq('service_id', serviceId).limit(5000);
    final mappedIds =
        (mappedRaw as List).map((e) => (e as Map)['barber_id'] as String?).whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (mappedIds.isEmpty) return barbers;
    return barbers.where((b) => mappedIds.contains(b.id)).toList(growable: false);
  } catch (e) {
    return barbers;
  }
});

final shopAvailableDaysForMonthProvider =
    FutureProvider.autoDispose.family<Map<DateTime, bool>, ({String shopId, String? serviceId, int durationMin, DateTime month})>((ref, p) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
  final barbers = await ref.watch(shopEligibleBarbersForServiceProvider((shopId: p.shopId, serviceId: p.serviceId)).future);
  if (barbers.isEmpty) return const <DateTime, bool>{};
  final repo = ref.watch(barberAvailabilityRepositoryProvider);
  final month0 = DateTime(p.month.year, p.month.month, 1);
  final list = <Map<DateTime, bool>>[];
  const batchSize = 6;
  for (var i = 0; i < barbers.length; i += batchSize) {
    final batch = barbers.skip(i).take(batchSize).toList(growable: false);
    final out = await Future.wait(
      batch.map(
        (b) => repo.listAvailableDaysForMonth(barberId: b.id, month: month0, durationMinutes: p.durationMin),
      ),
    );
    list.addAll(out);
  }
  final union = <DateTime, bool>{};
  for (final map in list) {
    for (final e in map.entries) {
      if (e.value == true) union[e.key] = true;
      union.putIfAbsent(e.key, () => e.value);
    }
  }
  return union;
});

final shopAvailableTimesWithBarberProvider = FutureProvider.autoDispose.family<
    ({List<TimeOfDay> times, Map<int, String> barberByMinute}), ({String shopId, String? serviceId, DateTime day, int durationMin})>((ref, p) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  final barbers = await ref.watch(shopEligibleBarbersForServiceProvider((shopId: p.shopId, serviceId: p.serviceId)).future);
  if (barbers.isEmpty) return (times: const <TimeOfDay>[], barberByMinute: const <int, String>{});
  final repo = ref.watch(barberAvailabilityRepositoryProvider);
  final startsList = <({String barberId, List<DateTime> starts})>[];
  const batchSize = 6;
  for (var i = 0; i < barbers.length; i += batchSize) {
    final batch = barbers.skip(i).take(batchSize).toList(growable: false);
    final out = await Future.wait(
      batch.map(
        (b) async {
          final starts = await repo.listAvailableStartsForDay(barberId: b.id, day: p.day, durationMinutes: p.durationMin);
          return (barberId: b.id, starts: starts);
        },
      ),
    );
    startsList.addAll(out);
  }

  final byMinute = <int, TimeOfDay>{};
  final barberByMinute = <int, String>{};
  for (final item in startsList) {
    for (final dt in item.starts) {
      final t = TimeOfDay.fromDateTime(dt);
      final key = t.hour * 60 + t.minute;
      byMinute.putIfAbsent(key, () => t);
      barberByMinute.putIfAbsent(key, () => item.barberId);
    }
  }

  final times = byMinute.entries.toList(growable: false)..sort((a, b) => a.key.compareTo(b.key));
  return (times: times.map((e) => e.value).toList(growable: false), barberByMinute: barberByMinute);
});

class _NewBookingScreenState extends ConsumerState<NewBookingScreen> {
  int _step = 0;
  String? _pickedBarberId;
  bool _anyBarber = false;
  String? _anyBarberCandidateId;
  Service? _service;
  DateTime? _date;
  TimeOfDay? _time;
  String _paymentMethod = 'cash';
  String? _slotHoldId;
  String? _slotHoldBarberId;
  DateTime? _slotHoldExpiresAt;
  int _slotHoldSecondsLeft = 0;
  Timer? _slotHoldTicker;
  bool _busy = false;
  bool _busyTimedOut = false;
  Timer? _busyGuard;
  FlutterExceptionHandler? _previousFlutterOnError;
  String? _lastFlutterError;
  bool _draftRestored = false;
  static const _loadingTimeout = Duration(seconds: 10);

  bool get _debugEnabled {
    return kDebugMode && _bookingDebugPanelEnabled;
  }

  double _discountForService(Service service, Offer? offer) {
    if (offer == null) return 0;
    final base = service.price;
    if (base <= 0) return 0;
    final fixed = offer.discountAmount ?? 0;
    final percent = offer.discountPercent ?? 0;
    final raw = fixed > 0
        ? fixed
        : percent > 0
            ? (base * (percent / 100.0))
            : 0.0;
    return raw.clamp(0.0, base).toDouble();
  }

  double _totalForService(Service service, Offer? offer) {
    final d = _discountForService(service, offer);
    return (service.price - d).clamp(0, double.infinity).toDouble();
  }

  void _setBusy(bool value, {bool timeoutUnlock = true}) {
    _busyGuard?.cancel();
    if (!mounted) return;
    setState(() {
      _busy = value;
      if (!value) _busyTimedOut = false;
      if (value) _busyTimedOut = false;
    });
    if (value) {
      _busyGuard = Timer(_loadingTimeout, () {
        if (!mounted) return;
        if (!_busy) return;
        setState(() {
          _busyTimedOut = true;
          if (timeoutUnlock) _busy = false;
        });
      });
    }
  }

  void _stopSlotHoldTicker() {
    _slotHoldTicker?.cancel();
    _slotHoldTicker = null;
  }

  Future<void> _releaseSlotHold({bool remote = true}) async {
    _stopSlotHoldTicker();
    final id = (_slotHoldId ?? '').trim();
    if (remote && id.isNotEmpty) {
      try {
        await ref.read(bookingRepositoryProvider).releaseBookingSlot(id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _slotHoldId = null;
      _slotHoldBarberId = null;
      _slotHoldExpiresAt = null;
      _slotHoldSecondsLeft = 0;
    });
    _scheduleSaveDraft();
  }

  void _startSlotHoldTicker() {
    _stopSlotHoldTicker();
    _slotHoldTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final exp = _slotHoldExpiresAt;
      if (exp == null) return;
      final left = exp.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        unawaited(_releaseSlotHold(remote: true));
        if (!mounted) return;
        final fromShop = widget.shopId != null && widget.barberId == null;
        setState(() {
          _time = null;
          _anyBarberCandidateId = null;
          _step = fromShop ? 3 : 2;
        });
        showErrorSnackBar(context, AppException(AppLocalizations.of(context).bookingReservedTimeExpired));
        return;
      }
      setState(() => _slotHoldSecondsLeft = left);
    });
  }

  Future<void> _reserveSelectedSlot({required String barberId, required Service service, required DateTime date, required TimeOfDay time}) async {
    await _releaseSlotHold(remote: true);
    final startAtShop = ShopTime.dateTime(date.year, date.month, date.day, time.hour, time.minute);
    final startAtUtc = ShopTime.toUtc(startAtShop);
    final shopId = (widget.shopId ?? '').trim().isEmpty ? null : widget.shopId;
    final hold = await ref.read(bookingRepositoryProvider).holdBookingSlot(
          serviceId: service.id,
          startAt: startAtUtc,
          barberId: barberId,
          shopId: shopId,
          holdMinutes: 5,
        );
    if (!mounted) return;
    final holdId = hold.holdId.trim();
    setState(() {
      _slotHoldId = holdId.isEmpty ? null : holdId;
      _slotHoldBarberId = holdId.isEmpty ? null : barberId;
      _slotHoldExpiresAt = holdId.isEmpty ? null : hold.expiresAt;
      _slotHoldSecondsLeft = holdId.isEmpty ? 0 : hold.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    });
    if (holdId.isEmpty) {
      _stopSlotHoldTicker();
    } else {
      _startSlotHoldTicker();
    }
    _scheduleSaveDraft();
  }

  String _draftKey() {
    final barber = (widget.barberId ?? '').trim();
    final shop = (widget.shopId ?? '').trim();
    if (shop.isNotEmpty) return 'booking_draft_shop_$shop';
    if (barber.isNotEmpty) return 'booking_draft_barber_$barber';
    return 'booking_draft';
  }

  void _scheduleSaveDraft() {
    if (!mounted) return;
    unawaited(_saveDraft());
  }

  Future<void> _saveDraft() async {
    final key = _draftKey();
    final s = _service;
    final d = _date;
    final t = _time;
    final json = <String, dynamic>{
      'step': _step,
      'picked_barber_id': _pickedBarberId,
      'any_barber': _anyBarber,
      'any_barber_candidate_id': _anyBarberCandidateId,
      'service_id': s?.id,
      'date': d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'time_min': t == null ? null : (t.hour * 60 + t.minute),
      'payment_method': _paymentMethod,
      'hold_id': _slotHoldId,
      'hold_barber_id': _slotHoldBarberId,
      'hold_expires_at': _slotHoldExpiresAt?.toIso8601String(),
    };
    try {
      await ref.read(kvStoreProvider).write(key, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      await ref.read(kvStoreProvider).delete(_draftKey());
    } catch (_) {}
  }

  void _retryCurrentStep() {
    final fromShop = widget.shopId != null && widget.barberId == null;
    final barberId = _pickedBarberId?.trim();
    final shopId = widget.shopId?.trim();
    final service = _service;
    final date = _date;

    if (fromShop) {
      if (_step == 0) {
        if (shopId != null && shopId.isNotEmpty) ref.invalidate(shopServicesProvider(shopId));
        return;
      }
      if (_step == 1) {
        if (shopId != null && shopId.isNotEmpty) ref.invalidate(barbersForShopProvider(shopId));
        return;
      }
      if (_step == 2) {
        if (service == null) return;
        final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
        if (_anyBarber) {
          if (shopId == null || shopId.isEmpty) return;
          ref.invalidate(shopAvailableDaysForMonthProvider((shopId: shopId, serviceId: service.id, durationMin: service.durationMin, month: month0)));
        } else {
          if (barberId == null || barberId.isEmpty) return;
          ref.invalidate(availableDaysForMonthProvider((barberId: barberId, durationMin: service.durationMin, month: month0)));
        }
        return;
      }
      if (_step == 3) {
        if (service == null || date == null) return;
        if (_anyBarber) {
          if (shopId == null || shopId.isEmpty) return;
          ref.invalidate(shopAvailableTimesWithBarberProvider((shopId: shopId, serviceId: service.id, day: date, durationMin: service.durationMin)));
        } else {
          if (barberId == null || barberId.isEmpty) return;
          ref.invalidate(availableTimesForDayProvider((barberId: barberId, day: date, durationMin: service.durationMin)));
        }
      }
      return;
    }

    if (_step == 0) {
      if (widget.barberId != null) ref.invalidate(barberServicesProvider(widget.barberId!));
      if (widget.shopId != null) ref.invalidate(shopServicesProvider(widget.shopId!));
      return;
    }
    if (_step == 1) {
      if (service == null || widget.barberId == null) return;
      final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
      ref.invalidate(availableDaysForMonthProvider((barberId: widget.barberId!, durationMin: service.durationMin, month: month0)));
      return;
    }
    if (_step == 2) {
      if (service == null || date == null || widget.barberId == null) return;
      ref.invalidate(availableTimesForDayProvider((barberId: widget.barberId!, day: date, durationMin: service.durationMin)));
    }
  }

  DateTime _monthNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  @override
  void initState() {
    super.initState();
    _pickedBarberId = widget.barberId;
    if (_debugEnabled) {
      _previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString();
        if (msg.contains('RenderFlex overflowed')) {
          if (mounted) setState(() => _lastFlutterError = msg);
        }
        _previousFlutterOnError?.call(details);
      };
    }
    ref.read(analyticsRepositoryProvider).track(
          eventName: 'booking_started',
          entityType: widget.barberId != null ? 'barber' : 'shop',
          entityId: widget.barberId ?? widget.shopId,
          meta: {'barber_id': widget.barberId, 'shop_id': widget.shopId, 'service_id': widget.serviceId},
        );
    if (widget.bookAgain && widget.barberId != null) {
      Future.microtask(_prefillBookAgain);
    } else if (widget.serviceId != null) {
      Future.microtask(_prefillService);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_restoreDraft());
      });
    }
  }

  @override
  void dispose() {
    _busyGuard?.cancel();
    _stopSlotHoldTicker();
    final id = (_slotHoldId ?? '').trim();
    if (id.isNotEmpty) {
      ref.read(bookingRepositoryProvider).releaseBookingSlot(id);
    }
    if (_previousFlutterOnError != null) FlutterError.onError = _previousFlutterOnError!;
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    if (_draftRestored) return;
    _draftRestored = true;
    final raw = await ref.read(kvStoreProvider).read(_draftKey());
    if (raw == null || raw.trim().isEmpty) return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }

    final fromShop = widget.shopId != null && widget.barberId == null;
    var languageCode = 'en';
    try {
      languageCode = Localizations.localeOf(context).languageCode;
    } catch (_) {}

    final serviceId = (m['service_id'] as String?)?.trim();
    Service? service;
    if (serviceId != null && serviceId.isNotEmpty) {
      try {
        final services = widget.barberId != null
            ? await ref.read(barberServicesProvider(widget.barberId!).future).timeout(_loadingTimeout)
            : widget.shopId != null
                ? await ref.read(shopServicesProvider(widget.shopId!).future).timeout(_loadingTimeout)
                : <Service>[];
        for (final s in services) {
          if (s.id == serviceId) {
            service = s;
            break;
          }
        }
      } catch (_) {}
    }

    DateTime? date;
    final dateRaw = (m['date'] as String?)?.trim();
    if (dateRaw != null && dateRaw.isNotEmpty) {
      final parts = dateRaw.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final mo = int.tryParse(parts[1]);
        final da = int.tryParse(parts[2]);
        if (y != null && mo != null && da != null) {
          date = DateTime(y, mo, da);
        }
      }
    }

    TimeOfDay? time;
    final timeMin = m['time_min'];
    if (timeMin is int) {
      time = TimeOfDay(hour: timeMin ~/ 60, minute: timeMin % 60);
    }

    final pickedBarberId = (m['picked_barber_id'] as String?)?.trim();
    final anyBarber = (m['any_barber'] as bool?) ?? false;
    final anyCandidate = (m['any_barber_candidate_id'] as String?)?.trim();
    final paymentMethod = (m['payment_method'] as String?)?.trim();

    final holdId = (m['hold_id'] as String?)?.trim();
    final holdBarberId = (m['hold_barber_id'] as String?)?.trim();
    final holdExpiresAtRaw = (m['hold_expires_at'] as String?)?.trim();
    DateTime? holdExpiresAt;
    if (holdExpiresAtRaw != null && holdExpiresAtRaw.isNotEmpty) {
      try {
        holdExpiresAt = DateTime.parse(holdExpiresAtRaw);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _service = service;
      _date = date;
      _time = time;
      _paymentMethod = (paymentMethod == null || paymentMethod.isEmpty) ? 'cash' : paymentMethod;
      _anyBarber = fromShop ? anyBarber : false;
      _pickedBarberId = fromShop ? (anyBarber ? null : pickedBarberId) : widget.barberId;
      _anyBarberCandidateId = fromShop ? anyCandidate : null;

      final barberChosen = _anyBarber || ((_pickedBarberId ?? '').trim().isNotEmpty);
      final serviceStepIndex = 0;
      final dateStepIndex = fromShop ? 2 : 1;
      final timeStepIndex = fromShop ? 3 : 2;
      final reviewStepIndex = fromShop ? 4 : 3;
      final inferredStep = (_service == null)
          ? serviceStepIndex
          : (fromShop && !barberChosen)
              ? 1
              : (_date == null)
                  ? dateStepIndex
                  : (_time == null)
                      ? timeStepIndex
                      : reviewStepIndex;
      _step = inferredStep;

      final exp = holdExpiresAt;
      final now = DateTime.now();
      if (holdId != null && holdId.isNotEmpty && exp != null && exp.isAfter(now)) {
        _slotHoldId = holdId;
        _slotHoldBarberId = holdBarberId;
        _slotHoldExpiresAt = exp;
        _slotHoldSecondsLeft = exp.difference(now).inSeconds.clamp(0, 3600);
      } else {
        _slotHoldId = null;
        _slotHoldBarberId = null;
        _slotHoldExpiresAt = null;
        _slotHoldSecondsLeft = 0;
      }
    });

    if ((_slotHoldId ?? '').trim().isNotEmpty && (_slotHoldExpiresAt != null)) {
      _startSlotHoldTicker();
    }

    if (service != null) {
      ref.read(analyticsRepositoryProvider).track(
            eventName: 'booking_draft_restored',
            entityType: widget.barberId != null ? 'barber' : 'shop',
            entityId: widget.barberId ?? widget.shopId,
            meta: {'service': service.displayName(languageCode)},
          );
    }
  }

  Future<void> _pickBarber({bool advanceAfterPick = false}) async {
    final shopId = widget.shopId;
    if (shopId == null || shopId.trim().isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickBarberSheet(shopId: shopId, selectedBarberId: _pickedBarberId, selectedAny: _anyBarber),
    );
    final picked = selected?.trim();
    if (picked == null || picked.isEmpty) return;
    if (!mounted) return;
    ref.read(analyticsRepositoryProvider).track(
          eventName: 'booking_barber_selected',
          entityType: 'shop',
          entityId: shopId,
          meta: {'barber_id': picked == _anyBarberKey ? null : picked, 'any': picked == _anyBarberKey},
        );
    if ((_slotHoldId ?? '').trim().isNotEmpty) {
      unawaited(_releaseSlotHold(remote: true));
    }
    setState(() {
      if (picked == _anyBarberKey) {
        _anyBarber = true;
        _pickedBarberId = null;
      } else {
        _anyBarber = false;
        _pickedBarberId = picked;
      }
      _date = null;
      _time = null;
      _anyBarberCandidateId = null;
      if (advanceAfterPick && _step == 0) _step = 1;
    });
    final s = _service;
    if (s != null) {
      final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
      if (picked == _anyBarberKey) {
        unawaited(
          ref.read(
            shopAvailableDaysForMonthProvider((
              shopId: shopId.trim(),
              serviceId: s.id,
              durationMin: s.durationMin,
              month: month0,
            )).future,
          ),
        );
      } else {
        unawaited(
          ref.read(
            availableDaysForMonthProvider((
              barberId: picked,
              durationMin: s.durationMin,
              month: month0,
            )).future,
          ),
        );
      }
    }
    _scheduleSaveDraft();
  }

  Future<void> _prefillService() async {
    final serviceId = widget.serviceId;
    if (serviceId == null || serviceId.isEmpty) return;

    _setBusy(true);
    try {
      final services = widget.barberId != null
          ? await ref.read(barberServicesProvider(widget.barberId!).future).timeout(_loadingTimeout)
          : widget.shopId != null
              ? await ref.read(shopServicesProvider(widget.shopId!).future).timeout(_loadingTimeout)
              : <Service>[];

      Service? selected;
      for (final s in services) {
        if (s.id == serviceId) {
          selected = s;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _service = selected;
        _step = selected != null ? 1 : 0;
      });
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Loading is taking too long. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              final barberId = widget.barberId;
              final shopId = widget.shopId;
              if (barberId != null) ref.invalidate(barberServicesProvider(barberId));
              if (shopId != null) ref.invalidate(shopServicesProvider(shopId));
              _prefillService();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  List<TimeOfDay> _timeSlots() {
    const start = TimeOfDay(hour: 10, minute: 0);
    const end = TimeOfDay(hour: 22, minute: 0);
    final slots = <TimeOfDay>[];
    var h = start.hour;
    var m = start.minute;
    while (h < end.hour || (h == end.hour && m <= end.minute)) {
      slots.add(TimeOfDay(hour: h, minute: m));
      m += 30;
      if (m >= 60) {
        m -= 60;
        h += 1;
      }
    }
    return slots;
  }

  List<DateTime> _days() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return List.generate(14, (i) => start.add(Duration(days: i)));
  }

  Future<void> _prefillBookAgain() async {
    final barberId = widget.barberId;
    if (barberId == null) return;

    _setBusy(true);
    try {
      final services = await ref.read(barberServicesProvider(barberId).future).timeout(_loadingTimeout);
      final last = await ref.read(bookingRepositoryProvider).getMyLastBookingForBarber(barberId).timeout(_loadingTimeout);
      final nextAvailable = await ref.read(barberAvailabilityRepositoryProvider).getNextAvailableStart(barberId: barberId).timeout(_loadingTimeout);

      Service? preferredService;
      if (services.isNotEmpty) {
        preferredService = services.first;
      }
      if (last != null) {
        for (final s in services) {
          if (s.id == last.serviceId) {
            preferredService = s;
            break;
          }
        }
      }

      DateTime? date;
      TimeOfDay? time;
      if (nextAvailable != null) {
        date = DateTime(nextAvailable.year, nextAvailable.month, nextAvailable.day);
        time = TimeOfDay.fromDateTime(nextAvailable);
      } else {
        final d = _days().skip(1).first;
        date = DateTime(d.year, d.month, d.day);
        time = _timeSlots().first;
      }

      if (!mounted) return;
      setState(() {
        _service = preferredService;
        _date = date;
        _time = time;
        _step = (_service != null && _date != null && _time != null) ? 3 : 0;
      });
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Loading is taking too long. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              ref.invalidate(barberServicesProvider(barberId));
              _prefillBookAgain();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _confirm() async {
    final service = _service;
    final date = _date;
    final time = _time;
    if (service == null || date == null || time == null) return;

    final fromShop = widget.shopId != null && widget.barberId == null;
    String? barberId = _pickedBarberId;
    Barber? resolvedBarber;
    if (fromShop && _anyBarber) {
      final shopId = widget.shopId!;
      final barbers = await ref.read(shopEligibleBarbersForServiceProvider((shopId: shopId, serviceId: service.id)).future).timeout(_loadingTimeout);
      final repo = ref.read(barberAvailabilityRepositoryProvider);
      String? found;
      final preferred = _anyBarberCandidateId?.trim();
      if (preferred != null && preferred.isNotEmpty) {
        final starts =
            await repo.listAvailableStartsForDay(barberId: preferred, day: date, durationMinutes: service.durationMin).timeout(_loadingTimeout);
        final ok = starts.any((dt) => dt.year == date.year && dt.month == date.month && dt.day == date.day && dt.hour == time.hour && dt.minute == time.minute);
        if (ok) {
          found = preferred;
          for (final b in barbers) {
            if (b.id == preferred) {
              resolvedBarber = b;
              break;
            }
          }
        }
      }
      for (final b in barbers) {
        if (found != null) break;
        if (preferred != null && preferred.isNotEmpty && b.id == preferred) continue;
        final starts = await repo.listAvailableStartsForDay(barberId: b.id, day: date, durationMinutes: service.durationMin).timeout(_loadingTimeout);
        final ok = starts.any((dt) {
          return dt.year == date.year &&
              dt.month == date.month &&
              dt.day == date.day &&
              dt.hour == time.hour &&
              dt.minute == time.minute;
        });
        if (ok) {
          found = b.id;
          resolvedBarber = b;
          break;
        }
      }
      barberId = found;
      if (barberId == null) {
        throw AppException(AppLocalizations.of(context).bookingNoBarberAvailableTime);
      }
    }

    if (barberId == null || barberId.trim().isEmpty) return;

    final startAtShop = ShopTime.dateTime(date.year, date.month, date.day, time.hour, time.minute);
    final startAtUtc = ShopTime.toUtc(startAtShop);

    _setBusy(true, timeoutUnlock: false);
    try {
      HallaqHaptics.tap();
      ref.read(analyticsRepositoryProvider).track(
            eventName: 'booking_confirm_attempt',
            entityType: 'barber',
            entityId: barberId,
            meta: {'service_id': service.id},
          );
      final holdId0 = (_slotHoldId ?? '').trim();
      final holdBarber0 = (_slotHoldBarberId ?? '').trim();
      if (holdId0.isEmpty || holdBarber0 != barberId.trim()) {
        await _reserveSelectedSlot(barberId: barberId.trim(), service: service, date: date, time: time).timeout(_loadingTimeout);
      }
      final holdId = (_slotHoldId ?? '').trim();
      if (holdId.isEmpty) {
        final starts = await ref
            .read(barberAvailabilityRepositoryProvider)
            .listAvailableStartsForDay(barberId: barberId, day: date, durationMinutes: service.durationMin)
            .timeout(_loadingTimeout);
        final stillAvailable = starts.any((dt) {
          return dt.year == startAtShop.year &&
              dt.month == startAtShop.month &&
              dt.day == startAtShop.day &&
              dt.hour == startAtShop.hour &&
              dt.minute == startAtShop.minute;
        });
        if (!stillAvailable) {
          throw AppException(AppLocalizations.of(context).bookingTimeNoLongerAvailable);
        }
      }
      var shopId = widget.shopId;
      if (shopId == null || shopId.trim().isEmpty) {
        final barber = await ref.read(_bookingBarberProvider(barberId).future).timeout(_loadingTimeout);
        resolvedBarber ??= barber;
        shopId = barber.shopId;
      }
      Offer? offer;
      final offerId0 = (widget.offerId ?? '').trim();
      if (offerId0.isNotEmpty) {
        try {
          offer = await ref.read(offerByIdProvider(offerId0).future).timeout(_loadingTimeout);
        } catch (_) {}
      }
      final discountAmount = _discountForService(service, offer);
      await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            serviceId: service.id,
            startAt: startAtUtc,
            barberId: barberId,
            shopId: shopId,
            holdId: holdId.isEmpty ? null : holdId,
            sourcePostId: (widget.sourcePostId ?? '').trim().isEmpty ? null : widget.sourcePostId,
            reelId: (widget.reelId ?? '').trim().isEmpty ? null : widget.reelId,
            offerId: offerId0.isEmpty ? null : offerId0,
            source: (widget.source ?? '').trim().isEmpty ? null : widget.source,
            discountAmount: discountAmount,
            paymentMethod: _paymentMethod,
          )
          .timeout(_loadingTimeout);
      unawaited(_clearDraft());
      await _releaseSlotHold(remote: false);
      ref.invalidate(myUpcomingBookingsProvider);
      ref.invalidate(myBookingsControllerProvider(BookingsTab.upcoming));
      ref.invalidate(myRecentBookingsProvider);
      ref.read(analyticsRepositoryProvider).track(
            eventName: 'booking_created',
            entityType: 'barber',
            entityId: barberId,
            meta: {'service_id': service.id},
          );
      ref.read(analyticsRepositoryProvider).track(
            eventName: 'booking_completed',
            entityType: 'barber',
            entityId: barberId,
            meta: {'service_id': service.id},
          );
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _BookingSuccessSheet(barberId: barberId, barber: resolvedBarber),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
      if (fromShop && _anyBarber && widget.shopId != null) {
        final month0 = DateTime(date.year, date.month, 1);
        ref.invalidate(shopAvailableDaysForMonthProvider((shopId: widget.shopId!, serviceId: service.id, durationMin: service.durationMin, month: month0)));
        ref.invalidate(shopAvailableTimesWithBarberProvider((shopId: widget.shopId!, serviceId: service.id, day: date, durationMin: service.durationMin)));
      }
      if (barberId.trim().isNotEmpty) {
        final month0 = DateTime(date.year, date.month, 1);
        ref.invalidate(availableDaysForMonthProvider((barberId: barberId, durationMin: service.durationMin, month: month0)));
        ref.invalidate(availableTimesForDayProvider((barberId: barberId, day: date, durationMin: service.durationMin)));
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  void _next() {
    final fromShop = widget.shopId != null && widget.barberId == null;
    final barberChosen = _anyBarber || (_pickedBarberId != null && _pickedBarberId!.trim().isNotEmpty);

    if (fromShop) {
      if (_step == 0 && _service == null) return;
      if (_step == 1 && !barberChosen) {
        _pickBarber();
        return;
      }
      if (_step == 2 && _date == null) return;
      if (_step == 3 && _time == null) return;
      if (_step < 5) setState(() => _step += 1);
      _scheduleSaveDraft();
      return;
    }

    if (_step == 0 && _service == null) return;
    if (_step == 1 && _date == null) return;
    if (_step == 2 && _time == null) return;
    if (_step < 4) setState(() => _step += 1);
    _scheduleSaveDraft();
  }

  void _back() {
    if (_step == 0) return;
    if ((_slotHoldId ?? '').trim().isNotEmpty) {
      unawaited(_releaseSlotHold(remote: true));
    }
    setState(() => _step -= 1);
    _scheduleSaveDraft();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fromShop = widget.shopId != null && widget.barberId == null;
    final barberId = _pickedBarberId;
    final barberChosen = _anyBarber || (barberId != null && barberId.trim().isNotEmpty);
    final selectedDate = _date;
    final selectedService = _service;
    final languageCode = Localizations.localeOf(context).languageCode;
    final lastError = ref.watch(lastErrorProvider);
    final debugEnabled = _debugEnabled;
    final offerId0 = (widget.offerId ?? '').trim();
    final offerValue = offerId0.isEmpty ? const AsyncValue<Offer?>.data(null) : ref.watch(offerByIdProvider(offerId0));
    final offer = offerValue.valueOrNull;
    final discountAmount = selectedService == null ? 0.0 : _discountForService(selectedService, offer);
    final totalBhd = selectedService == null ? null : _totalForService(selectedService, offer);

    final serviceStepIndex = 0;
    final dateStepIndex = fromShop ? 2 : 1;
    final timeStepIndex = fromShop ? 3 : 2;
    final reviewStepIndex = fromShop ? 4 : 3;
    final paymentStepIndex = fromShop ? 5 : 4;
    final totalSteps = fromShop ? 6 : 5;

    final effectiveBarberForServices = (widget.barberId ?? (!_anyBarber ? barberId : null))?.trim();
    final shouldWatchServices = _service == null || _step == serviceStepIndex;
    final servicesValue = !shouldWatchServices
        ? AsyncValue<List<Service>>.data(_service == null ? const <Service>[] : <Service>[_service!])
        : (effectiveBarberForServices != null && effectiveBarberForServices.isNotEmpty)
            ? ref.watch(barberServicesProvider(effectiveBarberForServices))
            : widget.shopId != null
                ? ref.watch(shopServicesProvider(widget.shopId!))
                : const AsyncValue<List<Service>>.data([]);

    final availableTimesValue = (barberId != null && barberId.trim().isNotEmpty && selectedDate != null && selectedService != null)
        ? ref.watch(
            availableTimesForDayProvider((
              barberId: barberId,
              day: selectedDate,
              durationMin: selectedService.durationMin,
            )),
          )
        : const AsyncValue<List<TimeOfDay>>.data([]);

    final title = fromShop
        ? switch (_step) {
            0 => l10n.selectService,
            1 => l10n.selectBarber,
            2 => l10n.selectDate,
            3 => l10n.selectTime,
            4 => l10n.confirmBooking,
            _ => l10n.paymentMethods,
          }
        : switch (_step) {
            0 => l10n.selectService,
            1 => l10n.selectDate,
            2 => l10n.selectTime,
            3 => l10n.confirmBooking,
            _ => l10n.paymentMethods,
          };

    final primaryLabel = _step == paymentStepIndex ? l10n.confirmBooking : l10n.next;
    final locking = _busy && _step == paymentStepIndex;
    final canContinue = !locking &&
        switch (_step) {
          0 => _service != null,
          1 => fromShop ? barberChosen : _date != null,
          2 => fromShop ? _date != null : _time != null,
          3 => fromShop ? _time != null : true,
          _ => true,
        };

    return WillPopScope(
      onWillPop: () async {
        if (locking) return false;
        if (_step > 0) {
          _back();
          return false;
        }
        return true;
      },
      child: LuxuryScaffold(
        header: LuxuryTopBar(
          leading: LuxuryIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: locking
                ? null
                : () {
                    if (_step > 0) {
                      _back();
                      return;
                    }
                    Navigator.of(context).maybePop();
                  },
          ),
          title: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        bottom: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppTheme.onyx3.withValues(alpha: 0.94),
          border: Border.all(
            color: _step == paymentStepIndex ? AppTheme.gold.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: [
            ...AppTheme.softShadow(opacity: 0.20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_step == paymentStepIndex && _service != null && _time != null && _date != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.bookAgain ? l10n.bookAgain : l10n.confirmBooking,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _service!.displayName(languageCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.gold.withValues(alpha: 0.12),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (discountAmount > 0.0005) ...[
                            Text(
                              '${_service!.price.toStringAsFixed(3)} BHD',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            '${(totalBhd ?? _service!.price).toStringAsFixed(3)} BHD',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _time!.format(context),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: HallaqButton(
                      label: MaterialLocalizations.of(context).backButtonTooltip,
                      variant: HallaqButtonVariant.ghost,
                      onPressed: locking ? null : _back,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: _step > 0 ? 2 : 1,
                  child: HallaqButton(
                    label: primaryLabel,
                    icon: _step == paymentStepIndex ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                    onPressed: canContinue ? (_step == paymentStepIndex ? _confirm : _next) : null,
                    isLoading: locking,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            if (_busyTimedOut) ...[
              HallaqCard(
                glass: true,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        locking
                            ? 'This is taking longer than expected. Please wait…'
                            : 'Loading is taking too long. You can continue, or retry.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!locking)
                      HallaqButton(
                        label: 'Retry',
                        expanded: false,
                        onPressed: _retryCurrentStep,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (debugEnabled) ...[
              _BookingDebugPanel(
                step: _step,
                busy: _busy,
                busyTimedOut: _busyTimedOut,
                service: _service,
                date: _date,
                time: _time,
                servicesValue: servicesValue,
                availableTimesValue: availableTimesValue,
                lastError: lastError,
                lastFlutterError: _lastFlutterError,
              ),
              const SizedBox(height: 12),
            ],
            if (fromShop && _step != 1) ...[
              HallaqCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.selectBarber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            _anyBarber
                                ? l10n.bookingAnyBarberSelectedHint
                                : (barberId == null || barberId.trim().isEmpty)
                                    ? l10n.bookingChooseBarberToSeeDates
                                    : l10n.bookingBarberSelectedHint,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    HallaqButton(
                      label: l10n.bookingChoose,
                      expanded: false,
                      onPressed: locking ? null : _pickBarber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (fromShop && _anyBarber && _step != 1) ...[
              HallaqCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold.withValues(alpha: 0.16),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.30)),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.bookingAnyBarber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            l10n.bookingAnyBarberSubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (barberId != null && barberId.trim().isNotEmpty && _step != 1) ...[
              AsyncValueWidget<Barber>(
                value: ref.watch(_bookingBarberProvider(barberId)),
                data: (barber) {
                  return HallaqCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: LuxuryNetworkImage(
                              imageUrl: barber.avatarUrl,
                              fallbackUrl: HallaqImages.barberAvatar(variant: '01'),
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                barber.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.bookAgain ? l10n.bookAgain : l10n.confirmBooking,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (barber.availableNow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppTheme.success.withValues(alpha: 0.16),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.26)),
                            ),
                            child: Text(
                              l10n.availableNow,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
            _StepIndicator(current: _step, total: totalSteps),
            const SizedBox(height: 12),
            _SelectionSummary(
              step: _step,
              serviceStepIndex: serviceStepIndex,
              dateStepIndex: dateStepIndex,
              timeStepIndex: timeStepIndex,
              service: _service,
              date: _date,
              time: _time,
              languageCode: languageCode,
              onJump: locking
                  ? null
                  : (step) {
                      if (step == _step) return;
                      if (step < _step && (_slotHoldId ?? '').trim().isNotEmpty) {
                        unawaited(_releaseSlotHold(remote: true));
                      }
                      setState(() => _step = step);
                      _scheduleSaveDraft();
                    },
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: fromShop
                    ? switch (_step) {
                        0 => _ServiceStep(
                            key: const ValueKey('service'),
                            value: servicesValue,
                            selected: _service,
                            busy: locking,
                            languageCode: languageCode,
                            onRetry: _retryCurrentStep,
                            onSelected: (s) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_service_selected',
                                    entityType: 'shop',
                                    entityId: widget.shopId,
                                    meta: {'service_id': s.id},
                                  );
                              if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                unawaited(_releaseSlotHold(remote: true));
                              }
                              setState(() {
                                _service = s;
                                _date = null;
                                _time = null;
                                _anyBarberCandidateId = null;
                                _step = 1;
                              });
                              final b = widget.barberId;
                              if (b != null && b.trim().isNotEmpty) {
                                final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
                                unawaited(
                                  ref.read(
                                    availableDaysForMonthProvider((
                                      barberId: b.trim(),
                                      durationMin: s.durationMin,
                                      month: month0,
                                    )).future,
                                  ),
                                );
                              }
                              _scheduleSaveDraft();
                            },
                          ),
                        1 => AsyncValueWidget<List<Barber>>(
                            key: const ValueKey('barber'),
                            value: ref.watch(barbersForShopProvider(widget.shopId!)),
                            onRetry: () => ref.invalidate(barbersForShopProvider(widget.shopId!)),
                            data: (items) {
                              if (items.isEmpty) {
                                return Center(
                                  child: HallaqEmptyState(
                                    title: l10n.selectBarber,
                                    description: l10n.bookingNoBarbersAvailable,
                                    showMascot: true,
                                    compact: true,
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 120),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    final selected = _anyBarber;
                                    return HallaqCard(
                                      glass: true,
                                      onTap: () {
                                        ref.read(analyticsRepositoryProvider).track(
                                              eventName: 'booking_barber_selected',
                                              entityType: 'shop',
                                              entityId: widget.shopId,
                                              meta: {'any': true},
                                            );
                                        if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                          unawaited(_releaseSlotHold(remote: true));
                                        }
                                        setState(() {
                                          _anyBarber = true;
                                          _pickedBarberId = null;
                                          _date = null;
                                          _time = null;
                                          _anyBarberCandidateId = null;
                                          _step = 2;
                                        });
                                        _scheduleSaveDraft();
                                        final s = selectedService;
                                        if (s != null) {
                                          final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
                                          unawaited(
                                            ref.read(
                                              shopAvailableDaysForMonthProvider((
                                                shopId: widget.shopId!,
                                                serviceId: s.id,
                                                durationMin: s.durationMin,
                                                month: month0,
                                              )).future,
                                            ),
                                          );
                                        }
                                      },
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.gold.withValues(alpha: 0.16),
                                              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.30)),
                                            ),
                                            child: const Icon(Icons.groups_rounded, size: 20, color: Colors.white),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.bookingAnyBarber,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.bookingAnyBarberSubtitle2,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (selected)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                color: AppTheme.gold.withValues(alpha: 0.18),
                                                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                                              ),
                                              child: Text(l10n.bookingSelected, style: const TextStyle(fontWeight: FontWeight.w900)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }

                                  final b = items[index - 1];
                                  final selected = !_anyBarber && _pickedBarberId != null && _pickedBarberId == b.id;
                                  return HallaqCard(
                                    glass: true,
                                    onTap: () {
                                      ref.read(analyticsRepositoryProvider).track(
                                            eventName: 'booking_barber_selected',
                                            entityType: 'shop',
                                            entityId: widget.shopId,
                                            meta: {'barber_id': b.id, 'any': false},
                                          );
                                      if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                        unawaited(_releaseSlotHold(remote: true));
                                      }
                                      setState(() {
                                        _anyBarber = false;
                                        _pickedBarberId = b.id;
                                        _date = null;
                                        _time = null;
                                        _anyBarberCandidateId = null;
                                        _step = 2;
                                      });
                                      _scheduleSaveDraft();
                                      final s = selectedService;
                                      if (s != null) {
                                        final month0 = DateTime(_monthNow().year, _monthNow().month, 1);
                                        unawaited(
                                          ref.read(
                                            availableDaysForMonthProvider((
                                              barberId: b.id,
                                              durationMin: s.durationMin,
                                              month: month0,
                                            )).future,
                                          ),
                                        );
                                      }
                                    },
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: LuxuryNetworkImage(
                                              imageUrl: b.avatarUrl,
                                              fallbackUrl: HallaqImages.barberAvatar(variant: '01'),
                                              borderRadius: BorderRadius.zero,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            b.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        if (selected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              color: AppTheme.gold.withValues(alpha: 0.18),
                                              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                                            ),
                                            child: Text(l10n.bookingSelected, style: const TextStyle(fontWeight: FontWeight.w900)),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemCount: items.length + 1,
                              );
                            },
                          ),
                        2 => _DateStep(
                            key: const ValueKey('date'),
                            selected: _date,
                            busy: locking,
                            barberId: barberId,
                            shopId: widget.shopId,
                            anyBarber: _anyBarber,
                            serviceId: selectedService?.id,
                            durationMin: selectedService?.durationMin,
                            onSelected: (d) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_date_selected',
                                    entityType: 'shop',
                                    entityId: widget.shopId,
                                    meta: {'date': d.toIso8601String()},
                                  );
                              if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                unawaited(_releaseSlotHold(remote: true));
                              }
                              setState(() {
                                _date = d;
                                _time = null;
                                _anyBarberCandidateId = null;
                                _step = 3;
                              });
                              final s = selectedService;
                              final pickedId = barberId?.trim();
                              if (s != null) {
                                if (_anyBarber) {
                                  unawaited(
                                    ref.read(
                                      shopAvailableTimesWithBarberProvider((
                                        shopId: widget.shopId!,
                                        serviceId: s.id,
                                        day: d,
                                        durationMin: s.durationMin,
                                      )).future,
                                    ),
                                  );
                                } else if (pickedId != null && pickedId.isNotEmpty) {
                                  unawaited(
                                    ref.read(
                                      availableTimesForDayProvider((
                                        barberId: pickedId,
                                        day: d,
                                        durationMin: s.durationMin,
                                      )).future,
                                    ),
                                  );
                                }
                              }
                              _scheduleSaveDraft();
                            },
                          ),
                        3 => _TimeStep(
                            key: const ValueKey('time'),
                            value: (_anyBarber && selectedDate != null && selectedService != null)
                                ? ref.watch(
                                    shopAvailableTimesWithBarberProvider((
                                      shopId: widget.shopId!,
                                      serviceId: selectedService.id,
                                      day: selectedDate,
                                      durationMin: selectedService.durationMin,
                                    )),
                                  ).whenData((v) => v.times)
                                : (barberId != null && barberId.trim().isNotEmpty)
                                    ? availableTimesValue
                                    : const AsyncValue<List<TimeOfDay>>.data([]),
                            selected: _time,
                            busy: locking,
                            onRetry: (_anyBarber && selectedDate != null && selectedService != null)
                                ? () => ref.invalidate(
                                      shopAvailableTimesWithBarberProvider((
                                        shopId: widget.shopId!,
                                        serviceId: selectedService.id,
                                        day: selectedDate,
                                        durationMin: selectedService.durationMin,
                                      )),
                                    )
                                : (barberId != null && barberId.trim().isNotEmpty && selectedDate != null && selectedService != null)
                                    ? () => ref.invalidate(
                                          availableTimesForDayProvider((
                                            barberId: barberId,
                                            day: selectedDate,
                                            durationMin: selectedService.durationMin,
                                          )),
                                        )
                                    : null,
                            onSelected: (t) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_time_selected',
                                    entityType: 'shop',
                                    entityId: widget.shopId,
                                    meta: {'time': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'},
                                  );
                              final service = selectedService;
                              final date = selectedDate;
                              if (service == null || date == null) return;
                              final candidate = (_anyBarber && selectedDate != null && selectedService != null)
                                  ? ref
                                      .read(
                                        shopAvailableTimesWithBarberProvider((
                                          shopId: widget.shopId!,
                                          serviceId: selectedService.id,
                                          day: selectedDate,
                                          durationMin: selectedService.durationMin,
                                        )),
                                      )
                                      .valueOrNull
                                      ?.barberByMinute[t.hour * 60 + t.minute]
                                  : null;
                              final holdBarberId = _anyBarber ? (candidate ?? '') : (barberId ?? '');
                              if (holdBarberId.trim().isEmpty) return;
                              _setBusy(true);
                              unawaited(() async {
                                try {
                                  await _reserveSelectedSlot(barberId: holdBarberId.trim(), service: service, date: date, time: t).timeout(_loadingTimeout);
                                  if (!mounted) return;
                                  setState(() {
                                    _time = t;
                                    _anyBarberCandidateId = candidate;
                                    _step = reviewStepIndex;
                                  });
                                  _scheduleSaveDraft();
                                } catch (e) {
                                  if (!mounted) return;
                                  showErrorSnackBar(context, e);
                                } finally {
                                  if (mounted) _setBusy(false);
                                }
                              }());
                            },
                          ),
                        4 => _ConfirmSummary(
                            key: const ValueKey('review'),
                            service: _service,
                            date: _date,
                            time: _time,
                            languageCode: languageCode,
                            barberId: _pickedBarberId ?? widget.barberId,
                            anyBarber: _anyBarber,
                            offer: offer,
                            discountAmount: discountAmount,
                            totalBhd: totalBhd,
                          ),
                        _ => _PaymentMethodStep(
                            key: const ValueKey('payment'),
                            selectedMethod: _paymentMethod,
                            totalBhd: totalBhd,
                            onSelected: locking
                                ? null
                                : (value) {
                                    setState(() => _paymentMethod = value);
                                    _scheduleSaveDraft();
                                  },
                          ),
                      }
                    : switch (_step) {
                        0 => _ServiceStep(
                            key: const ValueKey('service'),
                            value: servicesValue,
                            selected: _service,
                            busy: locking,
                            languageCode: languageCode,
                            onRetry: _retryCurrentStep,
                            onSelected: (s) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_service_selected',
                                    entityType: 'barber',
                                    entityId: widget.barberId,
                                    meta: {'service_id': s.id},
                                  );
                              if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                unawaited(_releaseSlotHold(remote: true));
                              }
                              setState(() {
                                _service = s;
                                _date = null;
                                _time = null;
                                _anyBarberCandidateId = null;
                                _step = 1;
                              });
                              _scheduleSaveDraft();
                            },
                          ),
                        1 => _DateStep(
                            key: const ValueKey('date'),
                            selected: _date,
                            busy: locking,
                            barberId: widget.barberId,
                            shopId: widget.shopId,
                            anyBarber: false,
                            serviceId: selectedService?.id,
                            durationMin: selectedService?.durationMin,
                            onSelected: (d) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_date_selected',
                                    entityType: 'barber',
                                    entityId: widget.barberId,
                                    meta: {'date': d.toIso8601String()},
                                  );
                              if ((_slotHoldId ?? '').trim().isNotEmpty) {
                                unawaited(_releaseSlotHold(remote: true));
                              }
                              setState(() {
                                _date = d;
                                _time = null;
                                _anyBarberCandidateId = null;
                                _step = 2;
                              });
                              final s = selectedService;
                              final b = widget.barberId;
                              if (s != null && b != null && b.trim().isNotEmpty) {
                                unawaited(
                                  ref.read(
                                    availableTimesForDayProvider((
                                      barberId: b.trim(),
                                      day: d,
                                      durationMin: s.durationMin,
                                    )).future,
                                  ),
                                );
                              }
                              _scheduleSaveDraft();
                            },
                          ),
                        2 => _TimeStep(
                            key: const ValueKey('time'),
                            value: availableTimesValue,
                            selected: _time,
                            busy: locking,
                            onRetry: (widget.barberId != null && selectedDate != null && selectedService != null)
                                ? () => ref.invalidate(
                                      availableTimesForDayProvider((
                                        barberId: widget.barberId!,
                                        day: selectedDate,
                                        durationMin: selectedService.durationMin,
                                      )),
                                    )
                                : null,
                            onSelected: (t) {
                              ref.read(analyticsRepositoryProvider).track(
                                    eventName: 'booking_time_selected',
                                    entityType: 'barber',
                                    entityId: widget.barberId,
                                    meta: {'time': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'},
                                  );
                              final service = selectedService;
                              final date = selectedDate;
                              final holdBarberId = (widget.barberId ?? '').trim();
                              if (service == null || date == null || holdBarberId.isEmpty) return;
                              _setBusy(true);
                              unawaited(() async {
                                try {
                                  await _reserveSelectedSlot(barberId: holdBarberId, service: service, date: date, time: t).timeout(_loadingTimeout);
                                  if (!mounted) return;
                                  setState(() {
                                    _time = t;
                                    _step = reviewStepIndex;
                                  });
                                  _scheduleSaveDraft();
                                } catch (e) {
                                  if (!mounted) return;
                                  showErrorSnackBar(context, e);
                                } finally {
                                  if (mounted) _setBusy(false);
                                }
                              }());
                            },
                          ),
                        3 => _ConfirmSummary(
                            key: const ValueKey('review'),
                            service: _service,
                            date: _date,
                            time: _time,
                            languageCode: languageCode,
                            barberId: widget.barberId,
                            anyBarber: false,
                            offer: offer,
                            discountAmount: discountAmount,
                            totalBhd: totalBhd,
                          ),
                        _ => _PaymentMethodStep(
                            key: const ValueKey('payment'),
                            selectedMethod: _paymentMethod,
                            totalBhd: totalBhd,
                            onSelected: locking
                                ? null
                                : (value) {
                                    setState(() => _paymentMethod = value);
                                    _scheduleSaveDraft();
                                  },
                          ),
                      },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final int step;
  final int serviceStepIndex;
  final int dateStepIndex;
  final int timeStepIndex;
  final Service? service;
  final DateTime? date;
  final TimeOfDay? time;
  final String languageCode;
  final ValueChanged<int>? onJump;

  const _SelectionSummary({
    required this.step,
    required this.serviceStepIndex,
    required this.dateStepIndex,
    required this.timeStepIndex,
    required this.service,
    required this.date,
    required this.time,
    required this.languageCode,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLabel = date == null
        ? '—'
        : MaterialLocalizations.of(context).formatMediumDate(DateTime(date!.year, date!.month, date!.day));

    return HallaqCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: l10n.selectService,
              value: (service == null) ? '—' : service!.displayName(languageCode),
              selected: step == serviceStepIndex,
              onTap: onJump == null ? null : () => onJump?.call(serviceStepIndex),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCell(
              label: l10n.selectDate,
              value: dateLabel,
              selected: step == dateStepIndex,
              onTap: onJump == null ? null : () => onJump?.call(dateStepIndex),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCell(
              label: l10n.selectTime,
              value: time == null ? '—' : time!.format(context),
              selected: step == timeStepIndex,
              onTap: onJump == null ? null : () => onJump?.call(timeStepIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.26) : AppTheme.border),
            color: selected ? AppTheme.gold.withValues(alpha: 0.08) : AppTheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (onTap != null && !selected)
                    Tooltip(
                      message: l10n.bookingChange,
                      child: LuxuryIconButton(
                        icon: Icons.edit_rounded,
                        size: 32,
                        filled: false,
                        iconColor: AppTheme.gold,
                        hoverIconColor: AppTheme.gold,
                        onPressed: onTap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmSummary extends ConsumerWidget {
  final Service? service;
  final DateTime? date;
  final TimeOfDay? time;
  final String languageCode;
  final String? barberId;
  final bool anyBarber;
  final Offer? offer;
  final double discountAmount;
  final double? totalBhd;

  const _ConfirmSummary({
    super.key,
    required this.service,
    required this.date,
    required this.time,
    required this.languageCode,
    required this.barberId,
    required this.anyBarber,
    required this.offer,
    required this.discountAmount,
    required this.totalBhd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = service;
    if (s == null || date == null || time == null) return const SizedBox.shrink();
    final d = date!;
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(DateTime(d.year, d.month, d.day));
    final shortDateLabel = MaterialLocalizations.of(context).formatMediumDate(DateTime(d.year, d.month, d.day));
    final timeLabel = time!.format(context);
    final l10n = AppLocalizations.of(context);
    final total = (totalBhd ?? s.price).clamp(0, double.infinity).toDouble();
    final hasDiscount = discountAmount > 0.0005;
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        HallaqCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      AppTheme.gold.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppTheme.gold.withValues(alpha: 0.14),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        l10n.confirmBooking,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.displayName(languageCode),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
                    ),
                    if (s.displayDescription(languageCode).trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.displayDescription(languageCode),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _BookingHighlightChip(
                          icon: Icons.calendar_today_rounded,
                          label: l10n.selectDate,
                          value: shortDateLabel,
                        ),
                        _BookingHighlightChip(
                          icon: Icons.schedule_rounded,
                          label: l10n.selectTime,
                          value: timeLabel,
                        ),
                        if (offer != null && offer!.title.trim().isNotEmpty)
                          _BookingHighlightChip(
                            icon: Icons.local_offer_rounded,
                            label: 'Offer',
                            value: offer!.title.trim(),
                          ),
                        if (hasDiscount)
                          _BookingHighlightChip(
                            icon: Icons.sell_rounded,
                            label: 'Discount',
                            value: '-${discountAmount.toStringAsFixed(3)} BHD',
                          ),
                        _BookingHighlightChip(
                          icon: Icons.payments_rounded,
                          label: l10n.total,
                          value: '${total.toStringAsFixed(3)} BHD',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmBooking,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (anyBarber) ...[
                      _Line(label: l10n.selectBarber, value: l10n.bookingAnyBarber, icon: Icons.content_cut_rounded),
                      const SizedBox(height: 10),
                    ] else if ((barberId ?? '').trim().isNotEmpty) ...[
                      AsyncValueWidget<Barber>(
                        value: ref.watch(_bookingBarberProvider(barberId!.trim())),
                        data: (b) => _Line(label: l10n.selectBarber, value: b.displayName, icon: Icons.content_cut_rounded),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _Line(label: l10n.selectDate, value: dateLabel, icon: Icons.event_rounded),
                    const SizedBox(height: 10),
                    _Line(label: l10n.selectTime, value: timeLabel, icon: Icons.schedule_rounded),
                    const SizedBox(height: 10),
                    _Line(label: l10n.duration, value: '${s.durationMin} ${l10n.minutes}', icon: Icons.timelapse_rounded),
                    const SizedBox(height: 10),
                    if (hasDiscount) ...[
                      _Line(label: 'Subtotal', value: '${s.price.toStringAsFixed(3)} BHD', icon: Icons.receipt_long_rounded),
                      const SizedBox(height: 10),
                      _Line(label: 'Discount', value: '-${discountAmount.toStringAsFixed(3)} BHD', icon: Icons.sell_rounded),
                      const SizedBox(height: 10),
                    ],
                    _Line(label: l10n.total, value: '${total.toStringAsFixed(3)} BHD', icon: Icons.account_balance_wallet_rounded, highlighted: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodStep extends StatelessWidget {
  final String selectedMethod;
  final double? totalBhd;
  final ValueChanged<String>? onSelected;

  const _PaymentMethodStep({
    super.key,
    required this.selectedMethod,
    required this.totalBhd,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        HallaqCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.paymentMethods,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _PaymentOptionTile(
                title: 'Cash at Shop',
                subtitle: 'Pay at the shop',
                value: 'cash',
                enabled: true,
                selected: selectedMethod == 'cash',
                onSelected: onSelected,
              ),
              const SizedBox(height: 10),
              _PaymentOptionTile(
                title: 'Card',
                subtitle: 'Coming soon',
                value: 'card',
                enabled: false,
                selected: selectedMethod == 'card',
                onSelected: onSelected,
              ),
              const SizedBox(height: 10),
              _PaymentOptionTile(
                title: 'BenefitPay',
                subtitle: 'Coming soon',
                value: 'benefitpay',
                enabled: false,
                selected: selectedMethod == 'benefitpay',
                onSelected: onSelected,
              ),
              const SizedBox(height: 10),
              _PaymentOptionTile(
                title: 'Apple Pay',
                subtitle: 'Coming soon',
                value: 'apple_pay',
                enabled: false,
                selected: selectedMethod == 'apple_pay',
                onSelected: onSelected,
              ),
              const SizedBox(height: 10),
              _PaymentOptionTile(
                title: 'STC Pay',
                subtitle: 'Coming soon',
                value: 'stc_pay',
                enabled: false,
                selected: selectedMethod == 'stc_pay',
                onSelected: onSelected,
              ),
              if (totalBhd != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppTheme.gold.withValues(alpha: 0.10),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.total,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${totalBhd!.toStringAsFixed(3)} BHD',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final bool enabled;
  final bool selected;
  final ValueChanged<String>? onSelected;

  const _PaymentOptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnSelected = enabled ? onSelected : null;
    final borderColor = selected ? AppTheme.gold.withValues(alpha: 0.55) : AppTheme.border;
    final bg = selected ? AppTheme.gold.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.03);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: effectiveOnSelected == null
              ? null
              : () {
                  HallaqHaptics.selection();
                  effectiveOnSelected(value);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: bg,
              border: Border.all(color: borderColor),
              boxShadow: selected ? AppTheme.softShadow(opacity: 0.10) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected ? AppTheme.gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: selected ? AppTheme.gold.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.wallet_rounded,
                    size: 18,
                    color: selected ? AppTheme.gold : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppTheme.gold.withValues(alpha: 0.14),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      'Selected',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  )
                else if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Coming soon',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlighted;

  const _Line({
    required this.label,
    required this.value,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: highlighted ? AppTheme.gold.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: highlighted ? AppTheme.gold.withValues(alpha: 0.22) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: highlighted ? AppTheme.gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
            ),
            child: Icon(
              icon,
              size: 18,
              color: highlighted ? AppTheme.gold : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingHighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BookingHighlightChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.gold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final selected = i <= current;
        final active = i == current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 10),
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected ? null : AppTheme.border.withValues(alpha: 0.70),
              gradient: selected
                  ? LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        AppTheme.goldSoft.withValues(alpha: 0.26),
                        AppTheme.gold.withValues(alpha: 0.38),
                        AppTheme.goldDeep.withValues(alpha: 0.26),
                      ],
                    )
                  : null,
              boxShadow: active ? AppTheme.goldGlow(opacity: 0.12, blur: 18, y: 8) : null,
            ),
          ),
        );
      }),
    );
  }
}

class _BookingDebugPanel extends StatelessWidget {
  final int step;
  final bool busy;
  final bool busyTimedOut;
  final Service? service;
  final DateTime? date;
  final TimeOfDay? time;
  final AsyncValue<List<Service>> servicesValue;
  final AsyncValue<List<TimeOfDay>> availableTimesValue;
  final Object? lastError;
  final String? lastFlutterError;

  const _BookingDebugPanel({
    required this.step,
    required this.busy,
    required this.busyTimedOut,
    required this.service,
    required this.date,
    required this.time,
    required this.servicesValue,
    required this.availableTimesValue,
    required this.lastError,
    required this.lastFlutterError,
  });

  String _stateOf<T>(AsyncValue<T> v) {
    return v.when(
      data: (_) => 'data',
      loading: () => 'loading',
      error: (e, _) => 'error: $e',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sb = StringBuffer()
      ..writeln('step=$step busy=$busy timedOut=$busyTimedOut')
      ..writeln('service=${service?.id ?? '-'} (${service == null ? '-' : (service!.nameEn.trim().isNotEmpty ? service!.nameEn : service!.nameAr)})')
      ..writeln('date=${date?.toIso8601String() ?? '-'}')
      ..writeln('time=${time?.format(context) ?? '-'}')
      ..writeln('services=${_stateOf(servicesValue)}')
      ..writeln('times=${_stateOf(availableTimesValue)}');
    if (lastError != null) sb.writeln('lastError=$lastError');
    if (lastFlutterError != null && lastFlutterError!.trim().isNotEmpty) sb.writeln('flutterError=$lastFlutterError');

    return HallaqCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          title: const Text('Debug'),
          subtitle: Text('step $step • ${_stateOf(servicesValue)} • ${_stateOf(availableTimesValue)}'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SelectableText(
                sb.toString().trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickBarberSheet extends ConsumerWidget {
  final String shopId;
  final String? selectedBarberId;
  final bool selectedAny;

  const _PickBarberSheet({required this.shopId, required this.selectedBarberId, required this.selectedAny});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(barbersForShopProvider(shopId));
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.onyx3,
                  AppTheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: AppTheme.softShadow(opacity: 0.20),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.selectBarber,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: value.when(
                    data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(l10n.bookingNoBarbersAvailable),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return HallaqCard(
                            glass: true,
                            onTap: () => Navigator.of(context).pop(_anyBarberKey),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.gold.withValues(alpha: 0.16),
                                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.30)),
                                  ),
                                  child: const Icon(Icons.groups_rounded, size: 20, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.bookingAnyBarber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l10n.bookingAnyBarberSubtitle2,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedAny) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.gold.withValues(alpha: 0.16),
                                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
                                    ),
                                    child: const Icon(Icons.check_rounded, color: AppTheme.gold, size: 18),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        final b = items[index - 1];
                        final selected = selectedBarberId != null && b.id == selectedBarberId;
                        return HallaqCard(
                          glass: true,
                          onTap: () => Navigator.of(context).pop(b.id),
                          padding: const EdgeInsets.all(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.30) : Colors.transparent),
                              gradient: selected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.gold.withValues(alpha: 0.14),
                                        Colors.white.withValues(alpha: 0.00),
                                      ],
                                    )
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: LuxuryNetworkImage(
                                        imageUrl: b.avatarUrl,
                                        fallbackUrl: HallaqImages.barberAvatar(variant: '01'),
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (b.area ?? l10n.bahrain),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (b.ratingCount > 0) ...[
                                    HallaqRating(value: b.ratingAvg, count: b.ratingCount, iconSize: 14, showValue: false),
                                    const SizedBox(width: 10),
                                  ],
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected ? AppTheme.gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
                                      border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.28) : AppTheme.border),
                                    ),
                                    child: Icon(
                                      selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                                      color: selected ? AppTheme.gold : AppTheme.textMuted,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: items.length + 1,
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: HallaqLoading())),
                  error: (_, __) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.genericError, textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          HallaqButton(label: l10n.retry, expanded: false, onPressed: () => ref.invalidate(barbersForShopProvider(shopId))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceStep extends StatelessWidget {
  final AsyncValue<List<Service>> value;
  final Service? selected;
  final bool busy;
  final String languageCode;
  final VoidCallback? onRetry;
  final ValueChanged<Service> onSelected;

  const _ServiceStep({
    super.key,
    required this.value,
    required this.selected,
    required this.busy,
    required this.languageCode,
    required this.onRetry,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AsyncValueWidget<List<Service>>(
      value: value,
      onRetry: onRetry,
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: HallaqEmptyState(
              title: 'No services available yet.',
              description: '',
              showMascot: true,
              actionLabel: 'Explore other barbers',
              onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 120),
          itemBuilder: (context, index) {
            final s = items[index];
            final isSelected = selected?.id == s.id;
            final d = s.displayDescription(languageCode).trim();
            final variant = ((s.id.hashCode.abs() % 5) + 1).toString().padLeft(2, '0');
            return HallaqCard(
              onTap: () {
                HallaqHaptics.selection();
                onSelected(s);
              },
              glass: true,
              padding: EdgeInsets.zero,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: isSelected ? AppTheme.gold.withValues(alpha: 0.36) : Colors.transparent),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppTheme.gold.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: LuxuryNetworkImage(
                            imageUrl: s.imageUrl,
                            fallbackUrl: HallaqImages.goldScissorsIllustration(variant: variant),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.displayName(languageCode),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                if (s.isPopular) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppTheme.gold.withValues(alpha: 0.14),
                                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                                    ),
                                    child: Text(
                                      l10n.popular,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${s.durationMin} ${l10n.minutes} • ${s.price.toStringAsFixed(3)} BHD',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                            ),
                            if (d.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                d,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppTheme.gold : AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
        );
      },
    );
  }
}

class _DateStep extends ConsumerStatefulWidget {
  final DateTime? selected;
  final bool busy;
  final String? barberId;
  final String? shopId;
  final bool anyBarber;
  final String? serviceId;
  final int? durationMin;
  final ValueChanged<DateTime> onSelected;

  const _DateStep({
    super.key,
    required this.selected,
    required this.busy,
    required this.barberId,
    required this.shopId,
    required this.anyBarber,
    required this.serviceId,
    required this.durationMin,
    required this.onSelected,
  });

  @override
  ConsumerState<_DateStep> createState() => _DateStepState();
}

class _DateStepState extends ConsumerState<_DateStep> {
  late DateTime _month;
  DateTime? _prefetchedNextMonth;
  RealtimeChannel? _availabilityChannel;
  SupabaseClient? _realtimeClient;
  Timer? _availabilityDebounce;
  bool _findingNext = false;
  String? _tapHint;
  bool _autoSkippedInitialEmptyMonth = false;

  @override
  void initState() {
    super.initState();
    final now = _nowBahrain();
    final selected = widget.selected;
    final base = selected ?? DateTime(now.year, now.month, now.day);
    _month = DateTime(base.year, base.month, 1);
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant _DateStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && widget.selected != null) {
      final s = widget.selected!;
      _month = DateTime(s.year, s.month, 1);
    }
    if (oldWidget.barberId != widget.barberId ||
        oldWidget.shopId != widget.shopId ||
        oldWidget.anyBarber != widget.anyBarber ||
        oldWidget.serviceId != widget.serviceId ||
        oldWidget.durationMin != widget.durationMin) {
      _setupRealtime();
    }
  }

  @override
  void dispose() {
    _availabilityDebounce?.cancel();
    final ch = _availabilityChannel;
    if (ch != null) {
      _realtimeClient?.removeChannel(ch);
    }
    _availabilityChannel = null;
    _realtimeClient = null;
    super.dispose();
  }

  void _setupRealtime() {
    _availabilityDebounce?.cancel();
    final existing = _availabilityChannel;
    if (existing != null) {
      _realtimeClient?.removeChannel(existing);
      _availabilityChannel = null;
    }

    final durationMin = widget.durationMin;
    if (durationMin == null || durationMin <= 0) return;

    final barberId = widget.barberId?.trim();
    final shopId = widget.shopId?.trim();
    final anyBarber = widget.anyBarber;

    if (anyBarber) {
      if (shopId == null || shopId.isEmpty) return;
    } else {
      if (barberId == null || barberId.isEmpty) return;
    }

    void scheduleInvalidate() {
      _availabilityDebounce?.cancel();
      _availabilityDebounce = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        if (anyBarber) {
          ref.invalidate(shopAvailableDaysForMonthProvider((shopId: shopId!, serviceId: widget.serviceId, durationMin: durationMin, month: _month)));
          final selected = widget.selected;
          if (selected != null) {
            ref.invalidate(shopAvailableTimesWithBarberProvider((shopId: shopId, serviceId: widget.serviceId, day: selected, durationMin: durationMin)));
          }
        } else {
          ref.invalidate(availableDaysForMonthProvider((barberId: barberId!, durationMin: durationMin, month: _month)));
          final selected = widget.selected;
          if (selected != null) {
            ref.invalidate(availableTimesForDayProvider((barberId: barberId, day: selected, durationMin: durationMin)));
          }
        }
      });
    }

    SupabaseClient client;
    try {
      client = ref.read(supabaseClientProvider);
    } catch (_) {
      return;
    }
    _realtimeClient = client;
    final channel = client
        .channel(anyBarber ? 'rt_avail_shop_$shopId' : 'rt_avail_barber_$barberId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) => scheduleInvalidate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'barber_time_off',
          callback: (_) => scheduleInvalidate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'barber_working_hours',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();

    _availabilityChannel = channel;
  }

  DateTime _nowBahrain() {
    return ShopTime.now();
  }

  void _prefetchNext({
    required DateTime month,
    required int durationMin,
    required bool anyBarber,
    String? barberId,
    String? shopId,
  }) {
    final next = DateTime(month.year, month.month + 1, 1);
    if (_prefetchedNextMonth?.year == next.year && _prefetchedNextMonth?.month == next.month) return;
    _prefetchedNextMonth = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (anyBarber) {
        final id = shopId?.trim() ?? '';
        if (id.isEmpty) return;
        ref.read(shopAvailableDaysForMonthProvider((shopId: id, serviceId: widget.serviceId, durationMin: durationMin, month: next)));
      } else {
        final id = barberId?.trim() ?? '';
        if (id.isEmpty) return;
        ref.read(availableDaysForMonthProvider((barberId: id, durationMin: durationMin, month: next)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = _nowBahrain();
    final today = DateTime(now.year, now.month, now.day);
    final barberId = widget.barberId?.trim();
    final shopId = widget.shopId?.trim();
    final anyBarber = widget.anyBarber;
    final durationMin = widget.durationMin;

    if (durationMin == null || durationMin <= 0) {
      return Center(
        child: HallaqEmptyState(
          title: l10n.selectDate,
          description: l10n.bookingSelectServiceToSeeAvailability,
          showMascot: true,
          compact: true,
        ),
      );
    }

    if (!anyBarber && (barberId == null || barberId.isEmpty)) {
      return Center(
        child: HallaqEmptyState(
          title: l10n.selectDate,
          description: l10n.bookingSelectBarberToSeeAvailability,
          showMascot: true,
          compact: true,
        ),
      );
    }
    if (anyBarber && (shopId == null || shopId.isEmpty)) {
      return Center(
        child: HallaqEmptyState(
          title: l10n.selectDate,
          description: l10n.bookingSelectShopToSeeAvailability,
          showMascot: true,
          compact: true,
        ),
      );
    }

    final daysValue = anyBarber
        ? ref.watch(shopAvailableDaysForMonthProvider((shopId: shopId!, serviceId: widget.serviceId, durationMin: durationMin, month: _month)))
        : ref.watch(availableDaysForMonthProvider((barberId: barberId!, durationMin: durationMin, month: _month)));

    _prefetchNext(month: _month, durationMin: durationMin, anyBarber: anyBarber, barberId: barberId, shopId: shopId);

    return RefreshIndicator(
      color: AppTheme.gold,
      backgroundColor: AppTheme.surface,
      onRefresh: () async {
        if (anyBarber) {
          ref.invalidate(shopAvailableDaysForMonthProvider((shopId: shopId!, serviceId: widget.serviceId, durationMin: durationMin, month: _month)));
        } else {
          ref.invalidate(availableDaysForMonthProvider((barberId: barberId!, durationMin: durationMin, month: _month)));
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          HallaqCard(
            glass: true,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.07),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                _MonthHeader(
                  month: _month,
                  canPrev: !_isBeforeMonth(DateTime(_month.year, _month.month - 1, 1), today),
                  onPrev: (widget.busy || daysValue.isLoading || _findingNext)
                      ? null
                      : () {
                          unawaited(
                            _goToNearestAvailableMonth(
                              start: DateTime(_month.year, _month.month - 1, 1),
                              step: -1,
                              today: today,
                              anyBarber: anyBarber,
                              durationMin: durationMin,
                              barberId: barberId,
                              shopId: shopId,
                            ),
                          );
                        },
                  onNext: (widget.busy || daysValue.isLoading || _findingNext)
                      ? null
                      : () {
                          unawaited(
                            _goToNearestAvailableMonth(
                              start: DateTime(_month.year, _month.month + 1, 1),
                              step: 1,
                              today: today,
                              anyBarber: anyBarber,
                              durationMin: durationMin,
                              barberId: barberId,
                              shopId: shopId,
                            ),
                          );
                        },
                ),
                const SizedBox(height: 10),
                _WeekdayHeader(month: _month),
                const SizedBox(height: 10),
                const _CalendarLegend(),
                const SizedBox(height: 10),
                daysValue.when(
                  data: (availability) {
                    _ensureSelectedIsValid(today, availability);
                    final hasAny = availability.values.any((e) => e == true);
                    _autoSkipInitialEmptyMonth(
                      hasAny: hasAny,
                      today: today,
                      anyBarber: anyBarber,
                      durationMin: durationMin,
                      barberId: barberId,
                      shopId: shopId,
                    );
                    return Column(
                      children: [
                        _MonthGrid(
                          month: _month,
                          today: today,
                          selected: widget.selected,
                          availability: availability,
                          enabled: !widget.busy,
                          onSelected: widget.onSelected,
                          onHint: (v) => setState(() => _tapHint = v),
                        ),
                        if ((_tapHint ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _tapHint!,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                        if (!hasAny) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              l10n.bookingNoAvailabilityThisMonth,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          HallaqButton(
                            label: _findingNext ? l10n.bookingSearching : l10n.bookingNextAvailableDay,
                            icon: Icons.auto_awesome_rounded,
                            variant: HallaqButtonVariant.ghost,
                            onPressed: (_findingNext || widget.busy)
                                ? null
                                : () => _jumpToNextAvailable(
                                      barberId: barberId,
                                      shopId: shopId,
                                      anyBarber: anyBarber,
                                      durationMin: durationMin,
                                    ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const _MonthGridSkeleton(),
                  error: (e, __) => Center(
                    child: HallaqEmptyState(
                      title: l10n.selectDate,
                      description: '${userFacingError(context, e).description}${kDebugMode ? '\n$e' : ''}',
                      showMascot: true,
                      compact: true,
                      actionLabel: l10n.tryAgain,
                      onAction: () {
                        if (anyBarber) {
                          ref.invalidate(shopAvailableDaysForMonthProvider((shopId: shopId!, serviceId: widget.serviceId, durationMin: durationMin, month: _month)));
                        } else {
                          ref.invalidate(availableDaysForMonthProvider((barberId: barberId!, durationMin: durationMin, month: _month)));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.bookingSelectedDate,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.gold.withValues(alpha: 0.14),
                        ),
                        child: Icon(
                          widget.selected == null ? Icons.calendar_month_rounded : Icons.check_rounded,
                          size: 18,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.selected == null
                              ? l10n.bookingChooseDateToContinue
                              : MaterialLocalizations.of(context).formatMediumDate(
                                  DateTime(widget.selected!.year, widget.selected!.month, widget.selected!.day),
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _ensureSelectedIsValid(DateTime today, Map<DateTime, bool> availability) {
    if (widget.busy) return;
    final selected = widget.selected;
    bool isSelectable(DateTime d) {
      final d0 = DateTime(d.year, d.month, d.day);
      if (d0.isBefore(today)) return false;
      return availability[d0] == true;
    }

    if (selected != null && isSelectable(selected)) return;

    DateTime? next;
    final month0 = DateTime(_month.year, _month.month, 1);
    final nextMonth = (_month.month == 12) ? DateTime(_month.year + 1, 1, 1) : DateTime(_month.year, _month.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    for (var d = month0; !d.isAfter(lastDay); d = d.add(const Duration(days: 1))) {
      if (isSelectable(d)) {
        next = d;
        break;
      }
    }
    if (next != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSelected(next!));
    }
  }

  Future<void> _jumpToNextAvailable({
    required String? barberId,
    required String? shopId,
    required bool anyBarber,
    required int durationMin,
  }) async {
    if (anyBarber) {
      final id = shopId?.trim() ?? '';
      if (id.isEmpty) return;
    } else {
      final id = barberId?.trim() ?? '';
      if (id.isEmpty) return;
    }

    setState(() => _findingNext = true);
    try {
      var month = _month;
      for (var i = 0; i < 8; i++) {
        final map = anyBarber
            ? await ref.read(shopAvailableDaysForMonthProvider((shopId: shopId!.trim(), serviceId: widget.serviceId, durationMin: durationMin, month: month)).future)
            : await ref.read(availableDaysForMonthProvider((barberId: barberId!.trim(), durationMin: durationMin, month: month)).future);
        final days = map.entries.where((e) => e.value == true).map((e) => e.key).toList(growable: false)
          ..sort((a, b) => a.compareTo(b));
        if (days.isNotEmpty) {
          if (!mounted) return;
          setState(() => _month = DateTime(days.first.year, days.first.month, 1));
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSelected(days.first));
          return;
        }
        month = DateTime(month.year, month.month + 1, 1);
      }
      if (mounted) {
        showErrorSnackBar(context, AppException(AppLocalizations.of(context).bookingNoAvailabilityFoundUpcomingMonths));
      }
    } finally {
      if (mounted) setState(() => _findingNext = false);
    }
  }

  void _autoSkipInitialEmptyMonth({
    required bool hasAny,
    required DateTime today,
    required bool anyBarber,
    required int durationMin,
    required String? barberId,
    required String? shopId,
  }) {
    if (_autoSkippedInitialEmptyMonth) return;
    if (widget.selected != null) return;
    if (widget.busy) return;
    if (_findingNext) return;
    final month0 = DateTime(_month.year, _month.month, 1);
    final todayMonth = DateTime(today.year, today.month, 1);
    if (month0.year != todayMonth.year || month0.month != todayMonth.month) return;
    if (hasAny) return;
    _autoSkippedInitialEmptyMonth = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _jumpToNextAvailableMonth(
          barberId: barberId,
          shopId: shopId,
          anyBarber: anyBarber,
          durationMin: durationMin,
          today: today,
        ),
      );
    });
  }

  Future<void> _jumpToNextAvailableMonth({
    required String? barberId,
    required String? shopId,
    required bool anyBarber,
    required int durationMin,
    required DateTime today,
  }) async {
    if (anyBarber) {
      final id = shopId?.trim() ?? '';
      if (id.isEmpty) return;
    } else {
      final id = barberId?.trim() ?? '';
      if (id.isEmpty) return;
    }

    setState(() => _findingNext = true);
    try {
      var month = DateTime(_month.year, _month.month + 1, 1);
      for (var i = 0; i < 8; i++) {
        final map = anyBarber
            ? await ref.read(shopAvailableDaysForMonthProvider((shopId: shopId!.trim(), serviceId: widget.serviceId, durationMin: durationMin, month: month)).future)
            : await ref.read(availableDaysForMonthProvider((barberId: barberId!.trim(), durationMin: durationMin, month: month)).future);
        if (map.values.any((e) => e == true)) {
          if (!mounted) return;
          setState(() => _month = DateTime(month.year, month.month, 1));
          return;
        }
        month = DateTime(month.year, month.month + 1, 1);
      }
    } finally {
      if (mounted) setState(() => _findingNext = false);
    }
  }

  Future<void> _goToNearestAvailableMonth({
    required DateTime start,
    required int step,
    required DateTime today,
    required bool anyBarber,
    required int durationMin,
    required String? barberId,
    required String? shopId,
  }) async {
    if (anyBarber) {
      final id = shopId?.trim() ?? '';
      if (id.isEmpty) return;
    } else {
      final id = barberId?.trim() ?? '';
      if (id.isEmpty) return;
    }

    if (step < 0 && _isBeforeMonth(start, today)) return;

    setState(() => _findingNext = true);
    try {
      DateTime? found;
      var month = start;
      for (var i = 0; i < 12; i++) {
        if (step < 0 && _isBeforeMonth(month, today)) break;
        final map = anyBarber
            ? await ref.read(shopAvailableDaysForMonthProvider((shopId: shopId!.trim(), serviceId: widget.serviceId, durationMin: durationMin, month: month)).future)
            : await ref.read(availableDaysForMonthProvider((barberId: barberId!.trim(), durationMin: durationMin, month: month)).future);
        if (map.values.any((e) => e == true)) {
          found = month;
          break;
        }
        month = DateTime(month.year, month.month + step, 1);
      }
      if (!mounted) return;
      setState(() => _month = found ?? start);
    } finally {
      if (mounted) setState(() => _findingNext = false);
    }
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final bool canPrev;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _MonthHeader({required this.month, required this.canPrev, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthNavIconButton(icon: Icons.chevron_left_rounded, onPressed: canPrev ? onPrev : null),
        Expanded(
          child: Center(
            child: Text(
              DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(month),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        _MonthNavIconButton(icon: Icons.chevron_right_rounded, onPressed: onNext),
      ],
    );
  }
}

class _MonthNavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _MonthNavIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          foregroundColor: AppTheme.text,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.02),
          disabledForegroundColor: AppTheme.textMuted.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final DateTime month;

  const _WeekdayHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex;
    final labels = <String>[
      loc.narrowWeekdays[DateTime.sunday - 1],
      loc.narrowWeekdays[DateTime.monday - 1],
      loc.narrowWeekdays[DateTime.tuesday - 1],
      loc.narrowWeekdays[DateTime.wednesday - 1],
      loc.narrowWeekdays[DateTime.thursday - 1],
      loc.narrowWeekdays[DateTime.friday - 1],
      loc.narrowWeekdays[DateTime.saturday - 1],
    ];
    final ordered = [...labels.sublist(first), ...labels.sublist(0, first)];
    return Row(
      children: List.generate(7, (i) {
        return Expanded(
          child: Center(
            child: Text(
              ordered[i],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
            ),
          ),
        );
      }),
    );
  }
}

class _MonthGridSkeleton extends StatelessWidget {
  const _MonthGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth / 7).clamp(24.0, 80.0);
        final circle = (cell * 0.72).clamp(22.0, 42.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: 1,
          ),
          itemCount: 42,
          itemBuilder: (_, __) => Center(
            child: Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
            ),
          ),
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final Map<DateTime, bool> availability;
  final bool enabled;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<String>? onHint;

  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.availability,
    required this.enabled,
    required this.onSelected,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final loc = MaterialLocalizations.of(context);
        final first = loc.firstDayOfWeekIndex;
        final month0 = DateTime(month.year, month.month, 1);
        final startOffset = (month0.weekday % 7 - first) % 7;
        final start = month0.subtract(Duration(days: startOffset));
        final nextMonth = (month.month == 12) ? DateTime(month.year + 1, 1, 1) : DateTime(month.year, month.month + 1, 1);
        final lastDay = nextMonth.subtract(const Duration(days: 1));
        final daysInMonth = lastDay.day;

        final cell = (constraints.maxWidth / 7).clamp(24.0, 90.0);
        final circle = (cell * 0.72).clamp(22.0, 44.0);
        final fontSize = (circle * 0.46).clamp(12.0, 18.0);

        DateTime dayAt(int index) => DateTime(start.year, start.month, start.day + index);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: 1,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final d = dayAt(index);
            final d0 = DateTime(d.year, d.month, d.day);
            final inMonth = d0.month == month.month;
            final isPast = d0.isBefore(today);
            final showEmpty = !inMonth || d0.day > daysInMonth;
            if (showEmpty) return const SizedBox.shrink();

            final isSelected = selected != null && selected!.year == d0.year && selected!.month == d0.month && selected!.day == d0.day;
            final isAvailable = availability[d0] == true;
            final isFull = !isPast && availability.containsKey(d0) && availability[d0] == false;
            final isUnknown = !isPast && !availability.containsKey(d0);

            final canTap = enabled && !isPast && isAvailable;
            final canExplainFull = enabled && !isPast && isFull;
            final canExplainPast = enabled && isPast;
            final canExplainUnknown = enabled && isUnknown;

            final bg = isSelected
                ? AppTheme.gold
                : isPast
                    ? AppTheme.border.withValues(alpha: 0.20)
                    : isFull
                        ? AppTheme.error.withValues(alpha: 0.30)
                        : isAvailable
                            ? AppTheme.success.withValues(alpha: 0.32)
                            : Colors.transparent;

            final fg = isSelected
                ? Colors.black
                : isPast
                    ? AppTheme.textMuted.withValues(alpha: 0.65)
                    : (bg == Colors.transparent ? AppTheme.text : Colors.black);

            final l10n = AppLocalizations.of(context);
            final dayLabel = MaterialLocalizations.of(context).formatFullDate(d0);
            final status = isPast
                ? l10n.bookingStatusPast
                : isFull
                    ? l10n.bookingStatusFull
                    : isAvailable
                        ? l10n.bookingStatusAvailable
                        : l10n.bookingStatusLoading;
            void tap() {
              if (canTap) {
                onHint?.call(l10n.bookingStatusAvailable);
                onSelected(d0);
                return;
              }
              if (canExplainPast) {
                onHint?.call(l10n.bookingStatusPast);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.bookingPastDateSnack)),
                );
                return;
              }
              if (canExplainFull) {
                onHint?.call(l10n.bookingStatusFull);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.bookingFullyBookedSnack)),
                );
                return;
              }
              if (canExplainUnknown) {
                onHint?.call(l10n.bookingStatusLoading);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.bookingLoadingAvailabilitySnack)),
                );
              }
            }

            final key = 'booking_day_${d0.year}-${d0.month.toString().padLeft(2, '0')}-${d0.day.toString().padLeft(2, '0')}';
            return Semantics(
              label: '$dayLabel, $status',
              button: true,
              enabled: enabled,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey(key),
                  customBorder: const CircleBorder(),
                  onTap: !enabled ? null : tap,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: circle,
                      height: circle,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${d0.day}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w900,
                                fontSize: fontSize,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

bool _isBeforeMonth(DateTime month, DateTime today) {
  final a = DateTime(month.year, month.month, 1);
  final b = DateTime(today.year, today.month, 1);
  return a.isBefore(b);
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget pill(Color c, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: c.withValues(alpha: 0.18),
          border: Border.all(color: c.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        pill(AppTheme.success, l10n.bookingStatusAvailable),
        pill(AppTheme.error, l10n.bookingStatusFull),
        pill(AppTheme.border.withValues(alpha: 0.85), l10n.bookingStatusPast),
      ],
    );
  }
}

class _TimeStep extends StatelessWidget {
  final AsyncValue<List<TimeOfDay>> value;
  final TimeOfDay? selected;
  final bool busy;
  final VoidCallback? onRetry;
  final ValueChanged<TimeOfDay> onSelected;

  const _TimeStep({
    super.key,
    required this.value,
    required this.selected,
    required this.busy,
    required this.onRetry,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AsyncValueWidget<List<TimeOfDay>>(
      value: value,
      onRetry: onRetry,
      error: (e, __) {
        final ui = userFacingError(context, e);
        return Center(
          child: HallaqEmptyState(
            title: ui.title,
            description: '${ui.description}${kDebugMode ? '\n$e' : ''}',
            showMascot: true,
            actionLabel: onRetry == null ? null : l10n.tryAgain,
            onAction: onRetry,
          ),
        );
      },
      data: (slots) {
        if (slots.isEmpty) {
          return Center(
            child: HallaqEmptyState(
              title: l10n.noAvailabilityTitle,
              description: l10n.noAvailabilityDescription,
              showMascot: true,
              compact: true,
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.gold,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            onRetry?.call();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              HallaqCard(
                glass: true,
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.gold.withValues(alpha: 0.14),
                        ),
                        child: const Icon(Icons.schedule_rounded, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.selectTime,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: slots.map((t) {
                  final isSelected = selected == t;
                  return _SelectChip(
                    label: t.format(context),
                    selected: isSelected,
                    onTap: busy ? null : () => onSelected(t),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SelectChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap == null
              ? null
              : () {
                  HallaqHaptics.selection();
                  onTap?.call();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected ? null : Colors.white.withValues(alpha: 0.04),
              gradient: selected ? AppTheme.goldGradient : null,
              border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.06)),
              boxShadow: selected ? AppTheme.goldGlow(opacity: 0.14, blur: 20, y: 10) : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? const Color(0xFF111111) : AppTheme.text,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingSuccessSheet extends StatelessWidget {
  final String? barberId;
  final Barber? barber;

  const _BookingSuccessSheet({this.barberId, this.barber});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: _BookingSuccessCard(barberId: barberId, barber: barber),
      ),
    );
  }
}

class _BookingSuccessCard extends ConsumerStatefulWidget {
  final String? barberId;
  final Barber? barber;

  const _BookingSuccessCard({this.barberId, this.barber});

  @override
  ConsumerState<_BookingSuccessCard> createState() => _BookingSuccessCardState();
}

class _BookingSuccessCardState extends ConsumerState<_BookingSuccessCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider).value;
    final barberId = widget.barberId ?? widget.barber?.id;
    final barber = widget.barber;

    final hasBarber = barberId != null && barberId.trim().isNotEmpty;
    final showMyBarberCta = barberId != null && barberId.trim().isNotEmpty && profile != null && profile.myBarberId != barberId;
    final viewHeight = MediaQuery.sizeOf(context).height;
    final insets = MediaQuery.paddingOf(context).vertical;
    final maxHeight = math.max(320.0, viewHeight - insets - 52);

    return HallaqCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF242424),
                      AppTheme.surface,
                      AppTheme.onyx,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -36,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.gold.withValues(alpha: 0.26),
                        AppTheme.gold.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.goldSoft,
                                  AppTheme.gold,
                                  AppTheme.success,
                                ],
                              ),
                              boxShadow: [
                                ...AppTheme.goldGlow(opacity: 0.20, blur: 30, y: 10),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.black, size: 34),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            l10n.bookingCreatedTitle,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.bookingCreatedSubtitle,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasBarber) ...[
                      const SizedBox(height: 16),
                      if (barber != null)
                        _SuccessBarberCard(barber: barber, l10n: l10n)
                      else
                        AsyncValueWidget<Barber>(
                          value: ref.watch(_bookingBarberProvider(barberId.trim())),
                          data: (b) => _SuccessBarberCard(barber: b, l10n: l10n),
                        ),
                      const SizedBox(height: 12),
                      HallaqButton(
                        label: l10n.getDirections,
                        icon: Icons.directions_rounded,
                        variant: HallaqButtonVariant.secondary,
                        onPressed: () {
                          unawaited(() async {
                            try {
                              final Barber b = barber ?? await ref.read(_bookingBarberProvider(barberId.trim()).future);
                              Barbershop? shop;
                              if (b.shopId != null) {
                                try {
                                  shop = await ref.read(_bookingShopProvider(b.shopId!).future);
                                } catch (_) {}
                              }
                              final ok = await launchDirections(
                                googleMapsUrl: shop?.googleMapsUrl,
                                lat: shop?.lat ?? b.lat,
                                lng: shop?.lng ?? b.lng,
                              );
                              if (!context.mounted) return;
                              if (!ok) showErrorSnackBar(context, 'Unable to open maps');
                            } catch (_) {
                              if (!context.mounted) return;
                              showErrorSnackBar(context, 'Unable to open maps');
                            }
                          }());
                        },
                      ),
                    ],
                    if (showMyBarberCta) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: AppTheme.gold.withValues(alpha: 0.16),
                                  ),
                                  child: Icon(Icons.star_rounded, color: AppTheme.gold, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.makeMyBarberTitle,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.makeMyBarberSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            HallaqButton(
                              label: l10n.setAsMyBarber,
                              icon: Icons.star_rounded,
                              isLoading: _busy,
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      setState(() => _busy = true);
                                      try {
                                        await ref.read(profileRepositoryProvider).setMyBarber(barberId);
                                        ref.invalidate(myProfileProvider);
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                      } finally {
                                        if (mounted) setState(() => _busy = false);
                                      }
                                    },
                            ),
                            const SizedBox(height: 10),
                            HallaqButton(
                              label: l10n.notNow,
                              variant: HallaqButtonVariant.ghost,
                              onPressed: _busy ? null : () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      HallaqButton(
                        label: l10n.done,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBarberCard extends StatelessWidget {
  final Barber barber;
  final AppLocalizations l10n;

  const _SuccessBarberCard({required this.barber, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final variant = ((barber.id.hashCode.abs() % 5) + 1).toString().padLeft(2, '0');
    final subtitle = (barber.specialty ?? '').trim().isNotEmpty ? barber.specialty!.trim() : (barber.area ?? l10n.bahrain);
    final badgeLabel = barber.badgeVerified
        ? l10n.badgeVerified
        : barber.badgeCertified
            ? l10n.badgeCertified
            : barber.badgeTopRated
                ? l10n.badgeTopRated
                : null;

    return HallaqCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: LuxuryNetworkImage(
                      imageUrl: barber.avatarUrl,
                      fallbackUrl: HallaqImages.barberAvatar(variant: variant),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barber.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.gold.withValues(alpha: 0.14),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.26)),
                  ),
                  child: Icon(
                    barber.badgeVerified ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                    color: AppTheme.gold,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppTheme.gold, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            barber.area ?? l10n.bahrain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: HallaqRating(
                    value: barber.ratingAvg,
                    count: barber.ratingCount > 0 ? barber.ratingCount : null,
                    iconSize: 14,
                  ),
                ),
              ],
            ),
            if (badgeLabel != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppTheme.gold.withValues(alpha: 0.14),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
