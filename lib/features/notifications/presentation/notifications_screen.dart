import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/models/role.dart';
import '../../../core/routing/routes.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(myNotificationsProvider);
    final unread = ref.watch(myUnreadNotificationsCountProvider).valueOrNull ?? 0;
    final bottomPad = 100.0 + MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        LuxuryTopBar(
          title: Text(l10n.notifications, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unread > 0)
                LuxuryIconButton(
                  icon: Icons.done_all_rounded,
                  onPressed: () async {
                    await ref.read(notificationsRepositoryProvider).markAllRead();
                    ref.invalidate(myNotificationsProvider);
                  },
                ),
              LuxuryIconButton(
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(myNotificationsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<AppNotification>>(
            value: value,
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: HallaqEmptyState(
                    title: l10n.noNotificationsTitle,
                    description: l10n.noNotificationsDescription,
                    showMascot: true,
                    actionLabel: l10n.exploreNow,
                    onAction: () => context.go('/discover'),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                itemBuilder: (context, index) => _NotificationTile(notification: items[index]),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: items.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuxuryCard(
      onTap: () async {
        if (!notification.read) {
          await ref.read(notificationsRepositoryProvider).markRead(notification.id);
          ref.invalidate(myNotificationsProvider);
        }
        final role = await ref.read(profileRepositoryProvider).getMyRoleFast();
        if (!context.mounted) return;
        final type = notification.type.trim();
        if (type == 'offer_received') {
          context.push('/offers/inbox');
          return;
        }
        if (type.contains('booking')) {
          final bookingId = (notification.data['booking_id'] as String?)?.trim();
          if (bookingId != null && bookingId.isNotEmpty) {
            context.push('/booking/$bookingId');
            return;
          }
          if (role == AppUserRole.barber) {
            context.go(Routes.barberDashboard);
            return;
          }
          if (role == AppUserRole.shopOwner) {
            context.go(Routes.shopDashboard);
            return;
          }
          context.go('/bookings');
        }
      },
      glass: true,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notification.read ? Colors.transparent : AppTheme.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
