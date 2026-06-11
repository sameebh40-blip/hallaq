import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/models/role.dart';
import '../../../core/routing/routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(myProfileProvider).valueOrNull?.role ?? AppUserRole.customer;
    Future<void> signOut() async {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        showDragHandle: true,
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: HallaqCard(
              glass: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Log out?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    'You can sign in again anytime.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  HallaqButton(
                    label: 'Log Out',
                    icon: Icons.logout_rounded,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ],
              ),
            ),
          );
        },
      );
      if (ok != true) return;
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go('/auth');
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          _Tile(icon: Icons.person_outline_rounded, title: 'Personal Information', onTap: () => context.push('/edit-profile')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.location_on_outlined, title: 'Addresses', onTap: () => context.push('/addresses')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.notifications_none_rounded, title: 'Notification Settings', onTap: () => context.go('/notifications')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.lock_outline_rounded, title: 'Privacy & Security', onTap: () => context.push('/privacy-security')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.credit_card_outlined, title: 'Payment Methods', onTap: () => context.push('/payment-methods')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.help_outline_rounded, title: 'Help & Support', onTap: () => context.push('/support')),
          const SizedBox(height: 10),
          _Tile(icon: Icons.info_outline_rounded, title: 'About Hallaq', onTap: () => context.push('/about')),
          if (role == AppUserRole.admin) ...[
            const SizedBox(height: 10),
            _Tile(icon: Icons.bug_report_outlined, title: 'Debug Panel', onTap: () => context.push(Routes.debugPanel)),
          ],
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: signOut,
              child: Text('Log Out', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.text, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
