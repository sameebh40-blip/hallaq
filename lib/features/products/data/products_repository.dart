import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/product.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ProductsRepository {
  final SupabaseClient _client;

  ProductsRepository(this._client);

  Future<Product?> getById(String id) async {
    try {
      final data = await _client.from('products').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return Product.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to load product', cause: e);
    }
  }

  Future<List<Product>> listForShop(String shopId, {int limit = 100}) async {
    try {
      final data = await _client
          .from('products')
          .select()
          .eq('shop_id', shopId)
          .eq('active', true)
          .eq('is_active', true)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load products', cause: e);
    }
  }

  Future<List<Product>> listForShopManagement(String shopId, {int limit = 200}) async {
    try {
      final data = await _client.from('products').select().eq('shop_id', shopId).order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load products', cause: e);
    }
  }

  Future<Product> create({
    required String shopId,
    required String name,
    String? description,
    required double price,
    int stock = 0,
    String? imageUrl,
    List<String> images = const [],
    bool active = true,
  }) async {
    try {
      final data = await _client
          .from('products')
          .insert({
            'shop_id': shopId,
            'name': name,
            'description': description,
            'price': price,
            'stock': stock,
            if (imageUrl != null) 'image_url': imageUrl,
            'images': images,
            'active': active,
          })
          .select()
          .single();
      return Product.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to create product', cause: e);
    }
  }

  Future<Product> update({
    required String id,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? imageUrl,
    List<String>? images,
    bool? active,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (stock != null) 'stock': stock,
        if (imageUrl != null) 'image_url': imageUrl,
        if (images != null) 'images': images,
        if (active != null) 'active': active,
      };
      final data = await _client.from('products').update(payload).eq('id', id).select().single();
      return Product.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to update product', cause: e);
    }
  }

  Future<void> delete({required String id}) async {
    try {
      await _client.from('products').delete().eq('id', id);
    } catch (e) {
      throw AppException('Failed to delete product', cause: e);
    }
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(supabaseClientProvider));
});

final productsForShopProvider = FutureProvider.family<List<Product>, String>((ref, shopId) async {
  return ref.watch(productsRepositoryProvider).listForShop(shopId);
});

final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) async {
  return ref.watch(productsRepositoryProvider).getById(id);
});

final shopProductsManagementProvider = FutureProvider.family<List<Product>, String>((ref, shopId) async {
  return ref.watch(productsRepositoryProvider).listForShopManagement(shopId);
});
