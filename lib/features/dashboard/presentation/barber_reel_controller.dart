import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../barber/data/barber_repository.dart';
import '../../explore/data/reels_repository.dart';
import '../../home/presentation/home_reels_controller.dart';

class BarberReelController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'barber_reels',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> uploadImageReel({
    required Uint8List bytes,
    String? caption,
    String? location,
    List<String>? hashtags,
    bool asDraft = false,
    String? draftId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');

      final uploaded = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'reels',
            pathPrefix: 'barbers/${barber.id}',
            bytes: bytes,
            maxBytes: 15 * 1024 * 1024,
          );

      if (asDraft) {
        await ref.read(reelsRepositoryProvider).saveDraft(
              draftId: draftId,
              barberId: barber.id,
              shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
              mediaType: 'image',
              mediaPath: uploaded.path,
              thumbnailPath: uploaded.thumbnailPath ?? uploaded.path,
              caption: caption,
              location: location,
              hashtags: hashtags,
            );
      } else {
        await ref.read(reelsRepositoryProvider).create(
              barberId: barber.id,
              shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
              mediaType: 'image',
              mediaPath: uploaded.path,
              thumbnailPath: uploaded.thumbnailPath ?? uploaded.path,
              caption: caption,
              location: location,
              hashtags: hashtags,
            );
      }

      ref.invalidate(reelsFeedProvider);
      ref.invalidate(homeReelsControllerProvider);
      ref.invalidate(reelsForBarberProvider(barber.id));
      ref.invalidate(myBarberReelsManageProvider);
      ref.invalidate(myBarberReelsDraftsProvider);
    });
    _logIfError(action: 'upload_reel_image', meta: const {'bucket': 'reels'});
  }

  Future<void> uploadVideoReel({
    required Uint8List videoBytes,
    required String videoContentType,
    Uint8List? thumbnailBytes,
    String? caption,
    String? location,
    List<String>? hashtags,
    bool asDraft = false,
    String? draftId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');

      final uploaded = await ref.read(mediaServiceProvider).uploadReelVideo(
            pathPrefix: 'barbers/${barber.id}',
            videoBytes: videoBytes,
            contentType: videoContentType,
            thumbnailBytes: thumbnailBytes,
          );

      if (asDraft) {
        await ref.read(reelsRepositoryProvider).saveDraft(
              draftId: draftId,
              barberId: barber.id,
              shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
              mediaType: 'video',
              mediaPath: uploaded.videoPath,
              thumbnailPath: uploaded.thumbnailPath,
              caption: caption,
              location: location,
              hashtags: hashtags,
            );
      } else {
        await ref.read(reelsRepositoryProvider).create(
              barberId: barber.id,
              shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
              mediaType: 'video',
              mediaPath: uploaded.videoPath,
              thumbnailPath: uploaded.thumbnailPath,
              caption: caption,
              location: location,
              hashtags: hashtags,
            );
      }

      ref.invalidate(reelsFeedProvider);
      ref.invalidate(homeReelsControllerProvider);
      ref.invalidate(reelsForBarberProvider(barber.id));
      ref.invalidate(myBarberReelsManageProvider);
      ref.invalidate(myBarberReelsDraftsProvider);
    });
    _logIfError(action: 'upload_reel_video', meta: const {'bucket': 'reels'});
  }

  Future<void> publishDraft({required String draftId, String? caption, String? location, List<String>? hashtags}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(reelsRepositoryProvider).publishDraft(draftId: draftId, caption: caption, location: location, hashtags: hashtags);
      ref.invalidate(reelsFeedProvider);
      ref.invalidate(homeReelsControllerProvider);
      ref.invalidate(myBarberReelsManageProvider);
      ref.invalidate(myBarberReelsDraftsProvider);
    });
    _logIfError(action: 'publish_reel_draft');
  }

  Future<void> deleteDraft(String draftId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(reelsRepositoryProvider).archiveDraft(draftId);
      ref.invalidate(myBarberReelsDraftsProvider);
      ref.invalidate(myBarberReelsManageProvider);
    });
    _logIfError(action: 'delete_reel_draft');
  }
}

final barberReelControllerProvider = AsyncNotifierProvider.autoDispose<BarberReelController, void>(BarberReelController.new);
