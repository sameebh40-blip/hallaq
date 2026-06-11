import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/responsive_center.dart';

class PreviewLandingScreen extends StatelessWidget {
  const PreviewLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Preview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: ResponsiveCenter(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 30),
          children: [
            Text(
              l10n.appName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Web preview launcher',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 22),
            HallaqButton(label: 'Customer App', onPressed: () => context.go('/')),
            const SizedBox(height: 12),
            HallaqButton(label: 'Barber Dashboard', onPressed: () => context.go('/dash/barber')),
            const SizedBox(height: 12),
            HallaqButton(label: 'Barbershop Dashboard', onPressed: () => context.go('/dash/shop')),
            const SizedBox(height: 12),
            HallaqButton(label: 'Admin Panel', onPressed: () => context.go('/dash/admin')),
            const SizedBox(height: 16),
            HallaqButton(label: 'Open Auth Screens', variant: HallaqButtonVariant.secondary, onPressed: () => context.go('/auth')),
          ],
        ),
      ),
    );
  }
}
