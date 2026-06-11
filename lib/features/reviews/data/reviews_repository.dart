import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/review.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../barber/data/barber_repository.dart';

class ReviewsRepository {
  final SupabaseClient _client;
  final StorageService _storage;
  final MediaService _media;

  ReviewsRepository(this._client, this._storage, this._media);

  Future<Review> _withSignedMedia(Review r) async {
    final image = await _media.resolveMediaUrl(bucket: 'review-photos', path: r.imagePath, legacyUrlOrPath: r.imageUrl);
    final avatar = await _media.resolveMediaUrl(bucket: 'avatars', path: r.customerAvatarPath, legacyUrlOrPath: r.customerAvatarUrl);
    return r.copyWith(imageUrl: image, customerAvatarUrl: avatar);
  }

  Future<List<Review>> listForTarget({required String targetType, required String targetId, int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from('reviews')
          .select(
            'id, customer_id, customer_profile_id, shop_id, barber_id, rating, comment, image_url, image_path, text, photo_url, is_verified, reply_text, replied_at, created_at, profiles(full_name, avatar_url, avatar_path)',
          )
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (data as List).map((e) => Review.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
      return Future.wait(list.map(_withSignedMedia));
    } catch (e) {
      return const <Review>[];
    }
  }

  Future<Review> create({
    required String targetType,
    required String targetId,
    required int rating,
    String? comment,
    XFile? photo,
    String? bookingId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    if (bookingId == null || bookingId.trim().isEmpty) {
      throw const AppException('You can review after your booking is confirmed or completed.');
    }

    String? photoPath;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final ext = photo.name.split('.').last;
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      photoPath = await _storage.uploadBytes(
        bucket: 'review-photos',
        path: path,
        bytes: bytes,
        contentType: photo.mimeType,
      );
    }

    try {
      final barberId = targetType == 'barber' ? targetId : null;
      final shopId = targetType == 'shop' ? targetId : null;
      final normalizedPhotoUrl = (photoPath ?? '').trim().isEmpty ? null : _media.publicUrlFor(bucket: 'review-photos', path: photoPath!.trim());
      final data = await _client
          .from('reviews')
          .insert({
            'customer_profile_id': user.id,
            'customer_id': user.id,
            'booking_id': bookingId,
            'target_type': targetType,
            'target_id': targetId,
            'barber_id': barberId,
            'shop_id': shopId,
            'rating': rating,
            'comment': comment,
            'text': comment,
            'image_path': photoPath,
            'image_url': normalizedPhotoUrl,
            'photo_url': normalizedPhotoUrl,
          })
          .select(
            'id, customer_id, customer_profile_id, shop_id, barber_id, rating, comment, image_url, image_path, text, photo_url, is_verified, reply_text, replied_at, created_at, profiles(full_name, avatar_url, avatar_path)',
          )
          .single();
      return _withSignedMedia(Review.fromJson(Map<String, dynamic>.from(data)));
    } catch (e) {
      throw AppException('Failed to create review', cause: e);
    }
  }

  Future<Review> updateReply({required String reviewId, String? replyText}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final data = await _client
          .from('reviews')
          .update({'reply_text': (replyText ?? '').trim().isEmpty ? null : replyText?.trim()})
          .eq('id', reviewId)
          .select(
            'id, customer_id, customer_profile_id, shop_id, barber_id, rating, comment, image_url, image_path, text, photo_url, is_verified, reply_text, replied_at, created_at, profiles(full_name, avatar_url, avatar_path)',
          )
          .single();
      return _withSignedMedia(Review.fromJson(Map<String, dynamic>.from(data)));
    } catch (e) {
      throw AppException('Failed to reply to review', cause: e);
    }
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return ReviewsRepository(client, storage, ref.watch(mediaServiceProvider));
});

final reviewsForTargetProvider = FutureProvider.family<List<Review>, ({String targetType, String targetId})>((ref, args) async {
  return ref.watch(reviewsRepositoryProvider).listForTarget(targetType: args.targetType, targetId: args.targetId);
});

final reviewsPreviewForTargetProvider = FutureProvider.family<List<Review>, ({String targetType, String targetId})>((ref, args) async {
  return ref.watch(reviewsRepositoryProvider).listForTarget(targetType: args.targetType, targetId: args.targetId, limit: 10, offset: 0);
});

final myBarberReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <Review>[];
  return ref.watch(reviewsRepositoryProvider).listForTarget(targetType: 'barber', targetId: barber.id, limit: 80);
});
