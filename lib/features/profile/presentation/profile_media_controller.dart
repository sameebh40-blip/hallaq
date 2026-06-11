import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../data/profile_repository.dart';

class ProfileMediaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'profile_media',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> updateAvatar({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw const AppException('Not authenticated');

      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final previousPath = (current?.avatarPath ?? '').trim();
      if (previousPath.isNotEmpty) {
        await ref.read(storageServiceProvider).removeObject(bucket: 'avatars', path: previousPath);
      } else {
        final previousUrl = (current?.avatarUrl ?? '').trim();
        if (previousUrl.isNotEmpty) {
          final parsed = parseSupabasePublicStorageUrl(previousUrl);
          if (parsed != null && parsed.bucket == 'avatars' && parsed.path.startsWith('${user.id}/')) {
            await ref.read(storageServiceProvider).removeObject(bucket: parsed.bucket, path: parsed.path);
          }
        }
      }

      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'avatars',
            pathPrefix: user.id,
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 1,
              maxWidth: 512,
              maxHeight: 512,
            ),
            uploadThumbnail: false,
          );

      final publicUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: 'avatars', path: stored.path);
      await repo.upsertMyProfile(avatarPath: stored.path, avatarUrl: publicUrl);
      ref.invalidate(myProfileProvider);
    });
    _logIfError(action: 'upload_avatar', meta: const {'bucket': 'avatars'});
  }
  Future<void> updateCover({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw const AppException('Not authenticated');


      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final previousPath = (current?.coverPath ?? '').trim();
      final previousUrl = (current?.coverUrl ?? '').trim();
      final parsed = previousUrl.isNotEmpty ? parseSupabasePublicStorageUrl(previousUrl) : null;
      if (parsed != null && parsed.path.startsWith('${user.id}/')) {
        await ref.read(storageServiceProvider).removeObject(bucket: parsed.bucket, path: parsed.path);
      } else if (previousPath.isNotEmpty) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'profile-covers', path: previousPath);
        } catch (_) {}
      }

      const bucket = 'profile-covers';
      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: bucket,
            pathPrefix: user.id,
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 16 / 9,
              maxWidth: 1280,
              maxHeight: 720,
            ),
            uploadThumbnail: false,
          );

      final publicUrl = ref.read(mediaServiceProvider).publicUrlFor(bucket: bucket, path: stored.path);
      await repo.upsertMyProfile(coverPath: stored.path, coverUrl: publicUrl);
      ref.invalidate(myProfileProvider);
    });
    _logIfError(action: 'upload_cover', meta: const {'bucket': 'profile-covers'});
  }

  Future<void> clearAvatar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw const AppException('Not authenticated');

      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final previousPath = (current?.avatarPath ?? '').trim();
      if (previousPath.isNotEmpty) {
        await ref.read(storageServiceProvider).removeObject(bucket: 'avatars', path: previousPath);
      } else {
        final previousUrl = (current?.avatarUrl ?? '').trim();
        if (previousUrl.isNotEmpty) {
          final parsed = parseSupabasePublicStorageUrl(previousUrl);
          if (parsed != null && parsed.bucket == 'avatars' && parsed.path.startsWith('${user.id}/')) {
            await ref.read(storageServiceProvider).removeObject(bucket: parsed.bucket, path: parsed.path);
          }
        }
      }

      await repo.upsertMyProfile(avatarPath: '', avatarUrl: '');
      ref.invalidate(myProfileProvider);
    });
    _logIfError(action: 'clear_avatar', meta: const {'bucket': 'avatars'});
  }

  Future<void> clearCover() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw const AppException('Not authenticated');

      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final previousPath = (current?.coverPath ?? '').trim();
      final previousUrl = (current?.coverUrl ?? '').trim();
      final parsed = previousUrl.isNotEmpty ? parseSupabasePublicStorageUrl(previousUrl) : null;
      if (parsed != null && parsed.path.startsWith('${user.id}/')) {
        await ref.read(storageServiceProvider).removeObject(bucket: parsed.bucket, path: parsed.path);
      } else if (previousPath.isNotEmpty) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'profile-covers', path: previousPath);
        } catch (_) {}
      }

      await repo.upsertMyProfile(coverPath: '', coverUrl: '');
      ref.invalidate(myProfileProvider);
    });
    _logIfError(action: 'clear_cover', meta: const {'bucket': 'profile-covers'});
  }

  Future<void> updateDetails({required String fullName, required String phone}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).upsertMyProfile(
            fullName: fullName.trim(),
            phone: phone.trim(),
          );
      ref.invalidate(myProfileProvider);
    });
  }
}

final profileMediaControllerProvider = AsyncNotifierProvider<ProfileMediaController, void>(ProfileMediaController.new);
