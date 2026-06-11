import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../reviews/data/reviews_repository.dart';

enum _ReviewFilter { all, five, four, three, low }

class BarberReviewsScreen extends ConsumerStatefulWidget {
  const BarberReviewsScreen({super.key});

  @override
  ConsumerState<BarberReviewsScreen> createState() => _BarberReviewsScreenState();
}

class _BarberReviewsScreenState extends ConsumerState<BarberReviewsScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final barberValue = ref.watch(myBarberProvider);
    final reviewsValue = ref.watch(myBarberReviewsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Reviews', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: barberValue,
        data: (barber) {
          if (barber == null) {
            return HallaqEmptyState(
              title: 'No barber profile',
              description: 'This account is not linked to a barber yet.',
              showMascot: true,
            );
          }
          return AsyncValueWidget<List<Review>>(
            value: reviewsValue,
            data: (reviews) {
              final filtered = reviews.where((r) {
                return switch (_filter) {
                  _ReviewFilter.all => true,
                  _ReviewFilter.five => r.rating == 5,
                  _ReviewFilter.four => r.rating == 4,
                  _ReviewFilter.three => r.rating == 3,
                  _ReviewFilter.low => r.rating <= 2,
                };
              }).toList(growable: false);

              final total = reviews.length;
              final counts = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
              for (final r in reviews) {
                final v = r.rating.clamp(1, 5);
                counts[v] = (counts[v] ?? 0) + 1;
              }
              final avg = total == 0 ? 0.0 : reviews.map((e) => e.rating).reduce((a, b) => a + b) / total;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  HallaqCard(
                    glass: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Average Rating', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(avg.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 10),
                                  HallaqRating(value: avg, count: total, iconSize: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.goldGradient,
                            boxShadow: AppTheme.softShadow(opacity: 0.35),
                          ),
                          child: const Icon(Icons.star_rounded, color: Colors.black, size: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  HallaqCard(
                    glass: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Review Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        for (var star = 5; star >= 1; star--) ...[
                          _BreakdownRow(
                            star: star,
                            count: counts[star] ?? 0,
                            total: total,
                          ),
                          if (star != 1) const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Recent Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _FilterChip(label: 'All', selected: _filter == _ReviewFilter.all, onTap: () => setState(() => _filter = _ReviewFilter.all))),
                      const SizedBox(width: 10),
                      Expanded(child: _FilterChip(label: '5★', selected: _filter == _ReviewFilter.five, onTap: () => setState(() => _filter = _ReviewFilter.five))),
                      const SizedBox(width: 10),
                      Expanded(child: _FilterChip(label: '4★', selected: _filter == _ReviewFilter.four, onTap: () => setState(() => _filter = _ReviewFilter.four))),
                      const SizedBox(width: 10),
                      Expanded(child: _FilterChip(label: 'Low', selected: _filter == _ReviewFilter.low, onTap: () => setState(() => _filter = _ReviewFilter.low))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    HallaqEmptyState(
                      title: 'No reviews',
                      description: 'No reviews match this filter yet.',
                      showMascot: true,
                      compact: true,
                    )
                  else
                    ...filtered.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReviewCard(review: r))),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold.withValues(alpha: 0.18) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.55) : AppTheme.border),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: selected ? AppTheme.gold : AppTheme.text),
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final int star;
  final int count;
  final int total;

  const _BreakdownRow({required this.star, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text('$star', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const Icon(Icons.star_rounded, size: 18, color: AppTheme.gold),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text('$count', textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> reply() async {
      final text = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ReplySheet(initial: review.replyText ?? ''),
      );
      if (text == null || !context.mounted) return;
      try {
        await ref.read(reviewsRepositoryProvider).updateReply(reviewId: review.id, replyText: text);
        ref.invalidate(myBarberReviewsProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply saved.')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HallaqAvatar(imageUrl: review.customerAvatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (review.customerName ?? '').trim().isEmpty ? 'Customer' : (review.customerName ?? '').trim(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        HallaqRating(value: review.rating.toDouble(), showValue: false, iconSize: 16),
                        if (review.isVerified) ...[
                          const SizedBox(width: 10),
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
                      ],
                    ),
                  ],
                ),
              ),
              LuxuryIconButton(icon: Icons.reply_rounded, onPressed: reply),
            ],
          ),
          if ((review.comment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review.comment!.trim(), style: Theme.of(context).textTheme.bodyMedium),
          ],
          if ((review.imageUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: LuxuryNetworkImage(
                imageUrl: review.imageUrl!,
                fallbackUrl: '',
                height: 200,
                borderRadius: BorderRadius.zero,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if ((review.replyText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your reply', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Text(review.replyText!.trim(), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final String initial;

  const _ReplySheet({required this.initial});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reply to review', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: _c,
                  decoration: const InputDecoration(labelText: 'Your reply'),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 14),
                HallaqButton(
                  label: 'Save Reply',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(_c.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
