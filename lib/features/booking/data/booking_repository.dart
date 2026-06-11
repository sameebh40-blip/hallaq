import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/models/booking.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../barber/data/barber_repository.dart';

class BookingRepository {
  final SupabaseClient _client;
  final KvStore _kv;
  final SystemLogsRepository _logs;

  BookingRepository(this._client, this._kv, this._logs);

  void _logFailure(String action, Object error, {Map<String, dynamic>? meta}) {
    _logs.logErrorUnawaited(
      page: 'booking_repository',
      action: action,
      error: error,
      meta: meta,
    );
  }

  ({String holdId, DateTime expiresAt})? _parseHoldResult(dynamic data) {
    final Map<String, dynamic> m;
    if (data is List) {
      if (data.isEmpty) return null;
      m = Map<String, dynamic>.from(data.first as Map);
    } else if (data is Map) {
      m = Map<String, dynamic>.from(data);
    } else {
      return null;
    }

    final holdId = ((m['hold_id'] as String?) ?? '').trim();
    final expiresRaw = m['expires_at'];
    if (holdId.isEmpty || expiresRaw == null) return null;
    final expiresAt = expiresRaw is String ? DateTime.parse(expiresRaw) : (expiresRaw as DateTime);
    return (holdId: holdId, expiresAt: expiresAt);
  }

