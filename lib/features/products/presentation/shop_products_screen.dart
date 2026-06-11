import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/product.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../dashboard/data/shop_dashboard_repository.dart';
import '../../../core/media/media_service.dart';
import '../data/products_repository.dart';

final _myShopIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).getMyShopId();
});

class ShopProductsScreen extends ConsumerWidget {
  const ShopProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopIdValue = ref.watch(_myShopIdProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.add_rounded,
          onPressed: () {
            final shopId = shopIdValue.valueOrNull;
            if (shopId == null) return;
            context.push('${Routes.shopManageProducts}/new');
          },
        ),
      ),
      child: AsyncValueWidget<String?>(
        value: shopIdValue,
        data: (shopId) {
          if (shopId == null) return const Center(child: Text('No shop assigned to this account.'));
          final productsValue = ref.watch(shopProductsManagementProvider(shopId));
          return AsyncValueWidget<List<Product>>(
            value: productsValue,
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No products yet.'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                children: items.map((p) => _ProductRow(shopId: shopId, product: p)).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductRow extends ConsumerWidget {
  final String shopId;
  final Product product;

  const _ProductRow({required this.shopId, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productsRepositoryProvider);
    final media = ref.watch(mediaServiceProvider);
    final primary = (product.imageUrl ?? '').trim();
    final imageUrl = primary.isNotEmpty ? primary : (product.images.isEmpty ? null : product.images.first);
    final needsResolution = (imageUrl ?? '').trim().isNotEmpty && !(imageUrl ?? '').trim().startsWith('http');

    Future<void> toggleActive() async {
      await repo.update(id: product.id, active: !product.active);
      ref.invalidate(shopProductsManagementProvider(shopId));
    }

    Future<void> delete() async {
      final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete product'),
              content: const Text('This will remove the product.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      await repo.delete(id: product.id);
      ref.invalidate(shopProductsManagementProvider(shopId));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('${Routes.shopManageProducts}/${product.id}'),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: !needsResolution
                    ? LuxuryNetworkImage(imageUrl: imageUrl, fallbackUrl: '', borderRadius: BorderRadius.zero)
                    : FutureBuilder<String?>(
                        future: media.resolveMediaUrlMulti(
                          buckets: const ['product-images', 'products'],
                          path: imageUrl,
                          legacyUrlOrPath: imageUrl,
                        ),
                        builder: (context, snapshot) {
                          return LuxuryNetworkImage(
                            imageUrl: snapshot.data ?? imageUrl,
                            fallbackUrl: '',
                            borderRadius: BorderRadius.zero,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '${product.price.toStringAsFixed(3)} ${product.currency} • Stock ${product.stock}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: toggleActive,
                          child: Text(product.active ? 'Disable' : 'Enable'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppTheme.textMuted,
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
