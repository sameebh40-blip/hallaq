import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/reviews_repository.dart';
import 'write_review_screen.dart';

class ReviewsScreen extends ConsumerWidget {
  final String targetType;
  final String targetId;

  const ReviewsScreen({super.key, required this.targetType, required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(reviewsForTargetProvider((targetType: targetType, targetId: targetId)));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.reviews, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.edit_rounded,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('To leave a review, open your completed booking.')),
            );
            context.go('/bookings');
          },
        ),
      ),
      child: AsyncValueWidget<List<Review>>(
        value: value,
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: HallaqEmptyState(
                title: l10n.reviews,
                description: l10n.noReviewsDescription,
                showMascot: true,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = items[index];
              return _ReviewTile(review: r);
            },
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = (review.comment ?? '').trim();
    final photoUrl = (review.imageUrl ?? '').trim();
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.isVerified)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.20)),
                ),
                child: Text(
                  l10n.verified,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold),
                ),
              ),
            ),
          Row(
            children: List.generate(5, (i) {
              final filled = i < review.rating;
              return Icon(filled ? Icons.star_rounded : Icons.star_border_rounded, color: AppTheme.gold, size: 18);
            }),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
          ],
          if (photoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            LuxuryNetworkImage(
              imageUrl: photoUrl,
              fallbackUrl: HallaqImages.premiumMembership(variant: '02'),
              height: 180,
              borderRadius: BorderRadius.circular(18),
            ),
          ],
          if ((review.replyText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                color: AppTheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.reply, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text((review.replyText ?? '').trim(), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
