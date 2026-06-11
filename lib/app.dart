import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/l10n/app_localizations.dart';
import 'core/analytics/analytics_outbox.dart';
import 'core/brand/brand_assets_controller.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/network/network_status.dart';
import 'core/push/push_bootstrap.dart';
import 'core/supabase/supabase_client_provider.dart';
import 'core/supabase/realtime_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/locale_controller.dart';
import 'features/profile/data/profile_repository.dart';

class HallaqApp extends ConsumerStatefulWidget {
  const HallaqApp({super.key});

  @override
  ConsumerState<HallaqApp> createState() => _HallaqAppState();
}

class _HallaqAppState extends ConsumerState<HallaqApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);
    ref.watch(realtimeBootstrapProvider);
    ref.watch(pushBootstrapProvider);
    ref.watch(networkStatusProvider);
    ref.watch(analyticsOutboxFlusherProvider);
    ref.watch(brandAssetsControllerProvider);

    ref.listen(authStateChangesProvider, (prev, next) {
      final state = next.valueOrNull;
      if (state == null) return;
      ref.read(profileRepositoryProvider).clearRoleCache();
      if (state.event == AuthChangeEvent.passwordRecovery) {
        router.go(Routes.resetPassword);
      }
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      routerConfig: router,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final c = child ?? const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopFrame = constraints.maxWidth >= 520;
            if (!isDesktopFrame) return c;
            final frameWidth = constraints.maxWidth >= 900 ? 430.0 : 420.0;
            final frameMarginY = 16.0;
            final frameHeight = constraints.maxHeight.isFinite
                ? ((constraints.maxHeight - (frameMarginY * 2)) > 0 ? (constraints.maxHeight - (frameMarginY * 2)) : constraints.maxHeight)
                : null;
            return ColoredBox(
              color: AppTheme.background,
              child: Center(
                child: Container(
                  width: frameWidth,
                  height: frameHeight,
                  margin: EdgeInsets.symmetric(vertical: frameMarginY),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.softShadow(opacity: 0.12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: c,
                  ),
                ),
              ),
            );
          },
        );
      },
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (locale != null) return locale;
        if (deviceLocale == null) return supportedLocales.first;
        for (final supported in supportedLocales) {
          if (supported.languageCode == deviceLocale.languageCode) return supported;
        }
        return supportedLocales.first;
      },
    );
  }
}
