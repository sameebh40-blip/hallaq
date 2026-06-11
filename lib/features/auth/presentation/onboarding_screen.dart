import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/onboarding/onboarding_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/hallaq_logo.dart';
import '../../../core/widgets/luxury_button.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    Future<void> next() async {
      await ref.read(onboardingSeenProvider.notifier).markSeen();
      if (!context.mounted) return;
      context.go('/auth/sign-up');
    }

    Future<void> goToSignIn() async {
      await ref.read(onboardingSeenProvider.notifier).markSeen();
      if (!context.mounted) return;
      context.go('/auth/sign-in');
    }

    return AuthScaffold(
      imageUrl: HallaqImages.luxuryBarberInterior(variant: '01'),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 88, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const HallaqLogo(size: 112, color: AppTheme.gold),
                            const SizedBox(height: 10),
                            Text(
                              l10n.appName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                    color: AppTheme.text,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          decoration: BoxDecoration(
                            color: AppTheme.background.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: AppTheme.softShadow(opacity: 0.12),
                          ),
                          child: Column(
                            children: [
                              LuxuryButton(
                                label: l10n.getStarted,
                                onPressed: next,
                              ),
                              const SizedBox(height: 12),
                              LuxuryButton(
                                label: l10n.signIn,
                                variant: LuxuryButtonVariant.secondary,
                                onPressed: goToSignIn,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
