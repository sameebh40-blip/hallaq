import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class MyReviewItem {
  final String id;
  final String targetType;
  final String targetId;
  final int rating;
  final String? text;
  final DateTime createdAt;
  final String? barberName;
  final String? shopName;

  const MyReviewItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.rating,
    required this.createdAt,
    this.text,
    this.barberName,
    this.shopName,
  });
}

class MyReviewsRepository {
  final SupabaseClient _client;

  MyReviewsRepository(this._client);

  Future<List<MyReviewItem>> listMy({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final data = await _client
          .from('reviews')
          .select(
            'id, target_type, target_id, rating, text, comment, created_at, '
            'barbers(display_name), '
            'barbershops(name)',
          )
          .eq('customer_profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      return rows.map((m) {
        final barber = m['barbers'] is Map ? Map<String, dynamic>.from(m['barbers'] as Map) : null;
        final shop = m['barbershops'] is Map ? Map<String, dynamic>.from(m['barbershops'] as Map) : null;
        final t = ((m['text'] as String?) ?? (m['comment'] as String?))?.trim();
        return MyReviewItem(
          id: m['id'] as String,
          targetType: (m['target_type'] as String?) ?? 'barber',
          targetId: (m['target_id'] as String?) ?? '',
          rating: (m['rating'] as num?)?.toInt() ?? 0,
          text: t?.isEmpty ?? true ? null : t,
          createdAt: DateTime.parse(m['created_at'] as String),
          barberName: (barber?['display_name'] as String?)?.trim(),
          shopName: (shop?['name'] as String?)?.trim(),
        );
      }).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load reviews', cause: e);
    }
  }
}

final myReviewsRepositoryProvider = Provider<MyReviewsRepository>((ref) {
  return MyReviewsRepository(ref.watch(supabaseClientProvider));
});

final myReviewsProvider = FutureProvider<List<MyReviewItem>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(myReviewsRepositoryProvider).listMy();
});

