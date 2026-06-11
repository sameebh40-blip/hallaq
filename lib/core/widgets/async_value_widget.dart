import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/user_facing_error.dart';
import '../l10n/app_localizations.dart';
import 'hallaq_mascot.dart';
import 'hallaq_ui.dart';
import 'luxury_loader.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function(Object error, StackTrace stackTrace)? error;
  final Widget? loading;
  final VoidCallback? onRetry;
  final String? errorImageUrl;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading,
    this.onRetry,
    this.errorImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading ??
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HallaqMascot(size: 74),
                SizedBox(height: 14),
                LuxuryLoader(size: 26),
              ],
            ),
          ),
      error: (e, st) {
        if (error != null) return error!.call(e, st);
        final ui = userFacingError(context, e);
        final l10n = AppLocalizations.of(context);
        return Center(
          child: HallaqEmptyState(
            title: ui.title,
            description: ui.description,
            imageUrl: errorImageUrl,
            actionLabel: onRetry == null ? null : l10n.tryAgain,
            onAction: onRetry,
          ),
        );
      },
    );
  }
}
