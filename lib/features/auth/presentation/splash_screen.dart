import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/role.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_mascot.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_loader.dart';
import '../../profile/data/profile_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _pulse;
  Timer? _timer;
  Timer? _retryTimer;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _timer = Timer(const Duration(milliseconds: 420), () => unawaited(_continue()));
    _retryTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _showRetry = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    _fade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!mounted) return;
    final authed = Supabase.instance.client.auth.currentSession != null;
    if (!authed) {
      context.go(Routes.auth);
      return;
    }

    final gate = await ref.read(profileRepositoryProvider).getMyGateInfoFresh();
    if (!mounted) return;
    switch (gate.role) {
      case AppUserRole.customer:
        context.go('/home');
        return;
      case AppUserRole.barber:
        context.go(Routes.barberDashboardHome);
        return;
      case AppUserRole.shopOwner:
        context.go(Routes.shopDashboardHome);
        return;
      case AppUserRole.admin:
        context.go(Routes.adminHome);
        return;
      case AppUserRole.unknown:
        context.go(Routes.completeProfile);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.background),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final a = 0.12 + (_pulse.value * 0.10);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.35),
                            radius: 1.1,
                            colors: [
                              AppTheme.gold.withValues(alpha: a),
                              AppTheme.background,
                            ],
                            stops: const [0.0, 0.82],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              PositionedDirectional(
                top: 12,
                end: 16,
                child: const LanguageSwitcher(compact: true),
              ),
              Center(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.softShadow(opacity: 0.10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, _) {
                                    final a = 0.18 + (_pulse.value * 0.16);
                                    return Container(
                                      width: 170,
                                      height: 170,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppTheme.gold.withValues(alpha: a),
                                            AppTheme.gold.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const HallaqMascot(size: 96, assetKey: 'splash_logo'),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.appName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.text,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.homeHeroSubtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            if (_showRetry) ...[
                              LuxuryButton(
                                label: l10n.tryAgain,
                                onPressed: () {
                                  setState(() => _showRetry = false);
                                  _timer?.cancel();
                                  _timer = Timer(const Duration(milliseconds: 180), () => unawaited(_continue()));
                                },
                                variant: LuxuryButtonVariant.secondary,
                              ),
                              const SizedBox(height: 14),
                            ],
                            const LuxuryLoader(size: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
