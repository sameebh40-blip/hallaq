import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/product.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class CartLine {
  final CartItem item;
  final Product product;

  const CartLine({required this.item, required this.product});
}

class CartRepository {
  final SupabaseClient _client;

  CartRepository(this._client);

  Future<List<CartItem>> listMine() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final data = await _client.from('cart_items').select().eq('profile_id', user.id).order('updated_at', ascending: false);
      return (data as List).map((e) => CartItem.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load cart', cause: e);
    }
  }

  Future<List<CartLine>> listMineWithProducts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final data = await _client
          .from('cart_items')
          .select('id, profile_id, product_id, quantity, created_at, updated_at, products(*)')
          .eq('profile_id', user.id)
          .order('updated_at', ascending: false);

      return (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((m) => m['products'] is Map)
          .map(
            (m) => CartLine(
              item: CartItem.fromJson(m),
              product: Product.fromJson(Map<String, dynamic>.from(m['products'] as Map)),
            ),
          )
          .toList();
    } catch (e) {
      throw AppException('Failed to load cart', cause: e);
    }
  }

  Future<CartItem> setItem({required String productId, required int quantity}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final data = await _client
          .from('cart_items')
          .upsert({'profile_id': user.id, 'product_id': productId, 'quantity': quantity})
          .select()
          .single();
      return CartItem.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to update cart', cause: e);
    }
  }

  Future<void> removeItem(String productId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('cart_items').delete().eq('profile_id', user.id).eq('product_id', productId);
    } catch (e) {
      throw AppException('Failed to update cart', cause: e);
    }
  }

  Future<void> clear() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('cart_items').delete().eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to clear cart', cause: e);
    }
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(supabaseClientProvider));
});

final myCartProvider = FutureProvider<List<CartItem>>((ref) async {
  return ref.watch(cartRepositoryProvider).listMine();
});

final myCartLinesProvider = FutureProvider<List<CartLine>>((ref) async {
  return ref.watch(cartRepositoryProvider).listMineWithProducts();
});
