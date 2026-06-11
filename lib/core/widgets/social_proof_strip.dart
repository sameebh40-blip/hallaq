import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../formatters/number_formatters.dart';
import '../social_proof/social_proof_repository.dart';
import '../theme/app_theme.dart';

class SocialProofStrip extends ConsumerWidget {
  final String targetType;
  final String targetId;
  final double ratingAvg;
  final int ratingCountFallback;
  final String? barberIdForBookings;
  final String? shopIdForBookings;
  final VoidCallback? onTapRating;
  final VoidCallback? onTapReviews;
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapBookings;

  const SocialProofStrip({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.ratingAvg,
    required this.ratingCountFallback,
    this.barberIdForBookings,
    this.shopIdForBookings,
    this.onTapRating,
    this.onTapReviews,
    this.onTapFollowers,
    this.onTapBookings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider((targetType: targetType, targetId: targetId)));
    final reviews = ref.watch(reviewsCountProvider((targetType: targetType, targetId: targetId)));
    final bookings = barberIdForBookings != null
        ? ref.watch(bookingsCountForBarberProvider(barberIdForBookings!))
        : (shopIdForBookings != null ? ref.watch(bookingsCountForShopProvider(shopIdForBookings!)) : const AsyncValue.data(0));

    Widget chip({required IconData icon, required String label, required VoidCallback? onTap}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF141414),
            border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    final reviewsCount = reviews.value ?? ratingCountFallback;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip(icon: Icons.star_rounded, label: ratingAvg.toStringAsFixed(1), onTap: onTapRating),
        chip(icon: Icons.rate_review_rounded, label: NumberFormatters.compactInt(reviewsCount), onTap: onTapReviews),
        chip(icon: Icons.people_alt_rounded, label: NumberFormatters.compactInt(followers.value ?? 0), onTap: onTapFollowers),
        chip(icon: Icons.event_available_rounded, label: NumberFormatters.compactInt(bookings.value ?? 0), onTap: onTapBookings),
      ],
    );
  }
}
