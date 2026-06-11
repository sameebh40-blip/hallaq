import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class SavedReelCard {
  final String id;
  final String? thumbnailUrl;
  final String? caption;

  const SavedReelCard({required this.id, this.thumbnailUrl, this.caption});
}

class SavedItemsRepository {
  final SupabaseClient _client;
  final MediaService _media;

  SavedItemsRepository(this._client, this._media);

  Future<Barber> _withSignedBarber(Barber b) async {
    final avatar = await _media.resolveMediaUrl(bucket: 'barber-images', path: b.avatarPath, legacyUrlOrPath: b.avatarUrl);
    final cover = await _media.resolveMediaUrl(bucket: 'barber-images', path: b.coverPath, legacyUrlOrPath: b.coverUrl);
    return b.copyWith(avatarUrl: avatar, coverUrl: cover);
  }

  Future<Barbershop> _withSignedShop(Barbershop s) async {
    final cover = await _media.resolveMediaUrl(bucket: 'shop-images', path: s.coverPath, legacyUrlOrPath: s.coverUrl);
    final logo = await _media.resolveMediaUrl(bucket: 'shop-images', path: s.logoPath, legacyUrlOrPath: s.logoUrl);
    return s.copyWith(coverUrl: cover, logoUrl: logo);
  }

  Future<void> remove({required String itemType, required String itemId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('saved_items').delete().eq('user_id', user.id).eq('item_type', itemType).eq('item_id', itemId);
    } catch (e) {
      throw AppException('Failed to remove saved item', cause: e);
    }
  }

  Future<List<Barber>> listSavedBarbers({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('saved_items')
          .select('item_id, created_at')
          .eq('user_id', user.id)
          .eq('item_type', 'barber')
          .order('created_at', ascending: false)
          .limit(limit);

      final ids = (rows as List).map((e) => (e['item_id'] as String?) ?? '').where((e) => e.isNotEmpty).toList(growable: false);
      if (ids.isEmpty) return const [];

      final data = await _client.from('barbers').select().inFilter('id', ids);
      final byId = <String, Barber>{};
      for (final row in (data as List)) {
        final b = Barber.fromJson(Map<String, dynamic>.from(row as Map));
        byId[b.id] = b;
      }

      final ordered = ids.map((id) => byId[id]).whereType<Barber>().toList(growable: false);
      return Future.wait(ordered.map(_withSignedBarber));
    } catch (e) {
      throw AppException('Failed to load saved items', cause: e);
    }
  }

  Future<List<Barbershop>> listSavedShops({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('saved_items')
          .select('item_id, created_at')
          .eq('user_id', user.id)
          .eq('item_type', 'shop')
          .order('created_at', ascending: false)
          .limit(limit);

      final ids = (rows as List).map((e) => (e['item_id'] as String?) ?? '').where((e) => e.isNotEmpty).toList(growable: false);
      if (ids.isEmpty) return const [];

      final data = await _client.from('barbershops').select().inFilter('id', ids);
      final byId = <String, Barbershop>{};
      for (final row in (data as List)) {
        final s = Barbershop.fromJson(Map<String, dynamic>.from(row as Map));
        byId[s.id] = s;
      }

      final ordered = ids.map((id) => byId[id]).whereType<Barbershop>().toList(growable: false);
      return Future.wait(ordered.map(_withSignedShop));
    } catch (e) {
      throw AppException('Failed to load saved items', cause: e);
    }
  }

  Future<List<SavedReelCard>> listSavedReels({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('saved_items')
          .select('item_id, created_at')
          .eq('user_id', user.id)
          .eq('item_type', 'reel')
          .order('created_at', ascending: false)
          .limit(limit);

      final ids = (rows as List).map((e) => (e['item_id'] as String?) ?? '').where((e) => e.isNotEmpty).toList(growable: false);
      if (ids.isEmpty) return const [];

      List<Map<String, dynamic>> details = const [];
      try {
        final data = await _client.from('posts').select('id, thumbnail_url, thumbnail_path, caption').inFilter('id', ids);
        details = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      } catch (_) {
        final data = await _client.from('reels').select('id, thumbnail_url, thumbnail_path, caption').inFilter('id', ids);
        details = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final m in details) {
        final id = (m['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        byId[id] = m;
      }

      final out = <SavedReelCard>[];
      for (final id in ids) {
        final m = byId[id];
        if (m == null) continue;
        final thumb = await _media.resolveMediaUrlMulti(
          buckets: const ['reels', 'reels-media'],
          path: m['thumbnail_path'] as String?,
          legacyUrlOrPath: m['thumbnail_url'] as String?,
        );
        out.add(
          SavedReelCard(
            id: id,
            thumbnailUrl: thumb,
            caption: (m['caption'] as String?)?.trim(),
          ),
        );
      }
      return out;
    } catch (e) {
      throw AppException('Failed to load saved items', cause: e);
    }
  }
}

final savedItemsRepositoryProvider = Provider<SavedItemsRepository>((ref) {
  return SavedItemsRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final mySavedBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(savedItemsRepositoryProvider).listSavedBarbers();
});

final mySavedShopsProvider = FutureProvider<List<Barbershop>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(savedItemsRepositoryProvider).listSavedShops();
});

final mySavedReelsCardsProvider = FutureProvider<List<SavedReelCard>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(savedItemsRepositoryProvider).listSavedReels();
});
