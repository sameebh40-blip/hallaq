import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../data/my_reviews_repository.dart';

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myReviewsProvider);

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
                      child: Text('My Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueWidget(
                value: value,
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No reviews yet', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                              'After your next booking, share your experience and earn more loyalty points.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: () => context.go('/bookings'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.gold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text('View bookings', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    itemBuilder: (_, i) => _ReviewTile(item: items[i]),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: items.length,
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

class _ReviewTile extends StatelessWidget {
  final MyReviewItem item;

  const _ReviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy').format(item.createdAt.toLocal());
    final title = [
      if ((item.barberName ?? '').trim().isNotEmpty) item.barberName!.trim(),
      if ((item.shopName ?? '').trim().isNotEmpty) item.shopName!.trim(),
    ].join(' • ').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title.isEmpty ? 'Review' : title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
              _Stars(rating: item.rating),
            ],
          ),
          const SizedBox(height: 6),
          Text(date, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
          if ((item.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.text!.trim(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.25)),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(filled ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: filled ? AppTheme.gold : AppTheme.textMuted);
      }),
    );
  }
}

