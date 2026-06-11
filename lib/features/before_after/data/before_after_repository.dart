import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/before_after_item.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class BeforeAfterRepository {
  final SupabaseClient _client;
  final MediaService _media;

  BeforeAfterRepository(this._client, this._media);

  Future<List<BeforeAfterItem>> listForBarber(String barberId, {int limit = 50}) async {
    try {
      final data = await _client
          .from('before_after_items')
          .select()
          .eq('barber_id', barberId)
          .order('approved_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return Future.wait((data as List).map((e) async {
        final m = Map<String, dynamic>.from(e);
        final beforePath = (m['before_image_path'] as String?) ?? '';
        final afterPath = (m['after_image_path'] as String?) ?? '';
        m['before_image_url'] = beforePath.isEmpty ? '' : (await _media.resolveMediaUrl(bucket: 'before-after', path: beforePath)) ?? '';
        m['after_image_url'] = afterPath.isEmpty ? '' : (await _media.resolveMediaUrl(bucket: 'before-after', path: afterPath)) ?? '';
        return BeforeAfterItem.fromJson(m);
      }));
    } catch (e) {
      throw AppException('Failed to load before/after', cause: e);
    }
  }

  Future<List<BeforeAfterItem>> listForShop(String shopId, {int limit = 50}) async {
    try {
      final data = await _client
          .from('before_after_items')
          .select()
          .eq('shop_id', shopId)
          .order('approved_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return Future.wait((data as List).map((e) async {
        final m = Map<String, dynamic>.from(e);
        final beforePath = (m['before_image_path'] as String?) ?? '';
        final afterPath = (m['after_image_path'] as String?) ?? '';
        m['before_image_url'] = beforePath.isEmpty ? '' : (await _media.resolveMediaUrl(bucket: 'before-after', path: beforePath)) ?? '';
        m['after_image_url'] = afterPath.isEmpty ? '' : (await _media.resolveMediaUrl(bucket: 'before-after', path: afterPath)) ?? '';
        return BeforeAfterItem.fromJson(m);
      }));
    } catch (e) {
      throw AppException('Failed to load before/after', cause: e);
    }
  }

  Future<void> create({
    String? barberId,
    String? shopId,
    required Uint8List beforeBytes,
    required Uint8List afterBytes,
    String? caption,
    String? category,
  }) async {
    try {
      final prefix = barberId != null ? 'barbers/$barberId' : 'shops/$shopId';
      final beforeStored = await _media.uploadImage(
        bucket: 'before-after',
        pathPrefix: '$prefix/before-after',
        bytes: beforeBytes,
        uploadThumbnail: false,
      );
      final afterStored = await _media.uploadImage(
        bucket: 'before-after',
        pathPrefix: '$prefix/before-after',
        bytes: afterBytes,
        uploadThumbnail: false,
      );

      final user = _client.auth.currentUser;
      await _client.from('before_after_items').insert({
        'barber_id': barberId,
        'shop_id': shopId,
        'created_by_profile_id': user?.id,
        'before_image_path': beforeStored.path,
        'after_image_path': afterStored.path,
        'caption': (caption ?? '').trim().isEmpty ? null : caption!.trim(),
        'category': (category ?? '').trim().isEmpty ? null : category!.trim(),
      });
    } catch (e) {
      throw AppException('Failed to upload before/after', cause: e);
    }
  }

  Future<void> delete({required String id}) async {
    try {
      await _client.from('before_after_items').delete().eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete item', cause: e);
    }
  }
}

final beforeAfterRepositoryProvider = Provider<BeforeAfterRepository>((ref) {
  return BeforeAfterRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final beforeAfterForBarberProvider = FutureProvider.family<List<BeforeAfterItem>, String>((ref, barberId) async {
  return ref.watch(beforeAfterRepositoryProvider).listForBarber(barberId);
});

final beforeAfterForShopProvider = FutureProvider.family<List<BeforeAfterItem>, String>((ref, shopId) async {
  return ref.watch(beforeAfterRepositoryProvider).listForShop(shopId);
});
