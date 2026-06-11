import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/product.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../cart/data/cart_repository.dart';
import '../data/products_repository.dart';

class ProductsScreen extends ConsumerWidget {
  final String? shopId;

  const ProductsScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shopId == null || shopId!.isEmpty) {
      return LuxuryScaffold(
        header: LuxuryTopBar(
          leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
          title: Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        child: const Center(child: Text('Missing shop')),
      );
    }

    final productsValue = ref.watch(productsForShopProvider(shopId!));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(icon: Icons.shopping_cart_rounded, onPressed: () => context.push(Routes.cart)),
      ),
      child: AsyncValueWidget(
        value: productsValue,
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No products yet.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: items.map((p) => _ProductTile(product: p)).toList(),
          );
        },
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartRepo = ref.watch(cartRepositoryProvider);
    final p = product;
    final imageUrl = p.imageUrl ?? (p.images.isEmpty ? null : p.images.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 74,
                height: 74,
                  child: LuxuryNetworkImage(imageUrl: imageUrl, fallbackUrl: '', borderRadius: BorderRadius.zero),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '${p.price.toStringAsFixed(3)} ${p.currency}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: HallaqButton(
                          label: 'Add to cart',
                          expanded: true,
                          variant: HallaqButtonVariant.secondary,
                          icon: Icons.add_shopping_cart_rounded,
                          onPressed: () async {
                            try {
                              await cartRepo.setItem(productId: p.id, quantity: 1);
                              ref.invalidate(myCartLinesProvider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                            } on AppException catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
