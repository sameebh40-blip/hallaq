import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../models/home_banner.dart';

class HomeRepository {
  final SupabaseClient _client;

  HomeRepository(this._client);

  Future<List<HomeBanner>> listBanners({int limit = 10}) async {
    try {
      final data = await _client.from('advertisements').select().eq('active', true).order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => HomeBanner.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load banners', cause: e);
    }
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(supabaseClientProvider));
});

final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  return ref.watch(homeRepositoryProvider).listBanners(limit: 10);
});

