import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../data/customer_membership_repository.dart';
import '../data/loyalty_repository.dart';
import '../data/profile_stats_repository.dart';

class LoyaltyHistoryScreen extends ConsumerWidget {
  const LoyaltyHistoryScreen({super.key});

  int _monthEarned(List<LoyaltyEntry> items) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return items.where((e) => e.createdAt.toLocal().isAfter(start)).fold<int>(0, (sum, e) => sum + e.delta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(myProfileStatsProvider);
    final ledger = ref.watch(myLoyaltyLedgerProvider);
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
                        'Loyalty Points',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.gold,
                onRefresh: () async {
                  ref.invalidate(myProfileStatsProvider);
                  ref.invalidate(myLoyaltyLedgerProvider);
                  ref.invalidate(myCustomerMembershipProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    AsyncValueWidget(
                      value: ledger,
                      onRetry: () {
                        ref.invalidate(myProfileStatsProvider);
                        ref.invalidate(myLoyaltyLedgerProvider);
                        ref.invalidate(myCustomerMembershipProvider);
                      },
                      data: (items) {
                        final points = stats.valueOrNull?.loyaltyPoints ?? membership.valueOrNull?.points ?? 0;
                        final earnedThisMonth = _monthEarned(items);
                        const platinumReq = 700;
                        final toPlatinum = (platinumReq - points).clamp(0, 999999);
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppTheme.softShadow(opacity: 0.14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Your Points', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            NumberFormat.decimalPattern().format(points),
                                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(width: 6),
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 6),
                                            child: Icon(Icons.circle, size: 8, color: AppTheme.gold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        earnedThisMonth <= 0 ? 'Earned this month' : '+${NumberFormat.decimalPattern().format(earnedThisMonth)} points earned this month',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.80), fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      NumberFormat.decimalPattern().format(platinumReq),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${NumberFormat.decimalPattern().format(toPlatinum)} to Platinum',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Earn Points', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _EarnRow(title: 'Book a service', points: '+10 points', icon: Icons.calendar_month_outlined),
                    const SizedBox(height: 10),
                    _EarnRow(title: 'Write a review', points: '+5 points', icon: Icons.rate_review_outlined),
                    const SizedBox(height: 10),
                    _EarnRow(title: 'Refer a friend', points: '+20 points', icon: Icons.person_add_alt_rounded),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () => context.push('/awards'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'View all rewards',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Reward History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ledger.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return _EmptyCard(
                            title: l10n.noPointsYetTitle,
                            subtitle: l10n.noPointsYetSubtitle,
                          );
                        }
                        return Column(
                          children: [
                            for (final e in items) ...[
                              _LedgerTile(entry: e),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                      loading: () => const _LoadingList(),
                      error: (_, __) => _EmptyCard(
                        title: 'Could not load history',
                        subtitle: 'Tap to retry',
                        onTap: () {
                          ref.invalidate(myProfileStatsProvider);
                          ref.invalidate(myLoyaltyLedgerProvider);
                          ref.invalidate(myCustomerMembershipProvider);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final String title;
  final String points;
  final IconData icon;

  const _EarnRow({required this.title, required this.points, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
          Text(points, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final LoyaltyEntry entry;

  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta >= 0;
    final amount = positive ? '+${entry.delta}' : '${entry.delta}';
    final date = DateFormat('MMM d, yyyy').format(entry.createdAt.toLocal());
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: positive ? AppTheme.gold.withValues(alpha: 0.14) : AppTheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(positive ? Icons.add_rounded : Icons.remove_rounded, color: positive ? AppTheme.gold : AppTheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason.isEmpty ? 'Points update' : entry.reason, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(date, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Text(amount, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow(opacity: 0.06),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _EmptyCard({required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}
