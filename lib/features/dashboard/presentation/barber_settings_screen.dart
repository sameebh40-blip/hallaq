import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../auth/data/auth_repository.dart';

class BarberSettingsScreen extends ConsumerWidget {
  const BarberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                _Tile(title: 'Edit profile', onTap: () => context.push(Routes.barberManageProfile)),
                const SizedBox(height: 10),
                _Tile(title: 'Portfolio', onTap: () => context.push(Routes.barberManagePortfolio)),
                const SizedBox(height: 10),
                _Tile(title: 'My reels', onTap: () => context.push(Routes.barberManageMyReels)),
                const SizedBox(height: 10),
                _Tile(title: 'Availability', onTap: () => context.push(Routes.barberManageAvailability)),
                const SizedBox(height: 10),
                _Tile(title: 'App settings', onTap: () => context.push(Routes.settings)),
                const SizedBox(height: 10),
                _Tile(
                  title: 'Copy my UID',
                  onTap: () async {
                    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
                    if ((uid ?? '').isEmpty) return;
                    await Clipboard.setData(ClipboardData(text: uid!));
                    if (context.mounted) showSuccessSnackBar(context, 'Copied');
                  },
                ),
                const SizedBox(height: 10),
                _Tile(
                  title: 'Sign out',
                  onTap: () {
                    () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(Routes.signIn);
                    }();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _Tile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
