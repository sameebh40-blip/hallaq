import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../auth/data/auth_repository.dart';
import '../../barber/data/barber_repository.dart';

class BarberMoreScreen extends ConsumerWidget {
  const BarberMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barber = ref.watch(myBarberProvider);

    Future<void> logout() async {
      await ref.read(authRepositoryProvider).signOut();
      if (!context.mounted) return;
      context.go(Routes.auth);
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: const SizedBox.shrink(),
        title: Text('More', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: IconButton(onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none_rounded), color: AppTheme.text),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          AsyncValueWidget(
            value: barber,
            data: (b) {
              return Row(
                children: [
                  HallaqAvatar(imageUrl: b?.avatarUrl, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b?.displayName ?? 'Barber', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Manage your business', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _MoreTile(label: 'Profile', icon: Icons.person_outline_rounded, onTap: () => context.push(Routes.barberManageProfile)),
          _MoreTile(label: 'Services', icon: Icons.design_services_outlined, onTap: () => context.push(Routes.barberManageServices)),
          _MoreTile(label: 'Portfolio', icon: Icons.photo_library_outlined, onTap: () => context.push(Routes.barberManagePortfolio)),
          _MoreTile(label: 'Reviews', icon: Icons.star_border_rounded, onTap: () => context.push(Routes.barberManageReviews)),
          _MoreTile(label: 'Reels', icon: Icons.video_collection_outlined, onTap: () => context.push(Routes.barberManageMyReels)),
          _MoreTile(label: 'Earnings', icon: Icons.payments_outlined, onTap: () => context.push(Routes.barberManageEarnings)),
          _MoreTile(label: 'Availability', icon: Icons.calendar_month_outlined, onTap: () => context.push(Routes.barberManageAvailability)),
          _MoreTile(label: 'Notifications', icon: Icons.notifications_none_rounded, onTap: () => context.push('/notifications')),
          _MoreTile(label: 'Settings', icon: Icons.settings_outlined, onTap: () => context.push(Routes.barberManageSettings)),
          _MoreTile(label: 'Help', icon: Icons.help_outline_rounded, onTap: () => context.push('/support')),
          const SizedBox(height: 14),
          HallaqButton(label: 'Logout', onPressed: logout, variant: HallaqButtonVariant.secondary),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MoreTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.gold.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: AppTheme.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
