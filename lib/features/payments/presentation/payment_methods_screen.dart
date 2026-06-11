import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Payment Methods', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          LuxuryCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cards & Wallets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Online payments are coming soon. You can still book normally and pay in-store.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 14),
                LuxuryButton(
                  label: l10n.helpSupport,
                  variant: LuxuryButtonVariant.secondary,
                  onPressed: () => context.push('/support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          HallaqEmptyState(
            title: 'No payment methods',
            description: 'Add your first card when online payments become available.',
            imageUrl: HallaqImages.premiumMembership(variant: '01'),
          ),
        ],
      ),
    );
  }
}