  Future<({String holdId, DateTime expiresAt})?> _recoverActiveHold({
    required String userId,
    required String serviceId,
    required String barberId,
    required String startAtIso,
    required String? shopId,
  }) async {
    try {
      var query = _client
          .from('booking_slot_holds')
          .select('id, expires_at')
          .eq('profile_id', userId)
          .eq('service_id', serviceId)
          .eq('barber_id', barberId)
          .eq('start_at', startAtIso)
          .isFilter('consumed_at', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          ;

      query = (shopId == null || shopId.trim().isEmpty) ? query.isFilter('shop_id', null) : query.eq('shop_id', shopId.trim());

      final data = await query.order('created_at', ascending: false).limit(1).maybeSingle();
      if (data == null) return null;

      final holdId = ((data as Map)['id'] as String?)?.trim() ?? '';
      final expiresRaw = data['expires_at'];
      if (holdId.isEmpty || expiresRaw == null) return null;
      final expiresAt = expiresRaw is String ? DateTime.parse(expiresRaw) : (expiresRaw as DateTime);
      return (holdId: holdId, expiresAt: expiresAt);
    } catch (_) {
      return null;
    }
  }

  Future<({String holdId, DateTime expiresAt})> holdBookingSlot({
    required String serviceId,
    required DateTime startAt,
    required String barberId,
    String? shopId,
    int holdMinutes = 5,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    final normalizedShopId = (shopId ?? '').trim().isEmpty ? null : shopId?.trim();
    final startAtIso = startAt.toUtc().toIso8601String();
    try {
      final data = await _client.rpc(
        'hold_booking_slot',
        params: {
          'service_id': serviceId,
          'start_at': startAtIso,
          'barber_id': barberId,
          'shop_id': normalizedShopId,
          'hold_minutes': holdMinutes,
        },
      );
      final parsed = _parseHoldResult(data);
      if (parsed != null) {
        return parsed;
      }

      final recovered = await _recoverActiveHold(
        userId: user.id,
        serviceId: serviceId,
        barberId: barberId,
        startAtIso: startAtIso,
        shopId: normalizedShopId,
      );
      if (recovered != null) return recovered;

      throw const AppException('Failed to reserve time slot');
    } catch (e) {
      _logFailure('hold_booking_slot_failed', e, meta: {
        'service_id': serviceId,
        'barber_id': barberId,
        'shop_id': normalizedShopId,
        'hold_minutes': holdMinutes,
      });

      final recovered = await _recoverActiveHold(
        userId: user.id,
        serviceId: serviceId,
        barberId: barberId,
        startAtIso: startAtIso,
        shopId: normalizedShopId,
      );
      if (recovered != null) return recovered;

      if (e is PostgrestException) {
        final code = (e.code ?? '').trim().toUpperCase();
        final msg = (e.message).toLowerCase();
        if (code == '42P01' && msg.contains('service_barbers') && msg.contains('does not exist')) {
          throw AppException('Booking system is missing a required database table. Please apply the latest Supabase migrations and try again.', cause: e);
        }
        if (code == 'PGRST202' || (msg.contains('could not find the function') && msg.contains('hold_booking_slot'))) {
          throw AppException('We couldn’t reserve this time. Please choose another time.', cause: e);
        }
        if (msg.contains('slot_held')) {
          throw AppException('This time is being held by another customer. Please select another time.', cause: e);
        }
        if (msg.contains('booking_overlap') || msg.contains('exclude')) {
          throw AppException('This time is no longer available. Please select another time.', cause: e);
        }
        if (msg.contains('barber_time_off')) {
          throw AppException('Barber is not available at this time. Please select another time.', cause: e);
        }
        if (msg.contains('service_inactive') || msg.contains('service_not_found') || msg.contains('service_not_for_barber') || msg.contains('service_not_for_shop')) {
          throw AppException('Selected service is not available. Please choose another service.', cause: e);
        }
      }
      throw AppException('Failed to reserve time slot', cause: e);
    }
  }

  Future<void> releaseBookingSlot(String holdId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final id = holdId.trim();
    if (id.isEmpty) return;
    try {
      await _client.rpc('release_booking_slot', params: {'hold_id': id});
    } catch (_) {}
  }

  Future<Map<String, Map<String, dynamic>>> _profilesByIds(Iterable<String?> ids) async {
    final unique = ids.map((e) => (e ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final data = await _client.from('profiles').select('id, full_name, phone, avatar_url, avatar_path').inFilter('id', unique);
    final out = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      out[id] = m;
    }
    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _servicesByIds(Iterable<String?> ids) async {
    final unique = ids.map((e) => (e ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final data = await _client.from('services').select('id, name, name_en, name_ar, price_bhd, duration_minutes, image_url').inFilter('id', unique);
    final out = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      out[id] = m;
    }
    return out;
  }

  static const _bookingSelect =
      'id, customer_profile_id, barber_id, shop_id, service_id, start_at, end_at, status, total_price, deposit_required_amount, service_name_en, service_name_ar, barber_name, shop_name';

  Future<Booking?> getBookingOverviewById(String bookingId) async {
    final id = bookingId.trim();
    if (id.isEmpty) return null;
    try {
      final data = await _client.from('booking_overview').select(_bookingSelect).eq('id', id).maybeSingle();
      if (data == null) return null;
      return Booking.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw AppException('Failed to load booking', cause: e);
    }
  }

  Future<Booking?> getMyLastBookingForBarber(String barberId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('booking_overview')
          .select(_bookingSelect)
          .eq('customer_profile_id', user.id)
          .eq('barber_id', barberId)
          .lt('start_at', now)
          .order('start_at', ascending: false)
          .limit(1);

      final list = (data as List);
      if (list.isEmpty) return null;
      return Booking.fromJson(Map<String, dynamic>.from(list.first));
    } catch (e) {
      throw AppException('Failed to load last booking', cause: e);
    }
  }

  Future<Booking?> getMyLastCompletedBookingForBarber(String barberId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('booking_overview')
          .select(_bookingSelect)
          .eq('customer_profile_id', user.id)
          .eq('barber_id', barberId)
          .eq('status', 'completed')
          .lt('start_at', now)
          .order('start_at', ascending: false)
          .limit(1);

      final list = (data as List);
      if (list.isEmpty) return null;
      return Booking.fromJson(Map<String, dynamic>.from(list.first));
    } catch (e) {
      throw AppException('Failed to load last completed booking', cause: e);
    }
  }

  Future<List<Booking>> listMyBookings({required bool upcoming, int limit = 60, int offset = 0}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final query = _client.from('booking_overview').select(_bookingSelect).eq('customer_profile_id', user.id);
      final data = upcoming
          ? await query.gte('start_at', now).order('start_at', ascending: true).range(offset, offset + limit - 1)
          : await query.lt('start_at', now).order('start_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => Booking.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<List<Booking>> listBookingsForBarber({required String barberId, required bool upcoming, int limit = 60, int offset = 0}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final query = _client.from('booking_overview').select(_bookingSelect).eq('barber_id', barberId);
      final data = upcoming
          ? await query.gte('start_at', now).order('start_at', ascending: true).range(offset, offset + limit - 1)
          : await query.lt('start_at', now).order('start_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => Booking.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load bookings', cause: e);
    }
  }

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
    return _createBookingInternal(
      serviceId: serviceId,
      startAt: startAt,
      barberId: barberId,
      shopId: shopId,
      holdId: holdId,
      sourcePostId: sourcePostId,
      source: source,
      reelId: reelId,
      offerId: offerId,
      discountAmount: discountAmount,
      paymentMethod: paymentMethod,
      retryOnHoldFailure: true,
    );
  }

  Future<Booking> _createBookingInternal({
    required String serviceId,
    required DateTime startAt,
    required String barberId,
    String? shopId,
    String? holdId,
    String? sourcePostId,
    String? source,
    String? reelId,
    String? offerId,
    required double discountAmount,
    required String paymentMethod,
    required bool retryOnHoldFailure,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    final normalizedShopId = (shopId ?? '').trim().isEmpty ? null : shopId?.trim();
    final normalizedSourcePostId = (sourcePostId ?? '').trim().isEmpty ? null : sourcePostId?.trim();
    final normalizedSource = (source ?? '').trim().isEmpty ? 'mobile_app' : source!.trim();
    final normalizedReelId = (reelId ?? '').trim().isEmpty ? null : reelId?.trim();
    final normalizedOfferId = (offerId ?? '').trim().isEmpty ? null : offerId?.trim();
    final startAtIso = startAt.toUtc().toIso8601String();
    final hold = (holdId ?? '').trim();
    final normalizedPaymentMethod = paymentMethod.trim().isEmpty ? 'cash' : paymentMethod.trim();
    final normalizedDiscount = discountAmount.isFinite && discountAmount > 0 ? discountAmount : 0.0;
    try {
      final params = {
        'service_id': serviceId,
        'start_at': startAtIso,
        'barber_id': barberId,
        'shop_id': normalizedShopId,
        'notes': null,
        'payment_method': normalizedPaymentMethod,
        'source_post_id': normalizedSourcePostId,
        'source': normalizedSource,
        'reel_id': normalizedReelId,
        'offer_id': normalizedOfferId,
        'discount_amount': normalizedDiscount,
        'hold_id': hold.isNotEmpty ? hold : null,
      };
      final data = await _client.rpc('create_booking_safely', params: params);
      final result = Map<String, dynamic>.from(data as Map);
      final ok = result['ok'] == true;
      if (!ok) {
        final errorMessage = ((result['error'] as String?) ?? '').trim();
        throw AppException(errorMessage.isEmpty ? 'Failed to create booking' : errorMessage);
      }
      final bookingData = result['booking'];
      if (bookingData is! Map) throw const AppException('Failed to create booking');
      return Booking.fromJson(Map<String, dynamic>.from(bookingData));
    } catch (e) {
      _logFailure('create_booking_failed', e, meta: {
        'service_id': serviceId,
        'barber_id': barberId,
        'shop_id': normalizedShopId,
        'hold_id': hold,
        'source_post_id': normalizedSourcePostId,
        'source': normalizedSource,
        'reel_id': normalizedReelId,
        'offer_id': normalizedOfferId,
        'discount_amount': normalizedDiscount,
      });
      if (e is PostgrestException) {
        if (kDebugMode) {
          debugPrint(
            '[BookingRepository/createBooking] ${e.code ?? ''} ${e.message} details=${e.details ?? ''} hint=${e.hint ?? ''}',
          );
        }
        final msg = (e.message).toLowerCase();
        final isHoldFailure = msg.contains('hold_not_found') || msg.contains('hold_mismatch');
        if (hold.isNotEmpty && retryOnHoldFailure && isHoldFailure) {
          final recovered = await _recoverActiveHold(
            userId: user.id,
            serviceId: serviceId,
            barberId: barberId,
            startAtIso: startAtIso,
            shopId: normalizedShopId,
          );
          if (recovered != null && recovered.holdId != hold) {
            return _createBookingInternal(
              serviceId: serviceId,
              startAt: startAt,
              barberId: barberId,
              shopId: normalizedShopId,
              holdId: recovered.holdId,
              sourcePostId: normalizedSourcePostId,
              source: normalizedSource,
              reelId: normalizedReelId,
              offerId: normalizedOfferId,
              discountAmount: normalizedDiscount,
              paymentMethod: normalizedPaymentMethod,
              retryOnHoldFailure: false,
            );
          }

          final refreshedHold = await holdBookingSlot(
            serviceId: serviceId,
            startAt: startAt,
            barberId: barberId,
            shopId: normalizedShopId,
          );
          final refreshedHoldId = refreshedHold.holdId.trim();
          if (refreshedHoldId.isNotEmpty) {
            return _createBookingInternal(
              serviceId: serviceId,
              startAt: startAt,
              barberId: barberId,
              shopId: normalizedShopId,
              holdId: refreshedHoldId,
              sourcePostId: normalizedSourcePostId,
              source: normalizedSource,
              reelId: normalizedReelId,
              offerId: normalizedOfferId,
              discountAmount: normalizedDiscount,
              paymentMethod: normalizedPaymentMethod,
              retryOnHoldFailure: false,
            );
          }
        }

        if (msg.contains('payment_method_not_supported')) {
          throw AppException('This payment method is coming soon. Please choose Cash at Shop.', cause: e);
        }
        if (msg.contains('slot_held')) {
          throw AppException('This time is being held by another customer. Please select another time.', cause: e);
        }
        if (isHoldFailure) {
          throw AppException('Your reservation expired. Please select the time again.', cause: e);
        }
        if (msg.contains('booking_overlap') || msg.contains('bookings_no_overlap_per_barber') || msg.contains('exclude')) {
          throw AppException('This time is no longer available. Please select another time.', cause: e);
        }
        if (msg.contains('barber_time_off')) {
          throw AppException('Barber is not available at this time. Please select another time.', cause: e);
        }
        if (msg.contains('barber_inactive')) {
          throw AppException('This barber is not available right now. Please choose another barber.', cause: e);
        }
        if (msg.contains('shop_inactive') || msg.contains('invalid_shop')) {
          throw AppException('This shop is not available right now. Please choose another shop.', cause: e);
        }
        if (msg.contains('service_inactive') || msg.contains('service_not_found') || msg.contains('service_not_for_barber') || msg.contains('service_not_for_shop')) {
          throw AppException('Selected service is not available. Please choose another service.', cause: e);
        }
      }
      throw AppException('Failed to create booking', cause: e);
    }
  }

  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _client.rpc('cancel_booking', params: {'booking_id': bookingId, 'reason': (reason ?? '').trim().isEmpty ? null : reason});
    } catch (e) {
      _logFailure('cancel_booking_failed', e, meta: {
        'booking_id': bookingId,
      });
      if (e is PostgrestException) {
        final msg = (e.message).toLowerCase();
        if (msg.contains('too_late_to_cancel')) {
          throw AppException('This booking can no longer be cancelled.', cause: e);
        }
        if (msg.contains('forbidden')) {
          throw AppException('Permission denied.', cause: e);
        }
        if (msg.contains('booking_not_found')) {
          throw AppException('Booking not found.', cause: e);
        }
      }
      throw AppException('Failed to cancel booking', cause: e);
    }
  }

  Future<Booking> rescheduleBooking({
    required String bookingId,
    required DateTime newStartAt,
  }) async {
    try {
      final data = await _client.rpc(
        'reschedule_booking',
        params: {
          'booking_id': bookingId,
          'new_start_at': newStartAt.toUtc().toIso8601String(),
        },
      );
      final Map<String, dynamic> m;
      if (data is List) {
        if (data.isEmpty) throw const AppException('Failed to reschedule booking');
        m = Map<String, dynamic>.from(data.first as Map);
      } else {
        m = Map<String, dynamic>.from(data as Map);
      }
      return Booking.fromJson(m);
    } catch (e) {
      _logFailure('reschedule_booking_failed', e, meta: {
        'booking_id': bookingId,
      });
      if (e is PostgrestException) {
        final msg = (e.message).toLowerCase();
        if (msg.contains('booking_overlap')) {
          throw AppException('This time is no longer available. Please select another time.', cause: e);
        }
        if (msg.contains('barber_time_off')) {
          throw AppException('Barber is not available at this time. Please select another time.', cause: e);
        }
        if (msg.contains('too_late_to_reschedule')) {
          throw AppException('This booking can no longer be rescheduled.', cause: e);
        }
      }
      throw AppException('Failed to reschedule booking', cause: e);
    }
  }


  Future<void> updateBookingStatus({required String bookingId, required String status, String? cancelReason}) async {
    if (!['pending', 'confirmed', 'in_progress', 'rescheduled', 'no_show', 'cancelled', 'completed'].contains(status)) {
      throw const AppException('Invalid status');
    }
    try {
      switch (status) {
        case 'cancelled':
          await cancelBooking(bookingId, reason: cancelReason);
          return;
        case 'confirmed':
          await _client.rpc('confirm_booking', params: {'booking_id': bookingId});
          return;
        case 'in_progress':
          await _client.rpc('start_booking', params: {'booking_id': bookingId});
          return;
        case 'completed':
          await _client.rpc('complete_booking', params: {'booking_id': bookingId});
          return;
        case 'no_show':
          await _client.rpc('mark_booking_no_show', params: {'booking_id': bookingId});
          return;
        case 'pending':
        case 'rescheduled':
          throw const AppException('Unsupported manual status change');
      }
    } catch (e) {
      _logFailure('update_booking_status_failed', e, meta: {
        'booking_id': bookingId,
        'status': status,
      });
      throw AppException('Failed to update booking', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listBookingsForBarberDetailed({
    required String barberId,
    String? status,
    DateTime? from,
    DateTime? to,
    int limit = 80,
  }) async {
    final cacheKey = 'barber_bookings_${barberId}_${(status ?? 'all').trim()}';
    try {
      var q = _client.from('bookings').select(
            'id, start_at, end_at, status, total_price, currency, customer_profile_id, service_id',
          ).eq('barber_id', barberId);
      final status0 = status?.trim();
      if (status0 != null && status0.isNotEmpty) q = q.eq('status', status0);
      if (from != null) q = q.gte('start_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lt('start_at', to.toUtc().toIso8601String());

      final isUpcoming = (status == 'pending' || status == 'confirmed' || status == 'in_progress' || status == 'rescheduled');
      final data = await q.order('start_at', ascending: isUpcoming).limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
      }
      try {
        await _kv.write(cacheKey, jsonEncode(rows));
      } catch (_) {}
      return rows;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> listBookingsForBarberDetailedMulti({
    required String barberId,
    List<String>? statuses,
    DateTime? from,
    DateTime? to,
    int limit = 80,
    bool ascending = false,
  }) async {
    final statuses0 = (statuses ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    final cacheKey = 'barber_bookings_multi_${barberId}_${statuses0.join('-')}_${from?.toUtc().toIso8601String() ?? ''}_${to?.toUtc().toIso8601String() ?? ''}_${limit}_${ascending ? 'asc' : 'desc'}';
    try {
      var q = _client.from('bookings').select(
            'id, start_at, end_at, status, total_price, currency, customer_profile_id, service_id, duration_minutes, shop_id, barbershops(name, phone, whatsapp, owner_profile_id), cancel_reason, cancelled_at, cancelled_by_profile_id, rescheduled_at, rescheduled_by_profile_id',
          ).eq('barber_id', barberId);
      if (statuses0.isNotEmpty) {
        if (statuses0.length == 1) {
          q = q.eq('status', statuses0.first);
        } else {
          q = q.inFilter('status', statuses0);
        }
      }
      if (from != null) q = q.gte('start_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lt('start_at', to.toUtc().toIso8601String());
      final data = await q.order('start_at', ascending: ascending).limit(limit);
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final profiles = await _profilesByIds(rows.map((e) => e['customer_profile_id'] as String?));
      final services = await _servicesByIds(rows.map((e) => e['service_id'] as String?));
      for (final r in rows) {
        final profileId = (r['customer_profile_id'] as String?)?.trim();
        final serviceId = (r['service_id'] as String?)?.trim();
        r['profiles'] = profileId == null ? null : profiles[profileId];
        r['services'] = serviceId == null ? null : services[serviceId];
      }
      try {
        await _kv.write(cacheKey, jsonEncode(rows));
      } catch (_) {}
      return rows;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load bookings', cause: e);
    }
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BookingRepository(client, ref.watch(kvStoreProvider), ref.watch(systemLogsRepositoryProvider));
});

final myUpcomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  return ref.watch(bookingRepositoryProvider).listMyBookings(upcoming: true);
});

final myPastBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  return ref.watch(bookingRepositoryProvider).listMyBookings(upcoming: false);
});

final myLastCompletedBookingForBarberProvider = FutureProvider.family<Booking?, String>((ref, barberId) async {
  return ref.watch(bookingRepositoryProvider).getMyLastCompletedBookingForBarber(barberId);
});

final myBarberUpcomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(bookingRepositoryProvider).listBookingsForBarber(barberId: barber.id, upcoming: true);
});

final myBarberBookingsDetailedByStatusProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(bookingRepositoryProvider).listBookingsForBarberDetailed(barberId: barber.id, status: status);
});

final myBarberUpcomingBookingsDetailedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref
      .watch(bookingRepositoryProvider)
      .listBookingsForBarberDetailedMulti(
        barberId: barber.id,
        statuses: const ['pending', 'confirmed', 'in_progress', 'rescheduled'],
        from: DateTime.now().subtract(const Duration(hours: 6)),
        ascending: true,
      );
});

final myBarberCompletedBookingsDetailedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(bookingRepositoryProvider).listBookingsForBarberDetailedMulti(barberId: barber.id, statuses: const ['completed'], ascending: false);
});

final myBarberCancelledBookingsDetailedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(bookingRepositoryProvider).listBookingsForBarberDetailedMulti(barberId: barber.id, statuses: const ['cancelled', 'no_show'], ascending: false);
});

final myBarberAllBookingsDetailedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref
      .watch(bookingRepositoryProvider)
      .listBookingsForBarberDetailedMulti(
        barberId: barber.id,
        statuses: const ['pending', 'confirmed', 'in_progress', 'rescheduled', 'completed', 'cancelled', 'no_show'],
        ascending: false,
      );
});
