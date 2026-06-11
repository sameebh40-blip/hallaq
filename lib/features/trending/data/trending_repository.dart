import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barber_public_stats.dart';
import '../../../core/models/reel.dart';
import '../../../core/models/trending_entry.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class TrendingRepository {
  final SupabaseClient _client;
  final MediaService _media;

  TrendingRepository(this._client, this._media);

  Future<Reel> _withSignedMedia(Reel r) async {
    final media = await _media.resolveMediaUrlMulti(
      buckets: const ['reels', 'reels-media'],
      path: r.mediaPath,
      legacyUrlOrPath: r.mediaUrl,
    );
    final thumb = await _media.resolveMediaUrlMulti(
      buckets: const ['reels', 'reels-media'],
      path: r.thumbnailPath,
      legacyUrlOrPath: r.thumbnailUrl,
    );
    return r.copyWith(mediaUrl: media ?? r.mediaUrl, thumbnailUrl: thumb);
  }

  Future<List<TrendingEntry>> getTrendingThisWeek() async {
    try {
      final data = await _client.rpc('get_trending_this_week');
      if (data is! List) return const <TrendingEntry>[];
      return data.map((e) => TrendingEntry.fromJson(Map<String, dynamic>.from(e as Map))).where((e) => e.kind.isNotEmpty).toList();
    } catch (e) {
      throw AppException('Failed to load trending', cause: e);
    }
  }

  Future<BarberPublicStats?> getBarberPublicStats(String barberId) async {
    try {
      final data = await _client.rpc('get_barber_public_stats', params: {'p_barber_id': barberId});
      if (data is! List || data.isEmpty) return null;
      return BarberPublicStats.fromJson(Map<String, dynamic>.from(data.first as Map));
    } catch (e) {
      throw AppException('Failed to load stats', cause: e);
    }
  }

  Future<Reel?> getReelById(String reelId) async {
    try {
      final data = await _client
          .from('reels')
          .select(
            'id, barber_id, shop_id, media_type, media_url, media_path, image_url, video_url, thumbnail_url, thumbnail_path, caption, location, hashtags, status, rejection_reason, likes_count, comments_count, saves_count, shares_count, created_at',
          )
          .eq('id', reelId)
          .maybeSingle();
      if (data == null) return null;
      return _withSignedMedia(Reel.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to load reel', cause: e);
    }
  }
}

final trendingRepositoryProvider = Provider<TrendingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TrendingRepository(client, ref.watch(mediaServiceProvider));
});

final trendingThisWeekProvider = FutureProvider<List<TrendingEntry>>((ref) async {
  return ref.watch(trendingRepositoryProvider).getTrendingThisWeek();
});

final barberPublicStatsProvider = FutureProvider.family<BarberPublicStats?, String>((ref, barberId) async {
  return ref.watch(trendingRepositoryProvider).getBarberPublicStats(barberId);
});

final trendingReelProvider = FutureProvider.family<Reel?, String>((ref, reelId) async {
  return ref.watch(trendingRepositoryProvider).getReelById(reelId);
});
