import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand/brand_assets_controller.dart';
import '../../../core/models/barber_public_stats.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../auth/data/auth_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../trending/data/trending_repository.dart';

class BarberProfileTab extends ConsumerWidget {
  const BarberProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(myBarberProvider);

    Future<void> logout() async {
      await ref.read(authRepositoryProvider).signOut();
      if (!context.mounted) return;
      context.go(Routes.auth);
    }

    return AsyncValueWidget(
      value: barberValue,
      data: (barber) {
        if (barber == null) {
          return const Center(
            child: HallaqEmptyState(
              title: 'No barber profile',
              description: 'This account is not linked to a barber yet.',
              compact: true,
              showMascot: true,
            ),
          );
        }

        final coverFallback = ref.watch(brandAssetUrlProvider('default_barber_cover'))?.trim() ?? '';
        final cover = (barber.coverUrl ?? '').trim();

        final statsValue = ref.watch(barberPublicStatsProvider(barber.id));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: LuxuryNetworkImage(
                      imageUrl: cover,
                      fallbackUrl: coverFallback,
                      bucket: 'barber-images',
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.push(Routes.barberManageSettings),
                        icon: const Icon(Icons.menu_rounded),
                        color: Colors.white,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_none_rounded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -36,
                  left: 16,
                  child: HallaqAvatar(imageUrl: barber.avatarUrl, size: 72),
                ),
              ],
            ),
            const SizedBox(height: 46),
            Row(
              children: [
                Expanded(
                  child: Text(
                    barber.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (barber.badgeVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
                    ),
                    child: Text('Verified', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if ((barber.area ?? '').trim().isNotEmpty) barber.area!.trim(),
                if ((barber.specialty ?? '').trim().isNotEmpty) barber.specialty!.trim(),
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            AsyncValueWidget<BarberPublicStats?>(
              value: statsValue,
              data: (s) {
                return Row(
                  children: [
                    Expanded(child: _MiniStat(label: 'Rating', value: barber.ratingAvg.toStringAsFixed(1))),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(label: 'Reviews', value: '${barber.reviewsCount}')),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(label: 'Followers', value: '${barber.followersCount}')),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(label: 'Bookings', value: '${s?.totalBookings ?? 0}')),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            HallaqCard(
              glass: true,
              child: Column(
                children: [
                  _MenuTile(label: 'Edit Profile', icon: Icons.edit_outlined, onTap: () => context.push(Routes.barberManageProfile)),
                  _MenuTile(label: 'Working Hours', icon: Icons.calendar_month_outlined, onTap: () => context.push(Routes.barberManageAvailability)),
                  _MenuTile(label: 'Services', icon: Icons.design_services_outlined, onTap: () => context.push(Routes.barberManageServices)),
                  _MenuTile(label: 'My Portfolio', icon: Icons.photo_library_outlined, onTap: () => context.push(Routes.barberManagePortfolio)),
                  _MenuTile(label: 'Earnings & Payouts', icon: Icons.payments_outlined, onTap: () => context.push(Routes.barberManageEarnings)),
                  _MenuTile(label: 'Reviews', icon: Icons.star_border_rounded, onTap: () => context.push(Routes.barberManageReviews)),
                  _MenuTile(label: 'Clients', icon: Icons.people_outline_rounded, onTap: () => context.push(Routes.barberManageClients)),
                  _MenuTile(label: 'QR Code', icon: Icons.qr_code_rounded, onTap: () => context.push(Routes.barberQrCenter)),
                  _MenuTile(label: 'Offers', icon: Icons.local_offer_outlined, onTap: () => context.push(Routes.barberManageOffers)),
                  _MenuTile(label: 'Settings', icon: Icons.settings_outlined, onTap: () => context.push(Routes.barberManageSettings)),
                  _MenuTile(label: 'Help', icon: Icons.help_outline_rounded, onTap: () => context.push('/support')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            HallaqButton(label: 'Logout', onPressed: logout, variant: HallaqButtonVariant.secondary),
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
