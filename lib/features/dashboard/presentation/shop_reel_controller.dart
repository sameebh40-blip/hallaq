import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../explore/data/reels_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../../home/presentation/home_reels_controller.dart';

class ShopReelController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'shop_reels',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> uploadImageReel({
    required Uint8List bytes,
    required String ownerType,
    required String ownerId,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      final isBarber = ownerType == 'barber';
      final effectiveShopId = shop.id;
      final pathPrefix = isBarber ? 'barbers/$ownerId' : 'shops/$effectiveShopId';

      final uploaded = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'reels',
            pathPrefix: pathPrefix,
            bytes: bytes,
            maxBytes: 15 * 1024 * 1024,
          );

      await ref.read(reelsRepositoryProvider).create(
            shopId: effectiveShopId,
            barberId: isBarber ? ownerId : null,
            mediaType: 'image',
            mediaPath: uploaded.path,
            thumbnailPath: uploaded.thumbnailPath ?? uploaded.path,
            caption: caption,
            hashtags: hashtags,
            location: location,
          );

      ref.invalidate(reelsFeedProvider);
      ref.invalidate(homeReelsControllerProvider);
    });
    _logIfError(action: 'upload_reel_image', meta: const {'bucket': 'reels'});
  }

  Future<void> uploadVideoReel({
    required Uint8List videoBytes,
    required String ownerType,
    required String ownerId,
    required String videoContentType,
    Uint8List? thumbnailBytes,
    String? caption,
    String? location,
    List<String>? hashtags,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      final isBarber = ownerType == 'barber';
      final effectiveShopId = shop.id;
      final pathPrefix = isBarber ? 'barbers/$ownerId' : 'shops/$effectiveShopId';

      final uploaded = await ref.read(mediaServiceProvider).uploadReelVideo(
            pathPrefix: pathPrefix,
            videoBytes: videoBytes,
            contentType: videoContentType,
            thumbnailBytes: thumbnailBytes,
          );

      await ref.read(reelsRepositoryProvider).create(
            shopId: effectiveShopId,
            barberId: isBarber ? ownerId : null,
            mediaType: 'video',
            mediaPath: uploaded.videoPath,
            thumbnailPath: uploaded.thumbnailPath,
            caption: caption,
            hashtags: hashtags,
            location: location,
          );

      ref.invalidate(reelsFeedProvider);
      ref.invalidate(homeReelsControllerProvider);
    });
    _logIfError(action: 'upload_reel_video', meta: const {'bucket': 'reels'});
  }

}

final shopReelControllerProvider = AsyncNotifierProvider.autoDispose<ShopReelController, void>(ShopReelController.new);
