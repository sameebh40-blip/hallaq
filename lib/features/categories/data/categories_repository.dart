import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/category.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class CategoriesRepository {
  final SupabaseClient _client;

  CategoriesRepository(this._client);

  Future<List<Category>> listCategories({int limit = 50}) async {
    try {
      final data = await _client.from('categories').select().order('created_at', ascending: true).limit(limit);
      return (data as List).map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load categories', cause: e);
    }
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(categoriesRepositoryProvider).listCategories(limit: 50);
});

