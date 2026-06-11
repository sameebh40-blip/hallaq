import 'package:flutter/material.dart';

import '../social_proof/hallaq_badges.dart';
import '../theme/app_theme.dart';

class HallaqBadgesRow extends StatelessWidget {
  final List<HallaqBadge> badges;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const HallaqBadgesRow({
    super.key,
    required this.badges,
    this.iconSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map(
            (b) => Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: b.color.withValues(alpha: 0.14),
                border: Border.all(color: b.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(b.icon, size: iconSize, color: b.color),
                  const SizedBox(width: 6),
                  Text(
                    b.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

