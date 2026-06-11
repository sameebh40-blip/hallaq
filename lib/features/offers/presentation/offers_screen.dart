import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/offer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../favorites/data/favorites_repository.dart';
import '../data/offers_repository.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(activeOffersProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Offers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        trailing: LuxuryIconButton(icon: Icons.inbox_outlined, onPressed: () => context.push('/offers/inbox')),
      ),
      child: AsyncValueWidget<List<Offer>>(
        value: value,
        data: (items) {
          if (items.isEmpty) return Center(child: Text('No offers', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted)));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            itemBuilder: (context, index) => _OfferCard(offer: items[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  final Offer offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (offer.offerType) {
      'fixed' => offer.discountAmount == null ? 'DISCOUNT' : '${offer.discountAmount!.toStringAsFixed(3)} BHD OFF',
      'package' => 'PACKAGE',
      _ => offer.discountPercent == null ? 'DISCOUNT' : '${offer.discountPercent!.toStringAsFixed(0)}% OFF',
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        gradient: AppTheme.goldGradient,
        boxShadow: AppTheme.softShadow(opacity: 0.34),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.36),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(offer.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: () async {
                      try {
                        await ref.read(favoritesRepositoryProvider).add(targetType: 'offer', targetId: offer.id);
                        ref.invalidate(favoriteOffersProvider);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (label.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.black.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              if (offer.description != null && offer.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(offer.description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
