import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../data/customer_membership_repository.dart';

class MembershipScreen extends ConsumerWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myCustomerMembershipProvider);

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Membership',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueWidget(
                value: membership,
                onRetry: () => ref.invalidate(myCustomerMembershipProvider),
                data: (m) {
                  final tier = (m?.tier ?? 'Silver').trim();
                  final points = m?.points ?? 0;

                  const tiers = {'Silver': 0, 'Gold': 300, 'Platinum': 700};
                  final nextTier = switch (tier) {
                    'Silver' => 'Gold',
                    'Gold' => 'Platinum',
                    _ => 'Platinum',
                  };
                  final nextReq = tiers[nextTier] ?? 700;
                  final remaining = (nextReq - points).clamp(0, 999999);
                  final progress = nextReq == 0 ? 1.0 : (points / nextReq).clamp(0, 1).toDouble();
                  final benefits = switch (tier) {
                    'Gold' => const [
                        (Icons.bolt_rounded, 'Priority booking', 'Get priority for busy barbers'),
                        (Icons.local_offer_outlined, 'Exclusive offers', 'Member-only promotions and deals'),
                      ],
                    'Platinum' => const [
                        (Icons.bolt_rounded, 'Priority booking', 'Get priority for busy barbers'),
                        (Icons.workspace_premium_rounded, 'VIP offers', 'Premium offers from top barbers and shops'),
                        (Icons.verified_rounded, 'Premium badge', 'A premium badge on your profile'),
                      ],
                    _ => const [
                        (Icons.stars_rounded, 'Basic benefits', 'Earn points and unlock rewards'),
                      ],
                  };

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(colors: [AppTheme.goldSoft, AppTheme.gold, AppTheme.goldDeep]),
                          boxShadow: AppTheme.goldGlow(opacity: 0.18, blur: 26, y: 14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(Icons.emoji_events_rounded, color: Colors.black),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$tier Member',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${NumberFormat.decimalPattern().format(points)} points',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        remaining.toString(),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        'Points to $nextTier',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black.withValues(alpha: 0.70), fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  height: 6,
                                  child: Stack(
                                    children: [
                                      const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
                                      FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: progress,
                                        child: const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Member Benefits', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      for (final b in benefits) ...[
                        _BenefitRow(icon: b.$1, title: b.$2, subtitle: b.$3),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: () => context.push('/points'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Learn more about membership',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
