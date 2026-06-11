import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/offer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/my_offers_repository.dart';

class MyOffersInboxScreen extends ConsumerWidget {
  const MyOffersInboxScreen({super.key});

  String _label(Offer offer) {
    return switch (offer.offerType) {
      'fixed' => offer.discountAmount == null ? 'DISCOUNT' : '${offer.discountAmount!.toStringAsFixed(3)} BHD OFF',
      'package' => 'PACKAGE',
      _ => offer.discountPercent == null ? 'DISCOUNT' : '${offer.discountPercent!.toStringAsFixed(0)}% OFF',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myOfferTargetsProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('My Offers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuxuryIconButton(icon: Icons.local_offer_outlined, onPressed: () => context.push('/offers')),
            LuxuryIconButton(icon: Icons.refresh_rounded, onPressed: () => ref.invalidate(myOfferTargetsProvider)),
          ],
        ),
      ),
      child: AsyncValueWidget<List<MyOfferTarget>>(
        value: value,
        onRetry: () => ref.invalidate(myOfferTargetsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: HallaqEmptyState(
                title: 'No offers yet',
                description: 'Offers sent to you will appear here.',
                showMascot: true,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemBuilder: (context, index) {
              final item = items[index];
              final offer = item.offer;
              final label = _label(offer);
              final sentAt = DateFormat('MMM d, h:mm a').format(item.createdAt.toLocal());
              final status = item.status.trim();
              final statusColor = switch (status) {
                'redeemed' => AppTheme.success,
                'expired' || 'cancelled' => AppTheme.error,
                _ => AppTheme.gold,
              };

              Future<void> book() async {
                final barberId = (offer.barberId ?? '').trim();
                final shopId = (offer.shopId ?? '').trim();
                if (barberId.isNotEmpty) {
                  context.push('/booking/new?barberId=$barberId');
                  return;
                }
                if (shopId.isNotEmpty) {
                  context.push('/booking/new?shopId=$shopId');
                }
              }

              Future<void> redeem() async {
                await ref.read(myOffersRepositoryProvider).markRedeemed(item.id);
                ref.invalidate(myOfferTargetsProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as redeemed.')));
              }

              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(offer.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                          ),
                          child: Text(status.isEmpty ? 'sent' : status, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (label.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppTheme.gold.withValues(alpha: 0.10),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.20)),
                        ),
                        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold)),
                      ),
                    if ((offer.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(offer.description!.trim(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                    const SizedBox(height: 10),
                    Text('Sent $sentAt', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (status == 'sent') ? book : null,
                            icon: const Icon(Icons.calendar_month_rounded, size: 18),
                            label: const Text('Book'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (status == 'sent') ? redeem : null,
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Redeemed'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
