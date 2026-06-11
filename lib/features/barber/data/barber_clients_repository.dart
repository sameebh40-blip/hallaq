import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'barber_repository.dart';

class BarberClientSummary {
  final String profileId;
  final String name;
  final String? avatarUrl;
  final String? phone;
  final int totalVisits;
  final DateTime? lastVisitAt;
  final double spentBhd;
  final int noShowCount;
  final String? favoriteServiceId;
  final String? favoriteServiceName;
  final String loyaltyTier;

  const BarberClientSummary({
    required this.profileId,
    required this.name,
    required this.avatarUrl,
    required this.phone,
    required this.totalVisits,
    required this.lastVisitAt,
    required this.spentBhd,
    required this.noShowCount,
    required this.favoriteServiceId,
    required this.favoriteServiceName,
    required this.loyaltyTier,
  });

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'name': name,
      'avatar_url': avatarUrl,
      'phone': phone,
      'total_visits': totalVisits,
      'last_visit_at': lastVisitAt?.toUtc().toIso8601String(),
      'spent_bhd': spentBhd,
      'no_show_count': noShowCount,
      'favorite_service_id': favoriteServiceId,
      'favorite_service_name': favoriteServiceName,
      'loyalty_tier': loyaltyTier,
    };
  }

  factory BarberClientSummary.fromJson(Map<String, dynamic> json) {
    return BarberClientSummary(
      profileId: (json['profile_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      totalVisits: (json['total_visits'] as num?)?.toInt() ?? 0,
      lastVisitAt: (json['last_visit_at'] as String?) == null ? null : DateTime.tryParse(json['last_visit_at'] as String),
      spentBhd: (json['spent_bhd'] as num?)?.toDouble() ?? 0,
      noShowCount: (json['no_show_count'] as num?)?.toInt() ?? 0,
      favoriteServiceId: json['favorite_service_id'] as String?,
      favoriteServiceName: json['favorite_service_name'] as String?,
      loyaltyTier: (json['loyalty_tier'] as String?) ?? 'Regular',
    );
  }
}

class BarberClientsRepository {
  final SupabaseClient _client;
  final KvStore _kv;

  BarberClientsRepository(this._client, this._kv);

  Future<String> upsertNote({required String barberId, required String customerProfileId, required String note}) async {
    final b = barberId.trim();
    final c = customerProfileId.trim();
    if (b.isEmpty || c.isEmpty) return '';
    final data = await _client
        .from('barber_customer_notes')
        .upsert({'barber_id': b, 'customer_profile_id': c, 'note': note.trim()}, onConflict: 'barber_id,customer_profile_id')
        .select('note')
        .single();
    final m = Map<String, dynamic>.from(data as Map);
    return (m['note'] as String?) ?? '';
  }

  Future<String?> getNote({required String barberId, required String customerProfileId}) async {
    final b = barberId.trim();
    final c = customerProfileId.trim();
    if (b.isEmpty || c.isEmpty) return null;
    try {
      final data = await _client.from('barber_customer_notes').select('note').eq('barber_id', b).eq('customer_profile_id', c).limit(1);
      final list = (data as List);
      if (list.isEmpty) return null;
      final m = Map<String, dynamic>.from(list.first as Map);
      return (m['note'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Future<List<BarberClientSummary>> listClients({required String barberId, int limit = 200}) async {
    final cacheKey = 'barber_clients_$barberId';
    try {
      final rows = await _client
          .from('bookings')
          .select('customer_profile_id, start_at, status, currency, total_price, price_bhd, service_id')
          .eq('barber_id', barberId)
          .inFilter('status', const ['pending', 'confirmed', 'in_progress', 'rescheduled', 'completed', 'cancelled', 'no_show'])
          .order('start_at', ascending: false)
          .limit(1200);

      final perCustomer = <String, ({int visits, DateTime? lastAt, double spent, int noShows, Map<String, int> serviceCounts})>{};
      for (final raw in (rows as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final pid = (m['customer_profile_id'] as String?)?.trim();
        if (pid == null || pid.isEmpty) continue;
        final startAt = DateTime.tryParse((m['start_at'] as String?) ?? '');
        final status = (m['status'] as String?) ?? '';
        final currency = (m['currency'] as String?) ?? 'BHD';
        final price = (m['price_bhd'] as num?)?.toDouble() ?? (m['total_price'] as num?)?.toDouble() ?? 0;
        final serviceId = (m['service_id'] as String?)?.trim();

        final current = perCustomer[pid];
        final lastAt = (startAt == null)
            ? (current?.lastAt)
            : current?.lastAt == null
                ? startAt
                : (startAt.isAfter(current!.lastAt!) ? startAt : current.lastAt);
        final visits = (current?.visits ?? 0) + (status == 'completed' ? 1 : 0);
        final spent = (current?.spent ?? 0) + (status == 'completed' && currency == 'BHD' ? price : 0);
        final noShows = (current?.noShows ?? 0) + (status == 'no_show' ? 1 : 0);
        final serviceCounts = Map<String, int>.from(current?.serviceCounts ?? const {});
        if (status == 'completed' && serviceId != null && serviceId.isNotEmpty) {
          serviceCounts[serviceId] = (serviceCounts[serviceId] ?? 0) + 1;
        }
        perCustomer[pid] = (visits: visits, lastAt: lastAt, spent: spent, noShows: noShows, serviceCounts: serviceCounts);
      }

      final ids = perCustomer.keys.toList(growable: false);
      if (ids.isEmpty) return const [];

      final profiles = await _client.from('profiles').select('id, full_name, phone, avatar_url').inFilter('id', ids);
      final profileById = <String, Map<String, dynamic>>{};
      for (final row in (profiles as List)) {
        final p = Map<String, dynamic>.from(row as Map);
        final id = (p['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        profileById[id] = p;
      }

      final favoriteServiceByClient = <String, String>{};
      final favoriteServiceIds = <String>{};
      for (final id in ids) {
        final counts = perCustomer[id]!.serviceCounts;
        if (counts.isEmpty) continue;
        String? bestId;
        var bestCount = -1;
        for (final e in counts.entries) {
          if (e.value > bestCount) {
            bestCount = e.value;
            bestId = e.key;
          }
        }
        if (bestId != null) {
          favoriteServiceByClient[id] = bestId;
          favoriteServiceIds.add(bestId);
        }
      }

      final serviceNameById = <String, String>{};
      if (favoriteServiceIds.isNotEmpty) {
        try {
          final data = await _client.from('services').select('id, name, name_en, name_ar').inFilter('id', favoriteServiceIds.toList(growable: false));
          for (final row in (data as List)) {
            final m = Map<String, dynamic>.from(row as Map);
            final id = (m['id'] as String?)?.trim();
            if (id == null || id.isEmpty) continue;
            final nameEn = (m['name_en'] as String?)?.trim();
            final name = (nameEn == null || nameEn.isEmpty) ? (m['name'] as String?)?.trim() : nameEn;
            if (name != null && name.isNotEmpty) serviceNameById[id] = name;
          }
        } catch (_) {}
      }

      final out = <BarberClientSummary>[];
      for (final id in ids) {
        final stats = perCustomer[id]!;
        final p = profileById[id];
        final name = (p?['full_name'] as String?)?.trim();
        final tier = (stats.visits <= 1)
            ? 'New'
            : (stats.visits >= 5 || stats.spent >= 80)
                ? 'VIP'
                : 'Regular';
        final favServiceId = favoriteServiceByClient[id];
        out.add(
          BarberClientSummary(
            profileId: id,
            name: (name == null || name.isEmpty) ? 'Customer' : name,
            avatarUrl: p?['avatar_url'] as String?,
            phone: p?['phone'] as String?,
            totalVisits: stats.visits,
            lastVisitAt: stats.lastAt,
            spentBhd: stats.spent,
            noShowCount: stats.noShows,
            favoriteServiceId: favServiceId,
            favoriteServiceName: favServiceId == null ? null : serviceNameById[favServiceId],
            loyaltyTier: tier,
          ),
        );
      }

      out.sort((a, b) {
        final av = a.lastVisitAt?.millisecondsSinceEpoch ?? 0;
        final bv = b.lastVisitAt?.millisecondsSinceEpoch ?? 0;
        return bv.compareTo(av);
      });

      final limited = out.take(limit).toList(growable: false);
      try {
        await _kv.write(cacheKey, jsonEncode(limited.map((e) => e.toJson()).toList()));
      } catch (_) {}
      return limited;
    } catch (e) {
      try {
        final cached = await _kv.read(cacheKey);
        if (cached != null && cached.trim().isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.map((e) => BarberClientSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (_) {}
      throw AppException('Failed to load clients', cause: e);
    }
  }
}

final barberClientsRepositoryProvider = Provider<BarberClientsRepository>((ref) {
  return BarberClientsRepository(ref.watch(supabaseClientProvider), ref.watch(kvStoreProvider));
});

final myBarberClientsProvider = FutureProvider<List<BarberClientSummary>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberClientsRepositoryProvider).listClients(barberId: barber.id);
});
