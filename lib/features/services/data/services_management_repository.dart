import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/service.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ServicesManagementRepository {
  final SupabaseClient _client;
  final KvStore _kv;

  ServicesManagementRepository(this._client, this._kv);

  Future<List<Service>> listForBarber(String barberId) async {
    final cacheKey = 'barber_services_public_$barberId';
    try {
      final data = await _client
          .from('services')
          .select()
          .eq('barber_id', barberId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('is_popular', ascending: false)
          .order('price_bhd', ascending: true);
      final raw = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      final rows = raw.map(Service.fromJson).toList(growable: false);
      try {
        await _kv.write(cacheKey, jsonEncode(raw));
      } catch (_) {}
      return rows;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => Service.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load services', cause: e);
    }
  }

  Future<List<Service>> listForBarberManage(String barberId) async {
    final cacheKey = 'barber_services_manage_$barberId';
    try {
      final data = await _client
          .from('services')
          .select()
          .eq('barber_id', barberId)
          .isFilter('deleted_at', null)
          .order('is_active', ascending: false)
          .order('is_popular', ascending: false)
          .order('price_bhd', ascending: true);
      final raw = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      final rows = raw.map(Service.fromJson).toList(growable: false);
      try {
        await _kv.write(cacheKey, jsonEncode(raw));
      } catch (_) {}
      return rows;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => Service.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load services', cause: e);
    }
  }

  Future<List<Service>> listForShop(String shopId) async {
    try {
      final data = await _client
          .from('services')
          .select()
          .eq('shop_id', shopId)
          .isFilter('barber_id', null)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('is_popular', ascending: false)
          .order('price_bhd', ascending: true);
      return (data as List).map((e) => Service.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load services', cause: e);
    }
  }

  Future<List<Service>> listForShopManage(String shopId) async {
    try {
      final data = await _client
          .from('services')
          .select()
          .eq('shop_id', shopId)
          .isFilter('barber_id', null)
          .isFilter('deleted_at', null)
          .order('is_active', ascending: false)
          .order('is_popular', ascending: false)
          .order('price_bhd', ascending: true);
      return (data as List).map((e) => Service.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load services', cause: e);
    }
  }

  Future<Service> upsert({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final normalizedPayload = <String, dynamic>{
        ...payload,
        if (!payload.containsKey('status') || payload['status'] == null || '${payload['status']}'.trim().isEmpty) 'status': 'approved',
        if (!payload.containsKey('deleted_at')) 'deleted_at': null,
      };
      final data = await _client.from('services').upsert(normalizedPayload).select().single();
      return Service.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to save service', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('services').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete service', cause: e);
    }
  }

  Future<Set<String>> listAssignedBarbers(String serviceId) async {
    try {
      final data = await _client.from('service_barbers').select('barber_id').eq('service_id', serviceId).limit(5000);
      return (data as List).map((e) => (e as Map)['barber_id'] as String?).whereType<String>().toSet();
    } catch (e) {
      throw AppException('Failed to load service assignments', cause: e);
    }
  }

  Future<void> setAssignedBarbers({
    required String serviceId,
    required Set<String> barberIds,
  }) async {
    try {
      await _client.from('service_barbers').delete().eq('service_id', serviceId);
      if (barberIds.isEmpty) return;
      await _client.from('service_barbers').insert(barberIds.map((b) => {'service_id': serviceId, 'barber_id': b}).toList());
    } catch (e) {
      throw AppException('Failed to update service assignments', cause: e);
    }
  }
}

final servicesManagementRepositoryProvider = Provider<ServicesManagementRepository>((ref) {
  return ServicesManagementRepository(ref.watch(supabaseClientProvider), ref.watch(kvStoreProvider));
});

final myBarberServicesManageProvider = FutureProvider<List<Service>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return const <Service>[];
  final data = await client.from('barbers').select('id').eq('profile_id', user.id).order('created_at', ascending: false).limit(1);
  final list = data as List;
  if (list.isEmpty) return const <Service>[];
  final barberId = (list.first as Map)['id'] as String?;
  if ((barberId ?? '').isEmpty) return const <Service>[];
  return ref.watch(servicesManagementRepositoryProvider).listForBarberManage(barberId!);
});
