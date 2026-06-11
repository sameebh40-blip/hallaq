import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../models/reel_comment.dart';

class ReelCommentsRepository {
  final SupabaseClient _client;

  ReelCommentsRepository(this._client);

  Future<List<ReelComment>> list(String reelId, {int limit = 50}) async {
    try {
      final data = await _client
          .from('reel_comments')
          .select('id, reel_id, profile_id, text, created_at, profiles(full_name, avatar_url)')
          .eq('reel_id', reelId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => ReelComment.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load comments', cause: e);
    }
  }

  Future<ReelComment> add({required String reelId, required String text}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final data = await _client
          .from('reel_comments')
          .insert({'reel_id': reelId, 'profile_id': user.id, 'text': text})
          .select('id, reel_id, profile_id, text, created_at, profiles(full_name, avatar_url)')
          .single();
      return ReelComment.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to comment', cause: e);
    }
  }

  Future<void> delete(String commentId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      await _client.from('reel_comments').delete().eq('id', commentId).eq('profile_id', user.id);
    } catch (e) {
      throw AppException('Failed to delete comment', cause: e);
    }
  }
}

final reelCommentsRepositoryProvider = Provider<ReelCommentsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReelCommentsRepository(client);
});

final reelCommentsProvider = FutureProvider.family<List<ReelComment>, String>((ref, reelId) async {
  return ref.watch(reelCommentsRepositoryProvider).list(reelId);
});
