import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../portfolio/data/portfolio_repository.dart';
import '../../shop/data/shop_repository.dart';
import 'shop_gallery_controller.dart';

class ShopManageGalleryScreen extends ConsumerWidget {
  const ShopManageGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(myShopProvider);
    final controller = ref.watch(shopGalleryControllerProvider);

    ref.listen(shopGalleryControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
    });

    Future<void> upload() async {
      final shop = await ref.read(myShopProvider.future);
      if (shop == null) return;
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await ref.read(shopGalleryControllerProvider.notifier).addImage(bytes: bytes);
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Gallery', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        trailing: LuxuryIconButton(icon: Icons.add_photo_alternate_outlined, onPressed: controller.isLoading ? null : upload),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: HallaqCard(glass: true, child: Text('No shop assigned to this account.')),
            );
          }

          final itemsValue = ref.watch(portfolioForShopProvider(shop.id));
          return AsyncValueWidget(
            value: itemsValue,
            data: (items) {
              final list = items.isEmpty ? List.generate(9, (_) => null) : items;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  final v = (index + 1).toString().padLeft(2, '0');
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: HallaqCard(
                          padding: EdgeInsets.zero,
                          child: LuxuryNetworkImage(
                            imageUrl: item == null
                                ? null
                                : ((item.thumbnailPath ?? '').trim().isNotEmpty
                                    ? item.thumbnailPath
                                    : (item.thumbnailUrl ?? '').trim().isNotEmpty
                                        ? item.thumbnailUrl
                                        : item.mediaPath ?? item.mediaUrl),
                            fallbackUrl: HallaqImages.shopCover(variant: v),
                            bucket: 'portfolio',
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
                      if (item != null)
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: GestureDetector(
                            onTap: controller.isLoading
                                ? null
                                : () => ref.read(shopGalleryControllerProvider.notifier).deleteItem(itemId: item.id, shopId: shop.id),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.45),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                              ),
                              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
