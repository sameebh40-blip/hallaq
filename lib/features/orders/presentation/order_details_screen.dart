import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/orders_repository.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderValue = ref.watch(orderByIdProvider(orderId));
    final itemsValue = ref.watch(orderItemsViewProvider(orderId));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Order', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: orderValue,
        data: (order) {
          if (order == null) return const Center(child: Text('Order not found.'));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(order.status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    Text('Payment', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      '${order.paymentMethod} • ${order.paymentStatus}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Text('Total', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      '${order.totalAmount.toStringAsFixed(3)} ${order.currency}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AsyncValueWidget(
                value: itemsValue,
                data: (items) {
                  if (items.isEmpty) return const HallaqCard(glass: true, child: Text('No items.'));
                  return HallaqCard(
                    glass: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        ...items.map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text('${v.productName} × ${v.item.quantity}')),
                                Text(v.item.lineTotal.toStringAsFixed(3)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
