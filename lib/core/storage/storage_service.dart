import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../supabase/supabase_client_provider.dart';

({String bucket, String path})? parseSupabasePublicStorageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final publicIndex = segments.indexOf('public');
  if (publicIndex == -1) return null;
  if (publicIndex + 1 >= segments.length) return null;
  final bucket = segments[publicIndex + 1];
  final pathSegments = segments.skip(publicIndex + 2).toList(growable: false);
  if (bucket.isEmpty || pathSegments.isEmpty) return null;
  return (bucket: bucket, path: pathSegments.join('/'));
}

class _SignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;

  const _SignedUrlCacheEntry({required this.url, required this.expiresAt});
}

class StorageService {
  final SupabaseClient _client;
  final Map<String, _SignedUrlCacheEntry> _signedUrlCache = {};

  StorageService(this._client);

  String publicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) async {
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: upsert),
          );
      return path;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('invalid size') || message.contains('file too large') || message.contains('payload too large')) {
        throw const AppException('File is too large. Please choose a smaller file.');
      }
      throw AppException('Failed to upload file ($bucket/$path)', cause: e);
    }
  }

  Future<String> signedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    final cacheKey = '$bucket:$path';
    final now = DateTime.now();
    final cached = _signedUrlCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(now.add(const Duration(seconds: 60)))) {
      return cached.url;
    }
    try {
      final result = await _client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
      _signedUrlCache[cacheKey] = _SignedUrlCacheEntry(
        url: result,
        expiresAt: now.add(Duration(seconds: expiresInSeconds)),
      );
      return result;
    } catch (e) {
      throw AppException('Failed to create signed URL ($bucket/$path)', cause: e);
    }
  }

  Future<void> removeObject({required String bucket, required String path}) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw AppException('Failed to delete file ($bucket/$path)', cause: e);
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});
