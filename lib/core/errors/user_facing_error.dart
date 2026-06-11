import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'last_error.dart';
import '../l10n/app_localizations.dart';
import 'system_logs_repository.dart';

class UserFacingError {
  final String title;
  final String description;

  const UserFacingError({required this.title, required this.description});
}

UserFacingError userFacingError(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is AppException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) {
      if (msg.toLowerCase().contains('failed to load availability')) {
        final d = _availabilityDescription(context, error.cause);
        return UserFacingError(
          title: l10n.errorAvailabilityTitle,
          description: d ?? l10n.errorAvailabilityGeneric,
        );
      }
      if (msg.toLowerCase().contains('offline')) {
        return UserFacingError(
          title: l10n.errorOfflineTitle,
          description: l10n.errorOfflineDescription,
        );
      }
      return UserFacingError(title: l10n.somethingWentWrongTitle, description: _humanize(context, msg));
    }
  }
  return UserFacingError(
    title: l10n.somethingWentWrongTitle,
    description: l10n.somethingWentWrongDescription,
  );
}

String userFacingMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  const debugPrimary = bool.fromEnvironment('SUPABASE_DEBUG', defaultValue: false);
  const debugFallback = bool.fromEnvironment('NEXT_PUBLIC_SUPABASE_DEBUG', defaultValue: false);
  const debugDefines = debugPrimary || debugFallback;
  final debug = kDebugMode || debugDefines;
  if (error is AppException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return _humanize(context, msg);
  }
  if (debug) {
    final raw = error.toString().trim();
    if (raw.isNotEmpty) return raw;
  }
  final raw = error.toString().trim();
  if (raw.isEmpty) return l10n.genericError;
  return _humanize(context, raw);
}

void showErrorSnackBar(BuildContext context, Object error) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(lastErrorProvider.notifier).state = error;
  final page = _routeForLogs(context) ?? 'app';
  final l10n = AppLocalizations.of(context);
  container.read(systemLogsRepositoryProvider).logErrorUnawaited(
        page: page,
        action: 'ui_error',
        error: error,
        severity: 'error',
        stackTrace: _errorDetails(error),
        meta: {
          'user_message': userFacingMessage(context, error),
        },
      );
  final message = userFacingMessage(context, error);
  final details = _errorDetails(error);
  final showDetails = details.trim().isNotEmpty && details.trim() != message.trim();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: showDetails
          ? SnackBarAction(
              label: l10n.errorDetailsAction,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(l10n.errorDetailsTitle),
                      content: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(child: SelectableText(details)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: details));
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: Text(l10n.copy),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.close),
                        ),
                      ],
                    );
                  },
                );
              },
            )
          : null,
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  final msg = message.trim();
  if (msg.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

String _humanize(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context);
  final lower = message.toLowerCase();
  if (lower.contains('offline')) return l10n.errorOfflineDescription;
  if (lower.contains('bucket not found')) return l10n.errorStorageBucketMissing;
  if (lower.contains('permission denied') || lower.contains('row-level security') || lower.contains('forbidden')) return l10n.errorPermissionDenied;
  if (lower.contains('not authenticated') || lower.contains('jwt') || lower.contains('session')) return l10n.errorSessionExpired;
  if (lower.contains('invalid google maps')) return l10n.errorInvalidGoogleMapsLink;
  if (lower.contains('missing required field')) return l10n.errorMissingRequiredField;
  if (lower.contains('unsupported image format')) return l10n.errorInvalidImageType;
  if (lower.contains('invalid size') || lower.contains('file too large') || lower.contains('too large')) return l10n.errorFileTooLarge;
  if (lower.contains('upload')) return l10n.errorUploadFailed;
  if (lower.contains('update') || lower.contains('save')) return l10n.errorSaveFailed;
  if (lower.contains('failed to fetch')) return l10n.errorConnection;
  if (lower.contains('socketexception')) return l10n.errorOfflineDescription;
  if (lower.contains('cors') || lower.contains('origin')) return l10n.errorConnection;
  if (lower.contains('failed to load availability')) return l10n.errorAvailabilityGeneric;
  return message;
}

String? _availabilityDescription(BuildContext context, Object? cause) {
  final l10n = AppLocalizations.of(context);
  if (cause == null) return null;
  if (cause is TimeoutException) return l10n.errorAvailabilityTimeout;
  final s = cause.toString().toLowerCase();
  if (s.contains('failed to fetch') || s.contains('socketexception') || s.contains('cors') || s.contains('origin')) {
    return l10n.errorConnection;
  }
  if (cause is PostgrestException) {
    final code = (cause.code ?? '').trim().toUpperCase();
    final msg = (cause.message).toLowerCase();
    final details = (cause.details ?? '').toString().toLowerCase();
    final hint = (cause.hint ?? '').toString().toLowerCase();

    if (code == 'PGRST202' || msg.contains('could not find the function') || details.contains('could not find the function')) {
      return l10n.errorAvailabilityMissingRpc;
    }
    if (code == '42501' || msg.contains('permission denied') || details.contains('permission denied') || msg.contains('row-level security')) {
      return l10n.errorAvailabilityPermission;
    }
    if (msg.contains('jwt') || msg.contains('not authenticated') || details.contains('jwt') || hint.contains('jwt')) {
      return l10n.errorSessionExpired;
    }
  }
  return null;
}

String? _routeForLogs(BuildContext context) {
  try {
    return GoRouter.of(context).routeInformationProvider.value.uri.toString();
  } catch (_) {
    return null;
  }
}

String _errorDetails(Object error) {
  if (error is AppException) {
    final msg = error.message.trim();
    final cause = error.cause;
    if (cause == null) return msg;
    return '$msg\n\n$cause';
  }
  return error.toString();
}
