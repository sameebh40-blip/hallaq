import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_logo.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../bookings/presentation/bookings_screen.dart';
import '../../city/presentation/city_screen.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../explore/presentation/explore_feed_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = <_Tab>[
    _Tab('/home', 'home', Icons.home_filled),
    _Tab('/bookings', 'bookings', Icons.calendar_month_rounded),
    _Tab('/discover', 'explore', Icons.play_arrow_rounded),
    _Tab('/me', 'profile', Icons.person_rounded),
  ];

  int _locationToIndex(String location) {
    final index = _tabs.indexWhere((t) => location == t.location);
    if (index != -1) return index;
    if (location == '/') return 0;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/city')) return -1;
    if (location.startsWith('/bookings')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/me')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uri = GoRouterState.of(context).uri;
    final currentIndex = _locationToIndex(uri.path);
    final citySelected = uri.path.startsWith('/city');
    final headerLabel = switch (currentIndex) {
      0 => l10n.home,
      1 => l10n.bookings,
      2 => l10n.explore,
      _ => l10n.profile,
    };

    return LuxuryScaffold(
      safeBottom: false,
      header: (currentIndex == 0 || currentIndex == 2 || citySelected) ? null : _ShellHeader(cityTitle: l10n.cityTitle, sectionTitle: headerLabel),
      bottom: HallaqBottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex && index == 2) {
            ref.read(exploreFeedControllerProvider.notifier).refresh();
            return;
          }
          context.go(_tabs[index].location);
        },
        items: [
          HallaqBottomNavItem(icon: _tabs[0].icon, label: l10n.home),
          HallaqBottomNavItem(icon: _tabs[1].icon, label: l10n.bookings),
          HallaqBottomNavItem(icon: _tabs[2].icon, label: l10n.explore),
          HallaqBottomNavItem(icon: _tabs[3].icon, label: l10n.profile),
        ],
        onActionTap: () => context.go('/city'),
        actionSelected: citySelected,
        actionIcon: Icons.location_on_rounded,
        actionLabel: l10n.cityTitle,
      ),
      child: child,
    );
  }
}

class _Tab {
  final String location;
  final String key;
  final IconData icon;

  const _Tab(this.location, this.key, this.icon);
}

class _ShellHeader extends StatelessWidget {
  final String cityTitle;
  final String sectionTitle;

  const _ShellHeader({required this.cityTitle, required this.sectionTitle});

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      padding: EdgeInsets.zero,
      child: LuxuryTopBar(
        leading: const HallaqLogo(size: 34),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cityTitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.goldDeep,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.2,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sectionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AppShellHome extends StatelessWidget {
  const AppShellHome({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class AppShellExplore extends StatelessWidget {
  const AppShellExplore({super.key});

  @override
  Widget build(BuildContext context) => const ExploreScreen();
}

class AppShellCity extends StatelessWidget {
  const AppShellCity({super.key});

  @override
  Widget build(BuildContext context) => const CityScreen();
}

class AppShellBookings extends StatelessWidget {
  const AppShellBookings({super.key});

  @override
  Widget build(BuildContext context) => const BookingsScreen();
}

class AppShellProfile extends StatelessWidget {
  const AppShellProfile({super.key});

  @override
  Widget build(BuildContext context) => const ProfileScreen();
}
