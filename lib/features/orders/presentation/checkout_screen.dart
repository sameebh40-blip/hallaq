import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/luxury_text_field.dart';
import '../../cart/data/cart_repository.dart';
import '../data/orders_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String? shopId;

  const CheckoutScreen({super.key, this.shopId});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _block = TextEditingController();
  final _road = TextEditingController();
  final _building = TextEditingController();
  final _apartment = TextEditingController();
  final _notes = TextEditingController();

  var _busy = false;
  var _paymentMethod = 'cod';

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _area.dispose();
    _block.dispose();
    _road.dispose();
    _building.dispose();
    _apartment.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linesValue = ref.watch(myCartLinesProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Checkout', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<List<CartLine>>(
        value: linesValue,
        data: (lines) {
          if (lines.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          final groups = <String, List<CartLine>>{};
          for (final l in lines) {
            groups.putIfAbsent(l.product.shopId, () => []).add(l);
          }

          if (widget.shopId == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                const HallaqCard(glass: true, child: Text('Select a shop to checkout.')),
                const SizedBox(height: 12),
                ...groups.entries.map((e) => _ShopCheckoutCard(shopId: e.key, lines: e.value)),
              ],
            );
          }

          final shopLines = groups[widget.shopId];
          if (shopLines == null || shopLines.isEmpty) {
            return const Center(child: Text('No items for this shop.'));
          }

          final subtotal = shopLines.fold<double>(0, (sum, l) => sum + (l.product.price * l.item.quantity));
          final currency = shopLines.first.product.currency;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order summary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ...shopLines.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('${l.product.name} × ${l.item.quantity}')),
                            Text((l.product.price * l.item.quantity).toStringAsFixed(3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('Total', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                        Text('${subtotal.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    LuxuryTextField(controller: _fullName, label: 'Full name'),
                    const SizedBox(height: 10),
                    LuxuryTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    LuxuryTextField(controller: _area, label: 'Area'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: LuxuryTextField(controller: _block, label: 'Block')),
                        const SizedBox(width: 10),
                        Expanded(child: LuxuryTextField(controller: _road, label: 'Road')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: LuxuryTextField(controller: _building, label: 'Building')),
                        const SizedBox(width: 10),
                        Expanded(child: LuxuryTextField(controller: _apartment, label: 'Apartment')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LuxuryTextField(controller: _notes, label: 'Notes (optional)', textInputAction: TextInputAction.done),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => setState(() => _paymentMethod = 'cod'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _paymentMethod == 'cod' ? Colors.black : AppTheme.textMuted,
                              side: BorderSide(color: _paymentMethod == 'cod' ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.22)),
                            ),
                            child: const Text('COD'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => setState(() => _paymentMethod = 'card'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _paymentMethod == 'card' ? Colors.black : AppTheme.textMuted,
                              side: BorderSide(color: _paymentMethod == 'card' ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.22)),
                            ),
                            child: const Text('Card'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              HallaqButton(
                label: 'Place order',
                isLoading: _busy,
                icon: Icons.check_rounded,
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final repo = ref.read(ordersRepositoryProvider);
                          final cartRepo = ref.read(cartRepositoryProvider);

                          final address = <String, dynamic>{
                            'full_name': _fullName.text.trim(),
                            'phone': _phone.text.trim(),
                            'area': _area.text.trim(),
                            'block': _block.text.trim(),
                            'road': _road.text.trim(),
                            'building': _building.text.trim(),
                            'apartment': _apartment.text.trim(),
                          };

                          final order = await repo.createOrder(
                            shopId: widget.shopId!,
                            items: shopLines.map((l) => (productId: l.product.id, quantity: l.item.quantity)).toList(),
                            deliveryAddress: address,
                            paymentMethod: _paymentMethod,
                            customerNote: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                          );

                          for (final l in shopLines) {
                            await cartRepo.removeItem(l.product.id);
                          }

                          ref.invalidate(myCartLinesProvider);
                          ref.invalidate(myOrdersProvider);

                          if (!context.mounted) return;
                          context.go('${Routes.orders}/${order.id}');
                        } on AppException catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopCheckoutCard extends StatelessWidget {
  final String shopId;
  final List<CartLine> lines;

  const _ShopCheckoutCard({required this.shopId, required this.lines});

  @override
  Widget build(BuildContext context) {
    final subtotal = lines.fold<double>(0, (sum, l) => sum + (l.product.price * l.item.quantity));
    final currency = lines.first.product.currency;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: () => context.push('${Routes.checkout}?shopId=$shopId'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shop $shopId', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${lines.length} items • ${subtotal.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
