import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_dashboard_repository.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const adminPanelUrl = String.fromEnvironment('ADMIN_PANEL_URL', defaultValue: 'https://admin.hallaq.com');
    final stats = ref.watch(adminStatsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Admin', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          AsyncValueWidget<Map<String, int>>(
            value: stats,
            data: (m) {
              return Column(
                children: [
                  _StatCard(title: 'Users', value: '${m['users'] ?? 0}'),
                  const SizedBox(height: 12),
                  _StatCard(title: 'Bookings', value: '${m['bookings'] ?? 0}'),
                  const SizedBox(height: 12),
                  _StatCard(title: 'Shops', value: '${m['shops'] ?? 0}'),
                  const SizedBox(height: 12),
                  _StatCard(title: 'Barbers', value: '${m['barbers'] ?? 0}'),
                  const SizedBox(height: 12),
                  _StatCard(title: 'Reels', value: '${m['reels'] ?? 0}'),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(Routes.adminCreateShop),
            child: const _Tile(title: 'Create Shop'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(Routes.adminShopClaims),
            child: const _Tile(title: 'Shop Claims'),
          ),
          const SizedBox(height: 18),
          HallaqButton(
            label: 'Open Admin Panel',
            icon: Icons.open_in_new_rounded,
            onPressed: () async {
              final uri = Uri.tryParse(adminPanelUrl);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go(Routes.signIn);
              },
              child: Text(
                'Log Out',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;

  const _Tile({required this.title});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
