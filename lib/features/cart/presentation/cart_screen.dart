import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/cart_repository.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesValue = ref.watch(myCartLinesProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Cart', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<List<CartLine>>(
        value: linesValue,
        data: (lines) {
          if (lines.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          final shopIds = lines.map((l) => l.product.shopId).toSet().toList();
          final canCheckoutSingleShop = shopIds.length == 1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              ...lines.map((l) => _CartLineTile(line: l)),
              const SizedBox(height: 14),
              if (!canCheckoutSingleShop)
                const HallaqCard(
                  glass: true,
                  child: Text('Your cart has products from multiple shops. Checkout is done per shop.'),
                ),
              const SizedBox(height: 12),
              HallaqButton(
                label: canCheckoutSingleShop ? 'Checkout' : 'Choose shop to checkout',
                icon: Icons.shopping_bag_rounded,
                onPressed: () => context.push(Routes.checkout),
              ),
              const SizedBox(height: 10),
              HallaqButton(
                label: 'My orders',
                variant: HallaqButtonVariant.secondary,
                icon: Icons.receipt_long_rounded,
                onPressed: () => context.push(Routes.orders),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  final CartLine line;

  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartRepo = ref.watch(cartRepositoryProvider);
    final p = line.product;
    final qty = line.item.quantity;
    final imageUrl = p.imageUrl ?? (p.images.isEmpty ? null : p.images.first);

    Future<void> setQty(int v) async {
      if (v <= 0) {
        await cartRepo.removeItem(p.id);
      } else {
        await cartRepo.setItem(productId: p.id, quantity: v);
      }
      ref.invalidate(myCartLinesProvider);
    }

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
                width: 64,
                height: 64,
                child: LuxuryNetworkImage(
                  imageUrl: imageUrl,
                    fallbackUrl: '',
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
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
                      _QtyButton(icon: Icons.remove_rounded, onTap: () => setQty(qty - 1)),
                      const SizedBox(width: 10),
                      Text('$qty', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      _QtyButton(icon: Icons.add_rounded, onTap: () => setQty(qty + 1)),
                      const Spacer(),
                      Text(
                        (p.price * qty).toStringAsFixed(3),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 6),
                      Text(p.currency, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
