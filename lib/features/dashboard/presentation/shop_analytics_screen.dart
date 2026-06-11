import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../payments/data/earnings_repository.dart';
import '../../shop/data/shop_repository.dart';

final _shopAnalyticsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const [];
  return ref.watch(earningsRepositoryProvider).listShopDaily(shop.id, days: 30);
});

class ShopAnalyticsScreen extends ConsumerWidget {
  const ShopAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_shopAnalyticsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Analytics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<List<Map<String, dynamic>>>(
        value: value,
        onRetry: () => ref.invalidate(_shopAnalyticsProvider),
        data: (rows) {
          final total = rows.fold<double>(0, (s, r) => s + ((r['gross_revenue'] as num?)?.toDouble() ?? 0));
          final currency = rows.isEmpty ? 'BHD' : (rows.first['currency'] as String? ?? 'BHD');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Row(
                  children: [
                    Expanded(child: Text('Revenue (30d)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                    Text('${total.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const HallaqCard(glass: true, child: Text('No revenue yet.')),
              ...rows.map((r) {
                final day = r['day']?.toString() ?? '';
                final amount = ((r['gross_revenue'] as num?)?.toDouble() ?? 0);
                final count = (r['payments_count'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HallaqCard(
                    glass: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text('$count payments', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Text('${amount.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
