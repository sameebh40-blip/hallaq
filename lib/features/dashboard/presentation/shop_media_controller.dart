import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../shop/data/shop_repository.dart';

class ShopMediaController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'shop_media',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> saveProfile({
    required String name,
    required String area,
    required String address,
    required String phone,
    String? whatsapp,
    String? googleMapsUrl,
    double? lat,
    double? lng,
    Map<String, dynamic>? openingHours,
    bool? homeService,
    Uint8List? logoBytes,
    Uint8List? coverBytes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      String? logoPath;
      String? logoUrl;
      String? coverPath;
      String? coverUrl;
      final prevLogoPath = (shop.logoPath ?? '').trim();
      final prevCoverPath = (shop.coverPath ?? '').trim();

      if (logoBytes != null) {
        final stored = await ref.read(mediaServiceProvider).uploadImage(
              bucket: 'shop-images',
              pathPrefix: 'shops/${shop.id}',
              bytes: logoBytes,
              options: const MediaImageProcessOptions(
                cropAspectRatio: 1,
                maxWidth: 512,
                maxHeight: 512,
              ),
              uploadThumbnail: false,
            );
        logoPath = stored.path;
        logoUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: 'shop-images', path: stored.path);
      }

      if (coverBytes != null) {
        final stored = await ref.read(mediaServiceProvider).uploadImage(
              bucket: 'shop-images',
              pathPrefix: 'shops/${shop.id}',
              bytes: coverBytes,
              options: const MediaImageProcessOptions(
                cropAspectRatio: 16 / 9,
                maxWidth: 1280,
                maxHeight: 720,
              ),
              uploadThumbnail: false,
            );
        coverPath = stored.path;
        coverUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: 'shop-images', path: stored.path);
      }

      await ref.read(shopRepositoryProvider).updateShop(
            shopId: shop.id,
            name: name,
            area: area,
            address: address,
            phone: phone,
            whatsapp: whatsapp,
            googleMapsUrl: googleMapsUrl,
            lat: lat,
            lng: lng,
            openingHours: openingHours,
            homeService: homeService,
            logoPath: logoPath,
            logoUrl: logoUrl,
            coverPath: coverPath,
            coverUrl: coverUrl,
          );
      if (logoPath != null && prevLogoPath.isNotEmpty && prevLogoPath != logoPath) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'shop-images', path: prevLogoPath);
        } catch (_) {}
      }
      if (coverPath != null && prevCoverPath.isNotEmpty && prevCoverPath != coverPath) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'shop-images', path: prevCoverPath);
        } catch (_) {}
      }
      ref.invalidate(myShopProvider);
      ref.invalidate(featuredShopsProvider);
      ref.invalidate(shopByIdProvider(shop.id));
    });
    _logIfError(action: 'save_profile', meta: const {'bucket': 'shop-images'});
  }

  Future<void> updateLogo({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      final previousPath = (shop.logoPath ?? '').trim();
      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'shop-images',
            pathPrefix: 'shops/${shop.id}',
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 1,
              maxWidth: 512,
              maxHeight: 512,
            ),
            uploadThumbnail: false,
          );

      final publicUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: 'shop-images', path: stored.path);
      await ref.read(shopRepositoryProvider).updateShop(shopId: shop.id, logoPath: stored.path, logoUrl: publicUrl);
      if (previousPath.isNotEmpty && previousPath != stored.path) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'shop-images', path: previousPath);
        } catch (_) {}
      }
      ref.invalidate(myShopProvider);
      ref.invalidate(featuredShopsProvider);
      ref.invalidate(shopByIdProvider(shop.id));
    });
    _logIfError(action: 'upload_logo', meta: const {'bucket': 'shop-images'});
  }

  Future<void> updateCover({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      final previousPath = (shop.coverPath ?? '').trim();
      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'shop-images',
            pathPrefix: 'shops/${shop.id}',
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 16 / 9,
              maxWidth: 1280,
              maxHeight: 720,
            ),
            uploadThumbnail: false,
          );

      final publicUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: 'shop-images', path: stored.path);
      await ref.read(shopRepositoryProvider).updateShop(shopId: shop.id, coverPath: stored.path, coverUrl: publicUrl);
      if (previousPath.isNotEmpty && previousPath != stored.path) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'shop-images', path: previousPath);
        } catch (_) {}
      }
      ref.invalidate(myShopProvider);
      ref.invalidate(featuredShopsProvider);
      ref.invalidate(shopByIdProvider(shop.id));
    });
    _logIfError(action: 'upload_cover', meta: const {'bucket': 'shop-images'});
  }

  Future<void> updateDetails({
    required String name,
    required String area,
    required String address,
    required String phone,
    String? whatsapp,
    String? googleMapsUrl,
    double? lat,
    double? lng,
    Map<String, dynamic>? openingHours,
    bool? homeService,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      await ref.read(shopRepositoryProvider).updateShop(
            shopId: shop.id,
            name: name,
            area: area,
            address: address,
            phone: phone,
            whatsapp: whatsapp,
            googleMapsUrl: googleMapsUrl,
            lat: lat,
            lng: lng,
            openingHours: openingHours,
            homeService: homeService,
          );
      ref.invalidate(myShopProvider);
      ref.invalidate(featuredShopsProvider);
      ref.invalidate(shopByIdProvider(shop.id));
    });
  }
}

final shopMediaControllerProvider = AsyncNotifierProvider.autoDispose<ShopMediaController, void>(ShopMediaController.new);
