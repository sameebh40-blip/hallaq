import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.helpSupport, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          _Tile(
            icon: Icons.chat_bubble_rounded,
            title: 'WhatsApp',
            subtitle: '+973 0000 0000',
            onTap: () => _launch(context, Uri.parse('https://wa.me/97300000000')),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.alternate_email_rounded,
            title: 'Email',
            subtitle: 'support@hallaq.com',
            onTap: () => _launch(context, Uri.parse('mailto:support@hallaq.com')),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.policy_rounded,
            title: 'Privacy & Terms',
            subtitle: 'Read policies and app information',
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.gold.withValues(alpha: 0.12),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

Future<void> _launch(BuildContext context, Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e);
  }
}
