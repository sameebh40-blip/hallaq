import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class HaircutHistoryItem {
  final String id;
  final String profileId;
  final String? barberId;
  final DateTime cutDate;
  final String? styleName;
  final String? notes;
  final List<String> photoUrls;

  const HaircutHistoryItem({
    required this.id,
    required this.profileId,
    required this.cutDate,
    required this.photoUrls,
    this.barberId,
    this.styleName,
    this.notes,
  });

  factory HaircutHistoryItem.fromJson(Map<String, dynamic> json) {
    final list = (json['photo_urls'] as List?)?.cast<String>() ?? const <String>[];
    return HaircutHistoryItem(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      barberId: json['barber_id'] as String?,
      cutDate: DateTime.parse((json['cut_date'] as String)),
      styleName: json['style_name'] as String?,
      notes: json['notes'] as String?,
      photoUrls: list,
    );
  }
}

class HaircutHistoryRepository {
  final SupabaseClient _client;
  final StorageService _storage;

  HaircutHistoryRepository(this._client, this._storage);

  Future<List<HaircutHistoryItem>> listMine() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final data = await _client
          .from('haircut_history')
          .select()
          .eq('profile_id', user.id)
          .order('cut_date', ascending: false);
      return (data as List).map((e) => HaircutHistoryItem.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      throw AppException('Failed to load haircut history', cause: e);
    }
  }

  Future<void> add({
    required DateTime cutDate,
    String? styleName,
    String? notes,
    List<XFile> photos = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');

    final photoUrls = <String>[];
    for (final p in photos) {
      final bytes = await p.readAsBytes();
      final ext = p.name.split('.').last;
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storedPath = await _storage.uploadBytes(
        bucket: 'haircut-history',
        path: path,
        bytes: bytes,
        contentType: p.mimeType,
      );
      photoUrls.add(storedPath);
    }

    try {
      await _client.from('haircut_history').insert({
        'profile_id': user.id,
        'cut_date': DateTime(cutDate.year, cutDate.month, cutDate.day).toIso8601String().split('T').first,
        'style_name': styleName,
        'notes': notes,
        'photo_urls': photoUrls,
      });
    } catch (e) {
      throw AppException('Failed to add haircut history', cause: e);
    }
  }
}

final haircutHistoryRepositoryProvider = Provider<HaircutHistoryRepository>((ref) {
  return HaircutHistoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});

final myHaircutHistoryProvider = FutureProvider<List<HaircutHistoryItem>>((ref) async {
  return ref.watch(haircutHistoryRepositoryProvider).listMine();
});
