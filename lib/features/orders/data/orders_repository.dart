import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/order.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class OrderItemView {
  final OrderItem item;
  final String productName;
  final List<String> productImages;

  const OrderItemView({required this.item, required this.productName, required this.productImages});
}

class OrdersRepository {
  final SupabaseClient _client;

  OrdersRepository(this._client);

  Future<List<Order>> listMine({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final data = await _client.from('orders').select().eq('customer_profile_id', user.id).order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load orders', cause: e);
    }
  }

  Future<Order?> getById(String orderId) async {
    try {
      final data = await _client.from('orders').select().eq('id', orderId).maybeSingle();
      if (data == null) return null;
      return Order.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to load order', cause: e);
    }
  }

  Future<List<Order>> listForShop(String shopId, {int limit = 50}) async {
    try {
      final data = await _client.from('orders').select().eq('shop_id', shopId).order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load orders', cause: e);
    }
  }

  Future<List<OrderItem>> listItems(String orderId) async {
    try {
      final data = await _client.from('order_items').select().eq('order_id', orderId).order('created_at', ascending: true);
      return (data as List).map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load order items', cause: e);
    }
  }

  Future<List<OrderItemView>> listItemsWithProducts(String orderId) async {
    try {
      final data = await _client
          .from('order_items')
          .select('id, order_id, product_id, quantity, unit_price, line_total, created_at, products(name, images)')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      return (data as List).map((e) {
        final m = Map<String, dynamic>.from(e);
        final p = m['products'] is Map ? Map<String, dynamic>.from(m['products'] as Map) : const <String, dynamic>{};
        final images = (p['images'] as List?)?.cast<String>() ?? const <String>[];
        return OrderItemView(
          item: OrderItem.fromJson(m),
          productName: (p['name'] as String?) ?? 'Product',
          productImages: images,
        );
      }).toList();
    } catch (e) {
      throw AppException('Failed to load order items', cause: e);
    }
  }

  Future<Order> createOrder({
    required String shopId,
    required List<({String productId, int quantity})> items,
    Map<String, dynamic> deliveryAddress = const <String, dynamic>{},
    String paymentMethod = 'cod',
    String? customerNote,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    if (items.isEmpty) throw const AppException('Empty order');

    try {
      final orderData = await _client
          .from('orders')
          .insert({
            'customer_profile_id': user.id,
            'shop_id': shopId,
            'payment_method': paymentMethod,
            'delivery_address': deliveryAddress,
            'customer_note': customerNote,
          })
          .select()
          .single();

      final order = Order.fromJson(Map<String, dynamic>.from(orderData));

      await _client.from('order_items').insert(
            items
                .map(
                  (i) => {
                    'order_id': order.id,
                    'product_id': i.productId,
                    'quantity': i.quantity,
                    'unit_price': 0,
                    'line_total': 0,
                  },
                )
                .toList(),
          );

      final refreshed = await _client.from('orders').select().eq('id', order.id).single();
      return Order.fromJson(Map<String, dynamic>.from(refreshed));
    } catch (e) {
      throw AppException('Failed to create order', cause: e);
    }
  }

  Future<void> updateStatus({required String orderId, required String status}) async {
    try {
      await _client.from('orders').update({'status': status}).eq('id', orderId);
    } catch (e) {
      throw AppException('Failed to update order', cause: e);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(supabaseClientProvider));
});

final myOrdersProvider = FutureProvider<List<Order>>((ref) async {
  return ref.watch(ordersRepositoryProvider).listMine();
});

final orderByIdProvider = FutureProvider.family<Order?, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).getById(orderId);
});

final orderItemsProvider = FutureProvider.family<List<OrderItem>, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).listItems(orderId);
});

final orderItemsViewProvider = FutureProvider.family<List<OrderItemView>, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).listItemsWithProducts(orderId);
});
