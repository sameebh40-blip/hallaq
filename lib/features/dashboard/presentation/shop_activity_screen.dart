import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/shop_dashboard_repository.dart';

final _shopActivityAllProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).listShopActivity(limit: 200);
});

class ShopActivityScreen extends ConsumerWidget {
  const ShopActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_shopActivityAllProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Live Activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: TextButton(onPressed: () => ref.invalidate(_shopActivityAllProvider), child: const Text('Refresh')),
      ),
      child: AsyncValueWidget<List<Map<String, dynamic>>>(
        value: value,
        onRetry: () => ref.invalidate(_shopActivityAllProvider),
        data: (rows) {
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 110),
              child: HallaqCard(glass: true, child: Text('No activity yet.')),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            itemBuilder: (context, i) => _ActivityTile(row: rows[i]),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: rows.length,
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ActivityTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] ?? row['type'] ?? row['event'] ?? '').toString();
    final title = (row['title'] ?? row['message'] ?? row['description'] ?? action).toString();
    final createdRaw = row['created_at']?.toString();
    final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
    final timeLabel = created == null ? '' : timeago.format(created);

    IconData icon = Icons.bolt_rounded;
    Color color = AppTheme.gold;
    final low = action.toLowerCase();
    if (low.contains('cancel')) {
      icon = Icons.close_rounded;
      color = AppTheme.error;
    } else if (low.contains('review') || low.contains('rating')) {
      icon = Icons.star_rounded;
      color = AppTheme.gold;
    } else if (low.contains('booking') || low.contains('appointment')) {
      icon = Icons.event_available_rounded;
      color = AppTheme.success;
    } else if (low.contains('reel') || low.contains('post')) {
      icon = Icons.movie_rounded;
      color = AppTheme.gold;
    } else if (low.contains('customer')) {
      icon = Icons.person_add_alt_1_rounded;
      color = AppTheme.gold;
    } else if (low.contains('offer')) {
      icon = Icons.local_offer_rounded;
      color = AppTheme.goldDeep;
    } else if (low.contains('order')) {
      icon = Icons.shopping_bag_rounded;
      color = AppTheme.gold;
    }

    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(timeLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
