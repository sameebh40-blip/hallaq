import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barber.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class BarberRepository {
  final SupabaseClient _client;
  final MediaService _media;

  BarberRepository(this._client, this._media);

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static const _barberCardSelect =
      'id, profile_id, slug, display_name, area, address, lat, lng, avatar_url, avatar_path, cover_url, cover_path, rating_avg, rating_count, followers_count, reviews_count, is_independent, home_service, available_now, waiting_time_min, queue_length, is_verified, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, starting_price_bhd, distance_km, status, created_at, shop_id';

  Future<Barber> _withSignedMedia(Barber b) async {
    final avatar = await _media.resolveMediaUrl(bucket: 'barber-images', path: b.avatarPath, legacyUrlOrPath: b.avatarUrl);
    final cover = await _media.resolveMediaUrl(bucket: 'barber-images', path: b.coverPath, legacyUrlOrPath: b.coverUrl);
    return b.copyWith(avatarUrl: avatar, coverUrl: cover);
  }

  Future<List<Barber>> getTrending({int limit = 10}) async {
    try {
      final data = await _client
          .from('barbers')
          .select(_barberCardSelect)
          .eq('is_verified', true)
          .eq('status', 'approved')
          .order('rating_avg', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load barbers', cause: e);
    }
  }

  Future<Barber> getByRef(String ref) async {
    try {
      final isUuid = _uuid.hasMatch(ref);
      final query = _client.from('barbers').select();
      final data = isUuid ? await query.eq('id', ref).maybeSingle() : await query.eq('slug', ref).maybeSingle();
      if (data == null) throw const AppException('Barber not available');
      return _withSignedMedia(Barber.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to load barber', cause: e);
    }
  }

  Future<Barber> getById(String id) async {
    try {
      final data = await _client.from('barbers').select().eq('id', id).maybeSingle();
      if (data == null) throw const AppException('Barber not available');
      return _withSignedMedia(Barber.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to load barber', cause: e);
    }
  }

  Future<Barber> getByProfileId(String profileId) async {
    try {
      final data = await _client.from('barbers').select().eq('profile_id', profileId).maybeSingle();
      if (data == null) throw const AppException('Barber not available');
      return _withSignedMedia(Barber.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to load barber', cause: e);
    }
  }

  Future<List<Barber>> listForShop(String shopId, {int limit = 20}) async {
    try {
      Future<List<Barber>> run({
        required bool withDeletedAt,
        required bool withStatus,
        required bool withIsActive,
      }) async {
        PostgrestFilterBuilder<dynamic> q = _client.from('barbers').select() as PostgrestFilterBuilder<dynamic>;
        q = q.eq('shop_id', shopId);
        if (withDeletedAt) q = q.isFilter('deleted_at', null);
        if (withStatus) q = q.eq('status', 'approved');
        if (withIsActive) q = q.eq('is_active', true);
        final data = await q.order('rating_avg', ascending: false).limit(limit);
        final list = (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
        return Future.wait(list.map(_withSignedMedia));
      }

      Future<List<Barber>> safeRun({
        required bool withDeletedAt,
        required bool withStatus,
        required bool withIsActive,
      }) async {
        try {
          return await run(withDeletedAt: withDeletedAt, withStatus: withStatus, withIsActive: withIsActive);
        } on PostgrestException catch (e) {
          final msg = e.message.toLowerCase();
          final missingDeletedAt = msg.contains('column') && msg.contains('deleted_at');
          final missingStatus = msg.contains('column') && msg.contains('status');
          final missingIsActive = msg.contains('column') && msg.contains('is_active');
          return run(
            withDeletedAt: withDeletedAt && !missingDeletedAt,
            withStatus: withStatus && !missingStatus,
            withIsActive: withIsActive && !missingIsActive,
          );
        }
      }

      final activeApproved = await safeRun(withDeletedAt: true, withStatus: true, withIsActive: true);
      if (activeApproved.isNotEmpty) return activeApproved;

      final approved = await safeRun(withDeletedAt: true, withStatus: true, withIsActive: false);
      if (approved.isNotEmpty) return approved;

      return await safeRun(withDeletedAt: true, withStatus: false, withIsActive: false);
    } catch (e) {
      throw AppException('Failed to load barbers', cause: e);
    }
  }

  Future<List<Barber>> listForShopManage(String shopId, {int limit = 60}) async {
    try {
      final data = await _client
          .from('barbers')
          .select()
          .eq('shop_id', shopId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load barbers', cause: e);
    }
  }

  Future<List<Barber>> listUnassignedManage({int limit = 200}) async {
    try {
      final data = await _client
          .from('barbers')
          .select()
          .isFilter('shop_id', null)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      throw AppException('Failed to load barbers', cause: e);
    }
  }

  Future<void> assignToShop({required String barberId, required String shopId}) async {
    try {
      await _client.from('barbers').update({'shop_id': shopId, 'is_independent': false, 'status': 'approved', 'is_active': true}).eq('id', barberId);
    } catch (e) {
      throw AppException('Failed to update barber', cause: e);
    }
  }

  Future<void> removeFromShop({required String barberId}) async {
    try {
      await _client.from('barbers').update({'shop_id': null, 'is_independent': true}).eq('id', barberId);
    } catch (e) {
      throw AppException('Failed to update barber', cause: e);
    }
  }

  Future<Barber?> getMyBarber() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client.from('barbers').select().eq('profile_id', user.id).order('created_at', ascending: false).maybeSingle();
      if (data == null) return null;
      return _withSignedMedia(Barber.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to load barber', cause: e);
    }
  }

  Future<Barber> updateBarber({
    required String barberId,
    String? displayName,
    String? bio,
    String? specialty,
    bool? homeService,
    bool? availableNow,
    bool? isActive,
    int? waitingTimeMin,
    int? queueLength,
    String? avatarUrl,
    String? coverUrl,
    String? avatarPath,
    String? coverPath,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (displayName != null) 'display_name': displayName.trim(),
        if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
        if (specialty != null) 'specialty': specialty.trim().isEmpty ? null : specialty.trim(),
        if (homeService != null) 'home_service': homeService,
        if (availableNow != null) 'available_now': availableNow,
        if (isActive != null) 'is_active': isActive,
        if (waitingTimeMin != null) 'waiting_time_min': waitingTimeMin,
        if (queueLength != null) 'queue_length': queueLength,
        if (avatarUrl != null) 'avatar_url': avatarUrl.trim().isEmpty ? null : avatarUrl.trim(),
        if (coverUrl != null) 'cover_url': coverUrl.trim().isEmpty ? null : coverUrl.trim(),
        if (avatarPath != null) 'avatar_path': avatarPath.trim().isEmpty ? null : avatarPath.trim(),
        if (coverPath != null) 'cover_path': coverPath.trim().isEmpty ? null : coverPath.trim(),
      };
      final data = await _client.from('barbers').update(payload).eq('id', barberId).select().single();
      return _withSignedMedia(Barber.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to update barber', cause: e);
    }
  }
}

final barberRepositoryProvider = Provider<BarberRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BarberRepository(client, ref.watch(mediaServiceProvider));
});

final trendingBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  return ref.watch(barberRepositoryProvider).getTrending();
});

final barbersForShopProvider = FutureProvider.family<List<Barber>, String>((ref, shopId) async {
  return ref.watch(barberRepositoryProvider).listForShop(shopId);
});

final barberByIdProvider = FutureProvider.family<Barber, String>((ref, barberId) async {
  return ref.watch(barberRepositoryProvider).getById(barberId);
});

final myBarberProvider = FutureProvider<Barber?>((ref) async {
  return ref.watch(barberRepositoryProvider).getMyBarber();
});
