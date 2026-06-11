import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/barber.dart';
import '../models/barbershop.dart';
import '../theme/app_theme.dart';

enum HallaqBadgeType { verified, elite, trending, certified, topRated }

class HallaqBadge {
  final HallaqBadgeType type;
  final String label;
  final IconData icon;
  final Color color;

  const HallaqBadge({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });
}

List<HallaqBadge> badgesForBarber(BuildContext context, Barber barber) {
  final l10n = AppLocalizations.of(context);
  final badges = <HallaqBadge>[];

  if (barber.badgeTopRated) {
    badges.add(HallaqBadge(type: HallaqBadgeType.topRated, label: l10n.badgeTopRated, icon: Icons.emoji_events_rounded, color: AppTheme.gold));
  }
  if (barber.badgeCertified) {
    badges.add(HallaqBadge(type: HallaqBadgeType.certified, label: l10n.badgeCertified, icon: Icons.workspace_premium_rounded, color: AppTheme.gold));
  }
  if (barber.badgeElite) {
    badges.add(HallaqBadge(type: HallaqBadgeType.elite, label: l10n.badgeElite, icon: Icons.star_rounded, color: AppTheme.gold));
  }
  if (barber.badgeTrending) {
    badges.add(HallaqBadge(type: HallaqBadgeType.trending, label: l10n.badgeTrending, icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF6B3D)));
  }
  if (barber.badgeVerified) {
    badges.add(HallaqBadge(type: HallaqBadgeType.verified, label: l10n.badgeVerified, icon: Icons.verified_rounded, color: const Color(0xFF3BA3FF)));
  }

  return badges;
}

List<HallaqBadge> badgesForShop(BuildContext context, Barbershop shop) {
  final l10n = AppLocalizations.of(context);
  final badges = <HallaqBadge>[];

  if (shop.badgeTopRated) {
    badges.add(HallaqBadge(type: HallaqBadgeType.topRated, label: l10n.badgeTopRated, icon: Icons.emoji_events_rounded, color: AppTheme.gold));
  }
  if (shop.badgeCertified) {
    badges.add(HallaqBadge(type: HallaqBadgeType.certified, label: l10n.badgeCertified, icon: Icons.workspace_premium_rounded, color: AppTheme.gold));
  }
  if (shop.badgeElite) {
    badges.add(HallaqBadge(type: HallaqBadgeType.elite, label: l10n.badgeElite, icon: Icons.star_rounded, color: AppTheme.gold));
  }
  if (shop.badgeTrending) {
    badges.add(HallaqBadge(type: HallaqBadgeType.trending, label: l10n.badgeTrending, icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF6B3D)));
  }
  if (shop.badgeVerified) {
    badges.add(HallaqBadge(type: HallaqBadgeType.verified, label: l10n.badgeVerified, icon: Icons.verified_rounded, color: const Color(0xFF3BA3FF)));
  }

  return badges;
}
