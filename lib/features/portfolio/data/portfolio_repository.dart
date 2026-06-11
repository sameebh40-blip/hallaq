import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/portfolio_item.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class PortfolioRepository {
  final SupabaseClient _client;
  final MediaService _media;

  PortfolioRepository(this._client, this._media);

  Future<PortfolioItem> _withSignedMedia(PortfolioItem item) async {
    final thumb = await _media.resolveMediaUrl(bucket: 'portfolio', path: item.thumbnailPath, legacyUrlOrPath: item.thumbnailUrl);
    return item.copyWith(thumbnailUrl: thumb);
  }

  Future<PortfolioItem> create({
    required String ownerType,
    required String ownerId,
    required String mediaType,
    required String mediaPath,
    String? thumbnailPath,
    String? caption,
    String? category,
  }) async {
    try {
      final normalizedMediaUrl =
          mediaPath.trim().startsWith('http') ? mediaPath.trim() : _media.publicUrlFor(bucket: 'portfolio', path: mediaPath.trim());
      final tp = (thumbnailPath ?? '').trim();
      final normalizedThumbUrl = tp.isEmpty ? null : (tp.startsWith('http') ? tp : _media.publicUrlFor(bucket: 'portfolio', path: tp));
      final data = await _client
          .from('portfolio_items')
          .insert({
            'owner_type': ownerType,
            'owner_id': ownerId,
            'media_type': mediaType,
            'media_path': mediaPath,
            'media_url': normalizedMediaUrl,
            'thumbnail_path': tp.isEmpty ? null : tp,
            'thumbnail_url': normalizedThumbUrl,
            'caption': (caption ?? '').trim().isEmpty ? null : caption,
            'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
          })
          .select()
          .single();
      return _withSignedMedia(PortfolioItem.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to create portfolio item', cause: e);
    }
  }

  Future<void> delete({required String id}) async {
    try {
      await _client.from('portfolio_items').delete().eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete portfolio item', cause: e);
    }
  }

  Future<PortfolioItem> update({
    required String id,
    String? caption,
    String? category,
    bool? isFeatured,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (caption != null) 'caption': caption.trim().isEmpty ? null : caption.trim(),
        if (category != null) 'category': category.trim().isEmpty ? null : category.trim(),
        if (isFeatured != null) 'is_featured': isFeatured,
      };
      final data = await _client.from('portfolio_items').update(payload).eq('id', id).select().single();
      return _withSignedMedia(PortfolioItem.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      throw AppException('Failed to update portfolio item', cause: e);
    }
  }

  Future<List<PortfolioItem>> list({required String ownerType, required String ownerId, int limit = 40, int offset = 0}) async {
    try {
      final data = await _client
          .from('portfolio_items')
          .select()
          .eq('owner_type', ownerType)
          .eq('owner_id', ownerId)
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (data as List).map((e) => PortfolioItem.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      return const <PortfolioItem>[];
    }
  }
}

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PortfolioRepository(client, ref.watch(mediaServiceProvider));
});

final portfolioForBarberProvider = FutureProvider.family<List<PortfolioItem>, String>((ref, barberId) async {
  return ref.watch(portfolioRepositoryProvider).list(ownerType: 'barber', ownerId: barberId);
});

final portfolioForShopProvider = FutureProvider.family<List<PortfolioItem>, String>((ref, shopId) async {
  return ref.watch(portfolioRepositoryProvider).list(ownerType: 'shop', ownerId: shopId);
});

final portfolioPreviewForBarberProvider = FutureProvider.family<List<PortfolioItem>, String>((ref, barberId) async {
  return ref.watch(portfolioRepositoryProvider).list(ownerType: 'barber', ownerId: barberId, limit: 20, offset: 0);
});

final portfolioPreviewForShopProvider = FutureProvider.family<List<PortfolioItem>, String>((ref, shopId) async {
  return ref.watch(portfolioRepositoryProvider).list(ownerType: 'shop', ownerId: shopId, limit: 20, offset: 0);
});
