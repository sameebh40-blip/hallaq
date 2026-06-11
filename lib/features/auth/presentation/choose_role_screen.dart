import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/role.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/widgets/responsive_center.dart';

class ChooseRoleScreen extends ConsumerStatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  ConsumerState<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends ConsumerState<ChooseRoleScreen> {
  bool _busy = false;

  Future<void> _submit(AppUserRole role) async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).upsertMyProfile(role: role);
      if (!mounted) return;
      context.go(Routes.splash);
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final items = <_RoleItem>[
      _RoleItem(
        role: AppUserRole.customer,
        icon: Icons.person_outline_rounded,
        title: l10n.roleCustomer,
        subtitle: l10n.chooseRoleCustomerSubtitle,
        imageUrl: HallaqImages.customerAvatar(variant: '01'),
      ),
      _RoleItem(
        role: AppUserRole.barber,
        icon: Icons.content_cut_rounded,
        title: l10n.roleBarber,
        subtitle: l10n.chooseRoleBarberSubtitle,
        imageUrl: HallaqImages.professionalBarberPortrait(variant: '02'),
      ),
      _RoleItem(
        role: AppUserRole.shopOwner,
        icon: Icons.storefront_rounded,
        title: l10n.roleShopOwner,
        subtitle: l10n.chooseRoleShopOwnerSubtitle,
        imageUrl: HallaqImages.luxuryBarberInterior(variant: '04'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 390,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
                child: Row(
                  children: [
                    LuxuryIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: _busy ? null : () => context.pop(),
                    ),
                    const Spacer(),
                    const LanguageSwitcher(compact: true),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
                  children: [
                    Text(
                      l10n.authWelcomeTitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.chooseRoleTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.chooseRoleSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    ...items.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RoleCard(
                          item: e,
                          busy: _busy,
                          onTap: () => _submit(e.role),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy ? null : () => context.go(Routes.splash),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          l10n.skip,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleItem {
  final AppUserRole role;
  final IconData icon;
  final String title;
  final String subtitle;
  final String imageUrl;

  const _RoleItem({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });
}

class _RoleCard extends StatelessWidget {
  final _RoleItem item;
  final VoidCallback onTap;
  final bool busy;

  const _RoleCard({
    required this.item,
    required this.onTap,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: busy ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.gold.withValues(alpha: 0.14),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
            ),
            child: Icon(item.icon, size: 22, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LuxuryNetworkImage(
              imageUrl: null,
              fallbackUrl: item.imageUrl,
              width: 62,
              height: 62,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
