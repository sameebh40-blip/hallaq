import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../categories/data/categories_repository.dart';

class SearchSuggestionsRepository {
  final SupabaseClient _client;

  SearchSuggestionsRepository(this._client);

  Future<List<Map<String, dynamic>>> listPopularServices({int limit = 24}) async {
    try {
      final data = await _client
          .from('services')
          .select('name_en,name_ar,category,is_popular,created_at')
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('is_popular', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load services', cause: e);
    }
  }
}

final searchSuggestionsRepositoryProvider = Provider<SearchSuggestionsRepository>((ref) {
  return SearchSuggestionsRepository(ref.watch(supabaseClientProvider));
});

final searchCategoriesProvider = categoriesProvider;

final popularServiceQueriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(searchSuggestionsRepositoryProvider);
  final rows = await repo.listPopularServices(limit: 24);
  final lang = (ref.watch(localeControllerProvider)?.languageCode ?? 'en');

  final out = <String>[];
  final seen = <String>{};
  for (final r in rows) {
    final nameEn = (r['name_en'] as String?) ?? '';
    final nameAr = (r['name_ar'] as String?) ?? '';
    final category = (r['category'] as String?) ?? '';
    final isAr = lang.toLowerCase().startsWith('ar');
    final primary = (isAr ? nameAr : nameEn).trim();
    final fallback = (isAr ? nameEn : nameAr).trim();
    final label = primary.isNotEmpty ? primary : (fallback.isNotEmpty ? fallback : category.trim());
    if (label.isEmpty) continue;
    final key = label.toLowerCase();
    if (!seen.add(key)) continue;
    out.add(label);
  }
  return out;
});
