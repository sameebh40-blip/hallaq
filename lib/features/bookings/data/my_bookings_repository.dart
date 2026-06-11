import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/booking.dart';
import '../../../core/network/network_status.dart';
import '../../../core/network/resilient_request.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../models/my_booking_card.dart';

class MyBookingsRepository {
  final SupabaseClient _client;
  final KvStore _kv;
  final bool _isOnline;

  MyBookingsRepository(this._client, this._kv, this._isOnline);

  static const _cacheTtlMs = 1000 * 60 * 30;

  String _cacheKey(String name, {Map<String, Object?> params = const {}}) {
    final b = StringBuffer('cache:$name');
    for (final e in params.entries) {
      b.write(':${e.key}=${e.value ?? ''}');
    }
    return b.toString();
  }

  Future<void> _writeCache(String key, Object value) async {
    final payload = <String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'v': value,
    };
    await _kv.write(key, jsonEncode(payload));
  }

  Future<List?> _readCacheList(String key) async {
    final raw = await _kv.read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final t = decoded['t'];
      final v = decoded['v'];
      if (t is! num) return null;
      if (DateTime.now().millisecondsSinceEpoch - t.toInt() > _cacheTtlMs) return null;
      if (v is! List) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<List<MyBookingCard>> listMyRecentBookings({int limit = 3}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final cacheKey = _cacheKey('my_recent_bookings', params: {'u': user.id, 'limit': limit});
    if (!_isOnline) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        return list.map(_mapRow).toList(growable: false);
      }
      throw const AppException('Offline mode');
    }
    try {
      final data = await resilientRequest(
        () => _client
            .from('bookings')
            .select(
              'id, customer_profile_id, barber_id, shop_id, service_id, start_at, end_at, status, payment_method, total_price, created_at, updated_at, '
              'cancelled_at, cancelled_by_profile_id, rescheduled_at, rescheduled_by_profile_id, '
              'services(name_en, name_ar), '
              'barbers(profile_id, display_name, avatar_url, is_verified, badge_verified, area, address, lat, lng), '
              'barbershops(owner_profile_id, name, area, address, lat, lng, google_maps_url, phone, whatsapp), '
              'payments(provider, status, purpose, created_at)',
            )
            .eq('customer_profile_id', user.id)
            .order('start_at', ascending: false)
            .limit(limit),
      );
      await _writeCache(cacheKey, data);
      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      return list.map(_mapRow).toList(growable: false);
    } catch (e) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        return list.map(_mapRow).toList(growable: false);
      }
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  Future<List<MyBookingCard>> listMyBookings({
    required BookingsTab tab,
    required int limit,
    DateTime? cursorStartAt,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final cacheKey = _cacheKey(
      'my_bookings',
      params: {
        'u': user.id,
        'tab': tab.name,
        'limit': limit,
      },
    );
    if (!_isOnline && cursorStartAt == null) {
      final cached = await _readCacheList(cacheKey);
      if (cached != null) {
        final list = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        return list.map(_mapRow).toList(growable: false);
      }
      throw const AppException('Offline mode');
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final needsClientFilter = tab == BookingsTab.autoAccepted || tab == BookingsTab.cancelledByBarber || tab == BookingsTab.cancelledByShop || tab == BookingsTab.cancelledByClient;
      final fetchLimit = needsClientFilter ? (limit * 3).clamp(limit, 120) : limit;
      dynamic q = _client
          .from('bookings')
          .select(
            'id, customer_profile_id, barber_id, shop_id, service_id, start_at, end_at, status, payment_method, total_price, created_at, updated_at, '
            'cancelled_at, cancelled_by_profile_id, rescheduled_at, rescheduled_by_profile_id, '
            'services(name_en, name_ar), '
            'barbers(profile_id, display_name, avatar_url, is_verified, badge_verified, area, address, lat, lng), '
            'barbershops(owner_profile_id, name, area, address, lat, lng, google_maps_url, phone, whatsapp), '
            'payments(provider, status, purpose, created_at)',
          )
          .eq('customer_profile_id', user.id);

      q = switch (tab) {
        BookingsTab.upcoming =>
          q.inFilter('status', ['pending', 'confirmed', 'accepted', 'in_progress', 'rescheduled']).gte('start_at', nowIso).order('start_at', ascending: true),
        BookingsTab.pending => q.eq('status', 'pending').gte('start_at', nowIso).order('start_at', ascending: true),
        BookingsTab.autoAccepted => q.eq('status', 'confirmed').gte('start_at', nowIso).order('start_at', ascending: true),
        BookingsTab.rescheduled =>
          q.not('rescheduled_at', 'is', null).order('rescheduled_at', ascending: false).order('start_at', ascending: false),
        BookingsTab.completed => q.eq('status', 'completed').order('start_at', ascending: false),
        BookingsTab.cancelled => q.inFilter('status', ['cancelled', 'rejected', 'no_show']).order('start_at', ascending: false),
        BookingsTab.cancelledByBarber => q.inFilter('status', ['cancelled', 'rejected']).order('start_at', ascending: false),
        BookingsTab.cancelledByShop => q.inFilter('status', ['cancelled', 'rejected']).order('start_at', ascending: false),
        BookingsTab.cancelledByClient => q.inFilter('status', ['cancelled', 'rejected']).order('start_at', ascending: false),
      };

      if (cursorStartAt != null) {
        final cursorIso = cursorStartAt.toUtc().toIso8601String();
        if (tab == BookingsTab.upcoming || tab == BookingsTab.pending || tab == BookingsTab.autoAccepted) {
          q = q.gt('start_at', cursorIso);
        } else {
          q = q.lt('start_at', cursorIso);
        }
      }

      final data = await resilientRequest(() => q.limit(fetchLimit));
      if (cursorStartAt == null) await _writeCache(cacheKey, data);
      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      final mapped = list.map(_mapRow).toList(growable: false);
      if (!needsClientFilter) return mapped;

      final filtered = switch (tab) {
        BookingsTab.autoAccepted => mapped.where((e) => e.autoAccepted).toList(growable: false),
        BookingsTab.cancelledByBarber => mapped.where((e) => e.status == BookingStatus.cancelled && e.cancelOrigin == BookingCancelOrigin.barber).toList(growable: false),
        BookingsTab.cancelledByShop => mapped.where((e) => e.status == BookingStatus.cancelled && e.cancelOrigin == BookingCancelOrigin.shop).toList(growable: false),
        BookingsTab.cancelledByClient => mapped.where((e) => e.status == BookingStatus.cancelled && e.cancelOrigin == BookingCancelOrigin.client).toList(growable: false),
        _ => mapped,
      };
      return filtered.take(limit).toList(growable: false);
    } catch (e) {
      if (cursorStartAt == null) {
        final cached = await _readCacheList(cacheKey);
        if (cached != null) {
          final list = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
          return list.map(_mapRow).toList(growable: false);
        }
      }
      throw AppException('Failed to load bookings', cause: e);
    }
  }

  MyBookingCard _mapRow(Map<String, dynamic> row) {
    final barber = row['barbers'] is Map ? Map<String, dynamic>.from(row['barbers'] as Map) : null;
    final shop = row['barbershops'] is Map ? Map<String, dynamic>.from(row['barbershops'] as Map) : null;
    final service = row['services'] is Map ? Map<String, dynamic>.from(row['services'] as Map) : null;

    final payments0 = row['payments'];
    final payments = payments0 is List ? payments0.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false) : const <Map<String, dynamic>>[];
    final method = _paymentLabelFromPayments(payments) ?? _paymentLabelFromBookingMethod(row['payment_method'] as String?);

    final shopArea = (shop?['area'] as String?)?.trim();
    final barberArea = (barber?['area'] as String?)?.trim();
    final shopAddress = (shop?['address'] as String?)?.trim();
    final barberAddress = (barber?['address'] as String?)?.trim();
    final location = [
      if (shopArea != null && shopArea.isNotEmpty) shopArea,
      if ((shopArea == null || shopArea.isEmpty) && shopAddress != null && shopAddress.isNotEmpty) shopAddress,
      if (shop == null && barberArea != null && barberArea.isNotEmpty) barberArea,
      if (shop == null && (barberArea == null || barberArea.isEmpty) && barberAddress != null && barberAddress.isNotEmpty) barberAddress,
    ].firstOrNull;

    final lat = (shop?['lat'] as num?)?.toDouble() ?? (barber?['lat'] as num?)?.toDouble();
    final lng = (shop?['lng'] as num?)?.toDouble() ?? (barber?['lng'] as num?)?.toDouble();
    final verified = ((barber?['is_verified'] as bool?) ?? false) || ((barber?['badge_verified'] as bool?) ?? false);

    final createdAt = DateTime.tryParse((row['created_at'] as String?) ?? '');
    final updatedAt = DateTime.tryParse((row['updated_at'] as String?) ?? '');
    final cancelledAt = DateTime.tryParse((row['cancelled_at'] as String?) ?? '');
    final rescheduledAt = DateTime.tryParse((row['rescheduled_at'] as String?) ?? '');
    final cancelledBy = row['cancelled_by_profile_id'] as String?;
    final rescheduledBy = row['rescheduled_by_profile_id'] as String?;
    final customerId = row['customer_profile_id'] as String?;
    final barberProfileId = barber?['profile_id'] as String?;
    final shopOwnerProfileId = shop?['owner_profile_id'] as String?;
    final status = BookingStatus.fromDb(row['status'] as String?);
    final autoAccepted = status == BookingStatus.confirmed &&
        createdAt != null &&
        updatedAt != null &&
        (updatedAt.difference(createdAt).inSeconds).abs() <= 6 &&
        rescheduledAt == null &&
        cancelledAt == null;
    final cancelOrigin = status != BookingStatus.cancelled
        ? BookingCancelOrigin.unknown
        : cancelledBy == null
            ? BookingCancelOrigin.unknown
            : cancelledBy == customerId
                ? BookingCancelOrigin.client
                : cancelledBy == barberProfileId
                    ? BookingCancelOrigin.barber
                    : cancelledBy == shopOwnerProfileId
                        ? BookingCancelOrigin.shop
                        : BookingCancelOrigin.unknown;

    return MyBookingCard(
      id: row['id'] as String,
      barberId: row['barber_id'] as String?,
      shopId: row['shop_id'] as String?,
      serviceId: row['service_id'] as String?,
      startAt: DateTime.parse(row['start_at'] as String),
      endAt: DateTime.parse(row['end_at'] as String),
      status: status,
      createdAt: createdAt,
      cancelledAt: cancelledAt,
      cancelledByProfileId: cancelledBy,
      rescheduledAt: rescheduledAt,
      rescheduledByProfileId: rescheduledBy,
      cancelOrigin: cancelOrigin,
      autoAccepted: autoAccepted,
      amountBhd: (row['total_price'] as num?)?.toDouble(),
      serviceNameEn: service?['name_en'] as String?,
      serviceNameAr: service?['name_ar'] as String?,
      barberName: (barber?['display_name'] as String?)?.trim(),
      barberAvatarUrl: (barber?['avatar_url'] as String?)?.trim(),
      barberVerified: verified,
      shopName: (shop?['name'] as String?)?.trim(),
      locationText: location,
      lat: lat,
      lng: lng,
      googleMapsUrl: (shop?['google_maps_url'] as String?)?.trim(),
      shopPhone: (shop?['phone'] as String?)?.trim(),
      shopWhatsApp: (shop?['whatsapp'] as String?)?.trim(),
      paymentMethodLabel: method,
    );
  }

  String? _paymentLabelFromBookingMethod(String? method) {
    final v = (method ?? '').trim().toLowerCase();
    return switch (v) {
      'cash' => 'Cash at shop',
      'manual' => 'Cash at shop',
      'cod' => 'Cash at shop',
      'cash_at_shop' => 'Cash at shop',
      'card' => 'Card',
      'benefitpay' => 'BenefitPay',
      'apple_pay' => 'Apple Pay',
      'stc_pay' => 'STC Pay',
      _ => v.isEmpty ? null : v,
    };
  }

  String? _paymentLabelFromPayments(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return null;

    Map<String, dynamic>? pickByPurpose(String purpose) {
      final filtered = payments.where((e) => (e['purpose'] as String?) == purpose).toList(growable: false);
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) => (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));
      return filtered.first;
    }

    final Map<String, dynamic> selected = pickByPurpose('service') ?? pickByPurpose('deposit') ?? payments.first;
    final provider = (selected['provider'] as String?)?.trim().toLowerCase();
    return switch (provider) {
      'benefitpay' => 'BenefitPay',
      'card' => 'Card',
      'manual' => 'Cash at shop',
      'cod' => 'Cash at shop',
      _ => provider?.isEmpty ?? true ? null : provider,
    };
  }
}

final myBookingsRepositoryProvider = Provider<MyBookingsRepository>((ref) {
  return MyBookingsRepository(ref.watch(supabaseClientProvider), ref.watch(kvStoreProvider), ref.watch(networkOnlineProvider));
});

extension _FirstOrNullX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
