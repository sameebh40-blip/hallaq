import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../portfolio/data/portfolio_repository.dart';
import '../../shop/data/shop_repository.dart';

class ShopGalleryController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addImage({required Uint8List bytes, String? caption}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final shop = await ref.read(shopRepositoryProvider).getMyShop();
      if (shop == null) throw const AppException('No shop assigned to this account');

      final uploaded = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'portfolio',
            pathPrefix: 'shops/${shop.id}',
            bytes: bytes,
          );

      await ref.read(portfolioRepositoryProvider).create(
            ownerType: 'shop',
            ownerId: shop.id,
            mediaType: 'image',
            mediaPath: uploaded.path,
            thumbnailPath: uploaded.thumbnailPath,
            caption: caption,
          );

      ref.invalidate(portfolioForShopProvider(shop.id));
    });
  }

  Future<void> deleteItem({required String itemId, required String shopId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(portfolioRepositoryProvider).delete(id: itemId);
      ref.invalidate(portfolioForShopProvider(shopId));
    });
  }
}

final shopGalleryControllerProvider = AsyncNotifierProvider.autoDispose<ShopGalleryController, void>(ShopGalleryController.new);
