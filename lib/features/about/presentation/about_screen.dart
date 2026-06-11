import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final points = [
      ('🇧🇭', l10n.builtInBahrain),
      ('💈', l10n.supportingLocalBarbers),
      ('🔒', l10n.secureBookingExperience),
      ('⭐️', l10n.verifiedProfessionals),
      ('🚀', l10n.modernDiscoveryPlatform),
    ];

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.aboutHallaq, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          HallaqCard(
            glass: true,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LuxuryNetworkImage(
                        imageUrl: null,
                        fallbackUrl: HallaqImages.aboutHero(),
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 16,
                      end: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                            l10n.aboutHallaq,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HallaqCard(
                glass: true,
                child: Row(
                  children: [
                    Text(p.$1, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.$2, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
