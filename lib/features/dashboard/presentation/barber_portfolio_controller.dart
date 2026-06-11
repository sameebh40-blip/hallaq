import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../barber/data/barber_repository.dart';
import '../../portfolio/data/portfolio_repository.dart';

class BarberPortfolioController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _logIfError({required String action, Map<String, dynamic>? meta}) {
    final err = state.error;
    if (err == null) return;
    ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
          page: 'barber_portfolio',
          action: action,
          error: err,
          stackTrace: state.stackTrace?.toString(),
          meta: meta,
        );
  }

  Future<void> addImage({required Uint8List bytes, String? caption, String? category}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final barber = await ref.read(barberRepositoryProvider).getMyBarber();
      if (barber == null) throw const AppException('No barber assigned to this account');

      final uploaded = await ref.read(mediaServiceProvider).uploadImage(
            bucket: 'portfolio',
            pathPrefix: 'barbers/${barber.id}',
            bytes: bytes,
          );

      await ref.read(portfolioRepositoryProvider).create(
            ownerType: 'barber',
            ownerId: barber.id,
            mediaType: 'image',
            mediaPath: uploaded.path,
            thumbnailPath: uploaded.thumbnailPath,
            caption: caption,
            category: category,
          );

      ref.invalidate(portfolioForBarberProvider(barber.id));
    });
    _logIfError(action: 'upload_portfolio_image', meta: const {'bucket': 'portfolio'});
  }

  Future<void> deleteItem({required String itemId, required String barberId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(portfolioRepositoryProvider).delete(id: itemId);
      ref.invalidate(portfolioForBarberProvider(barberId));
    });
  }
}

final barberPortfolioControllerProvider = AsyncNotifierProvider.autoDispose<BarberPortfolioController, void>(BarberPortfolioController.new);
