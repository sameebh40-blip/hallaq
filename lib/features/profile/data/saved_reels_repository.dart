import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class SavedReelItem {
  final String reelId;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final String? caption;

  const SavedReelItem({
    required this.reelId,
    required this.createdAt,
    this.thumbnailUrl,
    this.caption,
  });
}

class SavedReelsRepository {
  final SupabaseClient _client;
  final MediaService _media;

  SavedReelsRepository(this._client, this._media);

  Future<String?> _resolveThumb(String? raw) async {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    final resolved = await _media.resolveMediaUrlMulti(buckets: const ['reels', 'reels-media'], legacyUrlOrPath: v);
    return resolved ?? v;
  }

  Future<List<SavedReelItem>> listMy({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final data = await _client
          .from('reel_saves')
          .select('reel_id, created_at, reels(thumbnail_url, caption)')
          .eq('profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      final out = <SavedReelItem>[];
      for (final m in rows) {
        final reel = m['reels'] is Map ? Map<String, dynamic>.from(m['reels'] as Map) : null;
        final resolvedThumb = await _resolveThumb((reel?['thumbnail_url'] as String?)?.trim());
        out.add(SavedReelItem(
          reelId: (m['reel_id'] as String?) ?? '',
          createdAt: DateTime.parse(m['created_at'] as String),
          thumbnailUrl: resolvedThumb,
          caption: (reel?['caption'] as String?)?.trim(),
        ));
      }
      return out.where((e) => e.reelId.isNotEmpty).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load saved reels', cause: e);
    }
  }

  Future<void> remove(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_saves').delete().eq('profile_id', user.id).eq('reel_id', reelId);
    } catch (e) {
      throw AppException('Failed to remove saved reel', cause: e);
    }
  }
}

final savedReelsRepositoryProvider = Provider<SavedReelsRepository>((ref) {
  return SavedReelsRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final mySavedReelsProvider = FutureProvider<List<SavedReelItem>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(savedReelsRepositoryProvider).listMy();
});
