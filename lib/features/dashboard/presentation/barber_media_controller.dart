import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../barber/data/barber_repository.dart';

class BarberMediaController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'barber_media',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> updateAvatar({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');

      final previousPath = (barber.avatarPath ?? '').trim();
      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'barber-images',
            pathPrefix: 'barbers/${barber.id}',
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 1,
              maxWidth: 512,
              maxHeight: 512,
            ),
            uploadThumbnail: false,
          );

      await ref.read(barberRepositoryProvider).updateBarber(barberId: barber.id, avatarPath: stored.path);
      if (previousPath.isNotEmpty && previousPath != stored.path) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'barber-images', path: previousPath);
        } catch (_) {}
      }
      ref.invalidate(myBarberProvider);
      ref.invalidate(trendingBarbersProvider);
    });
    _logIfError(action: 'upload_avatar', meta: const {'bucket': 'barber-images'});
  }

  Future<void> updateCover({required Uint8List bytes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');

      final previousPath = (barber.coverPath ?? '').trim();
      final stored = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'barber-images',
            pathPrefix: 'barbers/${barber.id}',
            bytes: bytes,
            options: const MediaImageProcessOptions(
              cropAspectRatio: 16 / 9,
              maxWidth: 1280,
              maxHeight: 720,
            ),
            uploadThumbnail: false,
          );

      await ref.read(barberRepositoryProvider).updateBarber(barberId: barber.id, coverPath: stored.path);
      if (previousPath.isNotEmpty && previousPath != stored.path) {
        try {
          await ref.read(storageServiceProvider).removeObject(bucket: 'barber-images', path: previousPath);
        } catch (_) {}
      }
      ref.invalidate(myBarberProvider);
      ref.invalidate(trendingBarbersProvider);
    });
    _logIfError(action: 'upload_cover', meta: const {'bucket': 'barber-images'});
  }

  Future<void> updateDetails({required String displayName, required String specialty, required String bio, bool? homeService}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');
      await ref.read(barberRepositoryProvider).updateBarber(
            barberId: barber.id,
            displayName: displayName,
            specialty: specialty,
            bio: bio,
            homeService: homeService,
          );
      ref.invalidate(myBarberProvider);
      ref.invalidate(trendingBarbersProvider);
    });
  }
}

final barberMediaControllerProvider = AsyncNotifierProvider.autoDispose<BarberMediaController, void>(BarberMediaController.new);
