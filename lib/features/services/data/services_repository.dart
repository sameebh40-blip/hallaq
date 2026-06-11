import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/service.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ServicesRepository {
  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 10);

  ServicesRepository(this._client);

  List<Service> _sortServices(List<Service> items) {
    final list = items.toList(growable: false);
    list.sort((a, b) {
      if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
      return a.priceBhd.compareTo(b.priceBhd);
    });
    return list;
  }

  Future<List<Service>> listForBarber(String barberId, {int limit = 50, int offset = 0}) async {
    try {
      final data = await _client
          .from('barber_services_effective')
          .select()
          .eq('barber_ref', barberId)
          .eq('status', 'approved')
          .order('is_popular', ascending: false)
          .order('price_bhd', ascending: true)
          .range(offset, offset + limit - 1)
          .timeout(_timeout);
      return (data as List).map((e) => Service.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      try {
        return await _fallbackListForBarber(barberId, limit: limit, offset: offset);
      } catch (e2) {
        throw AppException('Failed to load services', cause: e2);
      }
    }
  }

  Future<List<Service>> listForShop(String shopId, {int limit = 50, int offset = 0}) async {
    try {
      final internalLimit = (offset + limit + 60).clamp(50, 250);
      final shopLevel = await _safeServicesQuery(
        (q) => q.eq('shop_id', shopId).isFilter('barber_id', null),
        limit: internalLimit,
        offset: 0,
      );

      final barberIds = await _listActiveBarberIdsForShop(shopId);
      final barberLevelLists = await Future.wait(
        barberIds.map(
          (barberId) => _safeServicesQuery(
            (q) => q.eq('barber_id', barberId),
            limit: internalLimit,
            offset: 0,
          ),
        ),
      );

      final byId = <String, Service>{};
      for (final service in shopLevel) {
        byId[service.id] = service;
      }
      for (final group in barberLevelLists) {
        for (final service in group) {
          byId[service.id] = service;
        }
      }

      final merged = _sortServices(byId.values.toList(growable: false));
      final start = offset.clamp(0, merged.length);
      final end = (start + limit).clamp(0, merged.length);
      return merged.sublist(start, end);
    } catch (e) {
      throw AppException('Failed to load services', cause: e);
    }
  }

  Future<List<String>> _listActiveBarberIdsForShop(String shopId) async {
    Future<List<String>> run({
      required bool withDeletedAt,
      required bool withStatus,
      required bool withIsActive,
    }) async {
      PostgrestFilterBuilder<dynamic> q = _client.from('barbers').select('id') as PostgrestFilterBuilder<dynamic>;
      q = q.eq('shop_id', shopId);
      if (withDeletedAt) q = q.isFilter('deleted_at', null);
      if (withStatus) q = q.eq('status', 'approved');
      if (withIsActive) q = q.eq('is_active', true);
      final data = await q.limit(200).timeout(_timeout);
      return (data as List)
          .map((e) => (e as Map)['id'] as String?)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toList(growable: false);
    }

    try {
      return await run(withDeletedAt: true, withStatus: true, withIsActive: true);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final missingDeletedAt = msg.contains('column') && msg.contains('deleted_at');
      final missingStatus = msg.contains('column') && msg.contains('status');
      final missingIsActive = msg.contains('column') && msg.contains('is_active');
      return run(
        withDeletedAt: !missingDeletedAt,
        withStatus: !missingStatus,
        withIsActive: !missingIsActive,
      );
    }
  }

  Future<List<Service>> _fallbackListForBarber(String barberId, {required int limit, required int offset}) async {
    final barber = await _client.from('barbers').select('shop_id').eq('id', barberId).maybeSingle().timeout(_timeout);
    final shopId = (barber as Map?)?['shop_id'] as String?;

    final internalLimit = (offset + limit + 40).clamp(50, 200);

    final direct = await _safeServicesQuery(
      (q) => q.eq('barber_id', barberId),
      limit: internalLimit,
      offset: 0,
    );

    var shopServices = <Service>[];
    if (shopId != null && shopId.isNotEmpty) {
      shopServices = await _safeServicesQuery(
        (q) => q.eq('shop_id', shopId).isFilter('barber_id', null),
        limit: internalLimit,
        offset: 0,
      );
    }

    if (shopServices.isNotEmpty) {
      final ids = shopServices.map((s) => s.id).toList(growable: false);
      try {
        final mappedRaw =
            await _client.from('service_barbers').select('service_id').eq('barber_id', barberId).limit(500).timeout(_timeout);
        final mapped = (mappedRaw as List)
            .map((e) => (e as Map)['service_id'] as String?)
            .whereType<String>()
            .toSet();

        final anyMappedRaw = await _client.from('service_barbers').select('service_id').inFilter('service_id', ids).limit(2000).timeout(_timeout);
        final anyMapped = (anyMappedRaw as List)
            .map((e) => (e as Map)['service_id'] as String?)
            .whereType<String>()
            .toSet();

        shopServices = shopServices.where((s) => !anyMapped.contains(s.id) || mapped.contains(s.id)).toList(growable: false);
      } catch (_) {}
    }

    final byId = <String, Service>{};
    for (final s in [...direct, ...shopServices]) {
      byId[s.id] = s;
    }
    final list = byId.values.toList(growable: false);
    list.sort((a, b) {
      if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
      return a.priceBhd.compareTo(b.priceBhd);
    });

    final start = offset.clamp(0, list.length);
    final end = (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  Future<List<Service>> _safeServicesQuery(
    PostgrestFilterBuilder<dynamic> Function(PostgrestFilterBuilder<dynamic> q) applyOwnerFilter, {
    required int limit,
    required int offset,
  }) async {
    Future<List<Service>> run({
      required bool withStatus,
      required String activeColumn,
      required bool withDeletedAt,
    }) async {
      PostgrestFilterBuilder<dynamic> q = _client.from('services').select() as PostgrestFilterBuilder<dynamic>;
      q = applyOwnerFilter(q);
      if (withDeletedAt) q = q.isFilter('deleted_at', null);
      q = q.eq(activeColumn, true);
      if (withStatus) q = q.or('status.eq.approved,status.is.null');
      final data = await q.range(offset, offset + limit - 1).timeout(_timeout);
      return _sortServices((data as List).map((e) => Service.fromJson(Map<String, dynamic>.from(e))).toList(growable: false));
    }

    try {
      return await run(withStatus: true, activeColumn: 'is_active', withDeletedAt: true);
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final missingStatus = msg.contains('column') && msg.contains('status');
      final missingIsActive = msg.contains('column') && msg.contains('is_active');
      final missingDeletedAt = msg.contains('column') && msg.contains('deleted_at');

      if (missingDeletedAt) {
        try {
          return await run(withStatus: !missingStatus, activeColumn: missingIsActive ? 'active' : 'is_active', withDeletedAt: false);
        } on PostgrestException {
          return await _safeServicesQueryNoActive(applyOwnerFilter, limit: limit, offset: offset);
        }
      }

      if (missingIsActive) {
        try {
          return await run(withStatus: !missingStatus, activeColumn: 'active', withDeletedAt: true);
        } on PostgrestException catch (e2) {
          final msg2 = (e2.message).toLowerCase();
          final missingActive = msg2.contains('column') && msg2.contains('active');
          if (missingActive) {
            return await _safeServicesQueryNoActive(applyOwnerFilter, limit: limit, offset: offset);
          }
          rethrow;
        }
      }

      if (missingStatus) {
        try {
          return await run(withStatus: false, activeColumn: 'is_active', withDeletedAt: true);
        } on PostgrestException catch (e2) {
          final msg2 = (e2.message).toLowerCase();
          final missingDeletedAt2 = msg2.contains('column') && msg2.contains('deleted_at');
          if (missingDeletedAt2) {
            return await run(withStatus: false, activeColumn: 'is_active', withDeletedAt: false);
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<List<Service>> _safeServicesQueryNoActive(
    PostgrestFilterBuilder<dynamic> Function(PostgrestFilterBuilder<dynamic> q) applyOwnerFilter, {
    required int limit,
    required int offset,
  }) async {
    Future<List<Service>> run({required bool withStatus}) async {
      PostgrestFilterBuilder<dynamic> q = _client.from('services').select() as PostgrestFilterBuilder<dynamic>;
      q = applyOwnerFilter(q);
      try {
        q = q.isFilter('deleted_at', null);
      } on PostgrestException {
        q = q;
      }
      if (withStatus) q = q.or('status.eq.approved,status.is.null');
      final data = await q.range(offset, offset + limit - 1).timeout(_timeout);
      return _sortServices((data as List).map((e) => Service.fromJson(Map<String, dynamic>.from(e))).toList(growable: false));
    }

    try {
      return await run(withStatus: true);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final missingStatus = msg.contains('column') && msg.contains('status');
      if (missingStatus) return await run(withStatus: false);
      rethrow;
    }
  }
}

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ServicesRepository(client);
});

final barberServicesProvider = FutureProvider.family<List<Service>, String>((ref, barberId) async {
  return ref.watch(servicesRepositoryProvider).listForBarber(barberId);
});

final shopServicesProvider = FutureProvider.family<List<Service>, String>((ref, shopId) async {
  return ref.watch(servicesRepositoryProvider).listForShop(shopId);
});
