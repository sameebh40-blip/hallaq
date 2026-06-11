import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../dashboard/data/shop_dashboard_repository.dart';

final _shopOrderDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, orderId) async {
  final repo = ref.watch(shopDashboardRepositoryProvider);
  return repo.getShopOrderById(orderId: orderId);
});

final _shopOrderItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) async {
  final repo = ref.watch(shopDashboardRepositoryProvider);
  return repo.listOrderItems(orderId: orderId);
});

class ShopOrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const ShopOrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderValue = ref.watch(_shopOrderDetailsProvider(orderId));
    final itemsValue = ref.watch(_shopOrderItemsProvider(orderId));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Order', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<Map<String, dynamic>?>(
        value: orderValue,
        data: (order) {
          if (order == null) return const Center(child: Text('Order not found.'));

          final status = (order['status'] as String?) ?? 'pending';
          final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
          final currency = (order['currency'] as String?) ?? 'BHD';
          final paymentMethod = (order['payment_method'] as String?) ?? 'cod';
          final paymentStatus = (order['payment_status'] as String?) ?? 'unpaid';
          final addr = order['delivery_address'] is Map ? Map<String, dynamic>.from(order['delivery_address'] as Map) : const <String, dynamic>{};

          Future<void> setStatus(String s) async {
            await ref.read(shopDashboardRepositoryProvider).updateOrderStatus(orderId: orderId, status: s);
            ref.invalidate(_shopOrderDetailsProvider(orderId));
            ref.invalidate(_shopOrderItemsProvider(orderId));
            ref.invalidate(shopDashboardOrdersProvider);
          }

          Future<void> setPayment(String s) async {
            await ref.read(shopDashboardRepositoryProvider).updateOrderPaymentStatus(orderId: orderId, paymentStatus: s);
            ref.invalidate(_shopOrderDetailsProvider(orderId));
            ref.invalidate(shopDashboardOrdersProvider);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _kv(context, 'Status', status),
                    _kv(context, 'Total', '${total.toStringAsFixed(3)} $currency'),
                    _kv(context, 'Payment', '$paymentMethod • $paymentStatus'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _kv(context, 'Name', (addr['full_name'] as String?) ?? ''),
                    _kv(context, 'Phone', (addr['phone'] as String?) ?? ''),
                    _kv(context, 'Area', (addr['area'] as String?) ?? ''),
                    _kv(context, 'Block', (addr['block'] as String?) ?? ''),
                    _kv(context, 'Road', (addr['road'] as String?) ?? ''),
                    _kv(context, 'Building', (addr['building'] as String?) ?? ''),
                    _kv(context, 'Apartment', (addr['apartment'] as String?) ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AsyncValueWidget<List<Map<String, dynamic>>>(
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
                        ...items.map((m) {
                          final qty = (m['quantity'] as num?)?.toInt() ?? 0;
                          final lineTotal = (m['line_total'] as num?)?.toDouble() ?? 0;
                          final product = m['products'] is Map ? Map<String, dynamic>.from(m['products'] as Map) : const <String, dynamic>{};
                          final name = (product['name'] as String?) ?? 'Product';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text('$name × $qty')),
                                Text(lineTotal.toStringAsFixed(3)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: status == 'accepted' ? null : () => setStatus('accepted'), child: const Text('Accept'))),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton(onPressed: status == 'rejected' ? null : () => setStatus('rejected'), child: const Text('Reject'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: status == 'shipped' ? null : () => setStatus('shipped'), child: const Text('Shipped'))),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton(onPressed: status == 'delivered' ? null : () => setStatus('delivered'), child: const Text('Delivered'))),
                      ],
                    ),
                    if (paymentMethod == 'card') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: paymentStatus == 'paid' ? null : () => setPayment('paid'),
                              child: const Text('Mark paid'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: paymentStatus == 'failed' ? null : () => setPayment('failed'),
                              child: const Text('Mark failed'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _kv(BuildContext context, String k, String v) {
  if (v.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted))),
        Text(v, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
