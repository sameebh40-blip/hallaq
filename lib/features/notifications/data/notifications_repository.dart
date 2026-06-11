import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class AppNotification {
  final String id;
  final String profileId;
  final String type;
  final String title;
  final String body;
  final bool read;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AppNotification(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      type: (json['type'] as String?) ?? 'generic',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      read: (json['read'] as bool?) ?? false,
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationsRepository {
  final SupabaseClient _client;

  NotificationsRepository(this._client);

  Stream<int> watchUnreadCount() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(0);
    return _client
        .from('notifications')
        .stream(primaryKey: const ['id'])
        .eq('profile_id', user.id)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length);
  }

  Future<List<AppNotification>> listMy({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load notifications', cause: e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.from('notifications').update({'read': true}).eq('id', id);
    } catch (e) {
      throw AppException('Failed to update notification', cause: e);
    }
  }

  Future<void> markAllRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('notifications').update({'read': true}).eq('profile_id', user.id).eq('read', false);
    } catch (e) {
      throw AppException('Failed to update notifications', cause: e);
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

final myNotificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  return ref.watch(notificationsRepositoryProvider).listMy();
});

final myUnreadNotificationsCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(notificationsRepositoryProvider).watchUnreadCount();
});
