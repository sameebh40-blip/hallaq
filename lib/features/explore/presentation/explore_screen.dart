import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/analytics/analytics_repository.dart';
import '../../../core/brand/brand_assets_controller.dart';
import '../../../core/geo/eta.dart';
import '../../../core/geo/geo_distance.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/formatters/number_formatters.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/links/app_links.dart';
import '../../../core/media/media_service.dart';
import '../../../core/media/video_thumbnailer.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/reel.dart';
import '../../../core/engagement/engagement_repository.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_loader.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_skeletons.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/reel_comments_repository.dart';
import '../models/explore_reel.dart';
import 'explore_feed_controller.dart';
import 'explore_reel_player_window.dart';

enum _DiscoverTab { forYou, following, nearby }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _pageController = PageController();
  int _index = 0;
  _DiscoverTab _tab = _DiscoverTab.forYou;
  final Set<String> _trackedReels = {};
  String _playerSyncKey = '';
  int _playerSyncIndex = -1;
  String _filterWarmupKey = '';

  @override
  void dispose() {
    ref.invalidate(exploreReelPlayerWindowProvider);
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(_DiscoverTab tab) {
    if (_tab == tab) return;
    HallaqHaptics.selection();
    setState(() {
      _tab = tab;
      _index = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(0);
    });
  }

  List<ExploreReel> _itemsForTab(List<ExploreReel> items, ({double lat, double lng})? viewerLatLng) {
    switch (_tab) {
      case _DiscoverTab.forYou:
        return items;
      case _DiscoverTab.following:
        return items.where((item) => item.isFollowing).toList(growable: false);
      case _DiscoverTab.nearby:
        if (viewerLatLng == null) return const <ExploreReel>[];
        final ranked = items
            .map(
              (item) => (
                item: item,
                distanceKm: _distanceForItem(item, viewerLatLng),
              ),
            )
            .where((entry) => entry.distanceKm != null)
            .toList(growable: false)
          ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
        return ranked.map((entry) => entry.item).toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(exploreFeedControllerProvider);
    final errorImage = ref.watch(brandAssetUrlProvider('default_error_state'))?.trim();
    final viewerLatLng = ref.watch(effectiveLatLngProvider).valueOrNull;

    return AsyncValueWidget<ExploreFeedState>(
      value: feed,
      loading: const FullScreenFeedSkeleton(),
      error: (e, st) {
        return Center(
          child: HallaqEmptyState(
            title: 'Couldn\'t load reels',
            description: 'Tap retry or pull to refresh.',
            showMascot: true,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(exploreFeedControllerProvider),
          ),
        );
      },
      onRetry: () {
        ref.invalidate(exploreFeedControllerProvider);
      },
      errorImageUrl: errorImage,
      data: (feedState) {
        final baseItems = feedState.items;
        final items = _itemsForTab(baseItems, viewerLatLng);
        final warmupKey = '${_tab.name}:${baseItems.length}:${feedState.hasMore}:${viewerLatLng != null}';
        if (_tab != _DiscoverTab.forYou && items.isEmpty && baseItems.isNotEmpty && feedState.hasMore && warmupKey != _filterWarmupKey) {
          _filterWarmupKey = warmupKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(exploreFeedControllerProvider.notifier).loadMore();
          });
        }
        final clampedIndex = items.isEmpty ? 0 : _index.clamp(0, items.length);
        if (clampedIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index = clampedIndex);
            if (_pageController.hasClients && items.isNotEmpty) {
              _pageController.jumpToPage(clampedIndex.clamp(0, items.length - 1));
            }
          });
        }
        final showEndScreen = items.isNotEmpty && !feedState.hasMore;
        final isEndIndex = _index >= items.length;
        final current = (!isEndIndex && items.isNotEmpty) ? items[_index.clamp(0, items.length - 1)] : null;
        final effectiveIndex = items.isEmpty ? null : _index.clamp(0, items.length - 1);
        final nextKey = '${_tab.name}:${items.length}:${items.isNotEmpty ? items.first.reel.id : ''}:${items.isNotEmpty ? items.last.reel.id : ''}';
        if (!isEndIndex && effectiveIndex != null && (nextKey != _playerSyncKey || effectiveIndex != _playerSyncIndex)) {
          _playerSyncKey = nextKey;
          _playerSyncIndex = effectiveIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(exploreReelPlayerWindowProvider.notifier).setActive(index: effectiveIndex, items: items);
          });
        }
        if (isEndIndex && _playerSyncIndex != -2) {
          _playerSyncIndex = -2;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(exploreReelPlayerWindowProvider.notifier).setActive(index: null, items: items);
          });
        }

        return Stack(
          children: [
            if (items.isEmpty)
              _EmptyExploreState(
                tab: _tab,
                onRefresh: () => ref.read(exploreFeedControllerProvider.notifier).refresh(),
              )
            else
              RefreshIndicator(
                color: AppTheme.gold,
                backgroundColor: Colors.black,
                onRefresh: () async {
                  await ref.read(exploreFeedControllerProvider.notifier).refresh();
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length + (showEndScreen ? 1 : 0),
                  onPageChanged: (index) {
                    setState(() => _index = index);
                    if (index >= 0 && index < items.length) {
                      ref.read(exploreReelPlayerWindowProvider.notifier).setActive(index: index, items: items);
                    } else {
                      ref.read(exploreReelPlayerWindowProvider.notifier).setActive(index: null, items: items);
                    }
                    if (feedState.hasMore && index >= items.length - 3) {
                      ref.read(exploreFeedControllerProvider.notifier).loadMore();
                    }

                    if (index >= 0 && index < items.length) {
                      final reelId = items[index].reel.id;
                      if (!_trackedReels.contains(reelId)) {
                        _trackedReels.add(reelId);
                        Future<void>(() async {
                          try {
                            await ref.read(engagementRepositoryProvider).trackReelView(reelId: reelId);
                          } catch (_) {}
                        });
                      }
                    }

                    final nextIndex = index + 1;
                    if (nextIndex >= 0 && nextIndex < items.length) {
                      final next = items[nextIndex].reel;
                      final thumb = (next.thumbnailUrl ?? '').trim();
                      final thumbPath = (next.thumbnailPath ?? '').trim();
                      final refOrUrl = thumbPath.isNotEmpty ? thumbPath : thumb;
                      if (refOrUrl.isNotEmpty) {
                        Future<void>(() async {
                          if (!context.mounted) return;
                          try {
                            await ref.read(mediaServiceProvider).precacheAnyImageRef(
                                  context,
                                  primary: refOrUrl,
                                  bucket: 'reels',
                                );
                          } catch (_) {}
                        });
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    if (showEndScreen && index == items.length) {
                      return const _EndOfReelsScreen();
                    }
                    return _ExploreReelPage(
                      item: items[index],
                      variant: (index + 1).toString().padLeft(2, '0'),
                      isActive: index == _index,
                      index: index,
                    );
                  },
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: _ExploreHeader(
                    selectedTab: _tab,
                    onTabSelected: _selectTab,
                    currentItem: current,
                    viewerLatLng: viewerLatLng,
                  ),
                ),
              ),
            ),
            if (current != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 102,
                child: _ExploreBookingCard(
                  item: current,
                  viewerLatLng: viewerLatLng,
                ),
              ),
          ],
        );
      },
    );
  }
}

double? _distanceForItem(ExploreReel item, ({double lat, double lng}) viewerLatLng) {
  final lat = item.author.lat;
  final lng = item.author.lng;
  if (lat == null || lng == null) return null;
  return haversineKm(
    fromLat: viewerLatLng.lat,
    fromLng: viewerLatLng.lng,
    toLat: lat,
    toLng: lng,
  );
}

class _ExploreHeader extends ConsumerWidget {
  final _DiscoverTab selectedTab;
  final ValueChanged<_DiscoverTab> onTabSelected;
  final ExploreReel? currentItem;
  final ({double lat, double lng})? viewerLatLng;

  const _ExploreHeader({
    required this.selectedTab,
    required this.onTabSelected,
    required this.currentItem,
    required this.viewerLatLng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(myUnreadNotificationsCountProvider).valueOrNull ?? 0;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final viewerArea = _savedViewerArea(profile);
    final distanceKm = currentItem == null || viewerLatLng == null ? null : _distanceForItem(currentItem!, viewerLatLng!);
    final reelPlaceLabel = currentItem == null ? null : _currentReelPlaceLabel(currentItem!);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 184),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HALLAQ',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DISCOVER',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    onTap: () {
                      HallaqHaptics.selection();
                      context.push('/notifications');
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                        if (unread > 0)
                          PositionedDirectional(
                            end: -4,
                            top: -4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderIconButton(
                    onTap: () {
                      HallaqHaptics.selection();
                      context.push('/search');
                    },
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ExploreLocationCard(
            areaLabel: viewerArea,
            reelPlaceLabel: reelPlaceLabel,
            distanceKm: distanceKm,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xCC0F0F0F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                _ExploreHeaderTab(
                  label: 'For You',
                  selected: selectedTab == _DiscoverTab.forYou,
                  onTap: () => onTabSelected(_DiscoverTab.forYou),
                ),
                _ExploreHeaderTab(
                  label: 'Following',
                  selected: selectedTab == _DiscoverTab.following,
                  onTap: () => onTabSelected(_DiscoverTab.following),
                ),
                _ExploreHeaderTab(
                  label: 'Nearby',
                  selected: selectedTab == _DiscoverTab.nearby,
                  onTap: () => onTabSelected(_DiscoverTab.nearby),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _savedViewerArea(UserProfile? profile) {
  final area = (profile?.area ?? '').trim();
  if (area.isNotEmpty) return area;
  final location = (profile?.location ?? '').trim();
  if (location.isEmpty) return 'Saved area';
  return location.split(',').first.trim();
}

String? _currentReelPlaceLabel(ExploreReel item) {
  final reelLocation = (item.reel.location ?? '').trim();
  if (reelLocation.isNotEmpty) return reelLocation;
  final area = (item.author.area ?? '').trim();
  if (area.isNotEmpty) return area;
  final shopName = (item.author.shopName ?? '').trim();
  if (shopName.isNotEmpty) return shopName;
  return null;
}

class _ExploreLocationCard extends StatelessWidget {
  final String areaLabel;
  final String? reelPlaceLabel;
  final double? distanceKm;

  const _ExploreLocationCard({
    required this.areaLabel,
    required this.reelPlaceLabel,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final distanceText = distanceKm == null
        ? 'Using your saved area for nearby reels'
        : reelPlaceLabel == null || reelPlaceLabel!.isEmpty
            ? '${distanceKm!.toStringAsFixed(1)} km from this reel'
            : '${distanceKm!.toStringAsFixed(1)} km to $reelPlaceLabel';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 224),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F).withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: AppTheme.softShadow(opacity: 0.26),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.location_on_rounded, color: AppTheme.gold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    areaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    distanceText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.94 : 1,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: AppTheme.softShadow(opacity: 0.18),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _ExploreHeaderTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExploreHeaderTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? AppTheme.goldGradient : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreBookingCard extends StatelessWidget {
  final ExploreReel item;
  final ({double lat, double lng})? viewerLatLng;

  const _ExploreBookingCard({
    required this.item,
    required this.viewerLatLng,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distanceKm = viewerLatLng == null ? null : _distanceForItem(item, viewerLatLng!);
    final eta = distanceKm == null ? null : etaLabelFromMinutes(etaMinutesFromKm(distanceKm));
    final subtitleParts = <String>[
      if ((item.author.shopName ?? '').trim().isNotEmpty) item.author.shopName!.trim(),
      if ((item.reel.location ?? item.author.area ?? '').trim().isNotEmpty) (item.reel.location ?? item.author.area)!.trim(),
      if (distanceKm != null) '${distanceKm.toStringAsFixed(1)} km',
      if (eta != null && eta.isNotEmpty) eta,
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xE6121212),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            ...AppTheme.softShadow(opacity: 0.34),
            ...AppTheme.goldGlow(opacity: 0.08, blur: 26, y: 8),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: Row(
          children: [
            HallaqAvatar(imageUrl: item.author.avatarUrl, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.isEmpty ? 'Book directly from this reel' : subtitleParts.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HallaqHaptics.selection();
                if (item.author.type == ExploreAuthorType.shop) {
                  context.push('/shop/${item.author.id}');
                } else {
                  context.push('/barber/${item.author.slug.isNotEmpty ? item.author.slug : item.author.id}');
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HallaqHaptics.selection();
                if (item.author.type == ExploreAuthorType.barber) {
                  context.push('/booking/new?barberId=${item.author.id}&postId=${item.reel.id}');
                } else {
                  context.push('/booking/new?shopId=${item.author.id}&postId=${item.reel.id}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.goldGlow(opacity: 0.18, blur: 20, y: 6),
                ),
                child: Text(
                  l10n.bookNow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExploreState extends StatelessWidget {
  final _DiscoverTab tab;
  final Future<void> Function() onRefresh;

  const _EmptyExploreState({
    required this.tab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final (title, description, actionLabel, actionPath) = switch (tab) {
      _DiscoverTab.following => (
          'No followed creators yet',
          'Follow barbers and shops from Discover to keep their latest reels here.',
          'Find creators',
          '/search?tab=barbers',
        ),
      _DiscoverTab.nearby => (
          'No nearby reels found',
          'We only show reels with real nearby location data in this tab.',
          'Search nearby barbers',
          '/search?tab=barbers',
        ),
      _DiscoverTab.forYou => (
          'No reels yet',
          'Be the first to share something amazing.',
          'Explore Top Barbers',
          '/search?tab=barbers',
        ),
    };
    return RefreshIndicator(
      color: AppTheme.gold,
      backgroundColor: Colors.black,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Center(
              child: HallaqEmptyState(
                title: title,
                description: description,
                showMascot: true,
                actionLabel: actionLabel,
                onAction: () => context.push(actionPath),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndOfReelsScreen extends StatelessWidget {
  const _EndOfReelsScreen();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.gold.withValues(alpha: 0.14),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55)),
                  ),
                  child: const Icon(Icons.check_rounded, color: AppTheme.gold, size: 38),
                ),
                const SizedBox(height: 18),
                Text(
                  'You’re all caught up',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You’ve seen all the latest reels.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 260,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/search?tab=barbers'),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.softShadow(opacity: 0.16),
                      ),
                      child: Center(
                        child: Text(
                          'Explore Top Barbers',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF111111), fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreReelPage extends ConsumerWidget {
  final ExploreReel item;
  final String variant;
  final bool isActive;
  final int index;

  const _ExploreReelPage({required this.item, required this.variant, required this.isActive, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reel = item.reel;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomNavInset = 190.0 + bottomPadding;
    final captionBottom = bottomNavInset + 12.0;
    final actionsBottom = bottomNavInset + 52.0;
    final muted = ref.watch(exploreReelPlayerWindowProvider.select((s) => s.muted));
    final soundBottom = bottomNavInset - 4.0;
    final soundImageRef = (reel.thumbnailPath ?? '').trim().isNotEmpty
        ? reel.thumbnailPath
        : (reel.thumbnailUrl ?? '').trim().isNotEmpty
            ? reel.thumbnailUrl
            : item.author.avatarUrl;

    void showActionError() {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed. Please try again.')));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _ReelMedia(
            reel: reel,
            variant: variant,
            isActive: isActive,
            index: index,
            onDoubleTap: () async {
              HallaqHaptics.tap();
              try {
                await ref.read(exploreFeedControllerProvider.notifier).toggleLike(reel.id);
              } catch (_) {}
            },
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 16,
          bottom: captionBottom,
          end: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => item.author.type == ExploreAuthorType.shop
                    ? context.push('/shop/${item.author.id}')
                    : context.push('/barber/${item.author.slug.isNotEmpty ? item.author.slug : item.author.id}'),
                child: Row(
                  children: [
                    HallaqAvatar(imageUrl: item.author.avatarUrl, size: 44, variant: variant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.author.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (item.author.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                              ],
                            ],
                          ),
                          if (((reel.location ?? item.author.area) ?? '').trim().isNotEmpty || (item.author.shopName ?? '').trim().isNotEmpty)
                            Text(
                              item.author.type == ExploreAuthorType.barber && (item.author.shopName ?? '').isNotEmpty
                                  ? [
                                      (item.author.shopName ?? '').trim(),
                                      ((reel.location ?? item.author.area ?? '').trim()),
                                    ].where((e) => e.isNotEmpty).join(' • ')
                                  : ((reel.location ?? item.author.area) ?? '').trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Caption(caption: reel.caption, hashtags: reel.hashtags),
            ],
          ),
        ),
        PositionedDirectional(
          end: 14,
          bottom: actionsBottom,
          child: Column(
            children: [
              _AuthorRailAction(
                author: item.author,
                variant: variant,
                isFollowing: item.isFollowing,
                onAvatarTap: () {
                  HallaqHaptics.selection();
                  if (item.author.type == ExploreAuthorType.shop) {
                    context.push('/shop/${item.author.id}');
                  } else {
                    context.push('/barber/${item.author.slug.isNotEmpty ? item.author.slug : item.author.id}');
                  }
                },
                onFollowTap: () async {
                  HallaqHaptics.selection();
                  try {
                    await ref.read(exploreFeedControllerProvider.notifier).toggleFollow(item.author);
                  } catch (_) {
                    if (!context.mounted) return;
                    showActionError();
                  }
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: item.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: NumberFormatters.compactInt(reel.likesCount),
                color: item.isLiked ? const Color(0xFFFF2D55) : AppTheme.text,
                onTap: () async {
                  HallaqHaptics.tap();
                  try {
                    await ref.read(exploreFeedControllerProvider.notifier).toggleLike(reel.id);
                  } catch (e) {
                    if (!context.mounted) return;
                    showActionError();
                  }
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: Icons.mode_comment_outlined,
                label: NumberFormatters.compactInt(reel.commentsCount),
                onTap: () async {
                  HallaqHaptics.selection();
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _CommentsSheet(reelId: reel.id, variant: variant),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: Icons.share_outlined,
                label: reel.sharesCount > 0 ? NumberFormatters.compactInt(reel.sharesCount) : l10n.shareAction,
                onTap: () async {
                  HallaqHaptics.selection();
                  try {
                    await Share.share(AppLinks.reel(reel.id));
                    await ref.read(exploreFeedControllerProvider.notifier).share(reel.id);
                  } catch (_) {
                    if (!context.mounted) return;
                    showActionError();
                  }
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: item.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: NumberFormatters.compactInt(reel.savesCount),
                onTap: () async {
                  HallaqHaptics.tap();
                  try {
                    await ref.read(exploreFeedControllerProvider.notifier).toggleSave(reel.id);
                  } catch (e) {
                    if (!context.mounted) return;
                    showActionError();
                  }
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: Icons.flag_outlined,
                label: 'Report',
                onTap: () async {
                  HallaqHaptics.selection();
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _ReportSheet(reelId: reel.id),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: Icons.visibility_off_outlined,
                label: 'Hide',
                onTap: () async {
                  HallaqHaptics.selection();
                  try {
                    await ref.read(exploreFeedControllerProvider.notifier).hideReel(reel.id);
                  } catch (_) {
                    if (!context.mounted) return;
                    showActionError();
                  }
                },
              ),
            ],
          ),
        ),
        if (reel.mediaType == 'video')
          PositionedDirectional(
            end: 14,
            bottom: soundBottom,
            child: _SoundThumbButton(
              imageRef: soundImageRef,
              muted: muted,
              onTap: () {
                HallaqHaptics.selection();
                ref.read(exploreReelPlayerWindowProvider.notifier).setMuted(!muted);
              },
            ),
          ),
      ],
    );
  }
}

class _AuthorRailAction extends StatefulWidget {
  final ExploreAuthor author;
  final String variant;
  final bool isFollowing;
  final VoidCallback onAvatarTap;
  final VoidCallback onFollowTap;

  const _AuthorRailAction({
    required this.author,
    required this.variant,
    required this.isFollowing,
    required this.onAvatarTap,
    required this.onFollowTap,
  });

  @override
  State<_AuthorRailAction> createState() => _AuthorRailActionState();
}

class _AuthorRailActionState extends State<_AuthorRailAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : 1.0;
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: SizedBox(
        width: 58,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: widget.onAvatarTap,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F0F0F).withValues(alpha: 0.68),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  boxShadow: AppTheme.softShadow(opacity: 0.38),
                ),
                padding: const EdgeInsets.all(3),
                child: HallaqAvatar(
                  imageUrl: widget.author.avatarUrl,
                  size: 52,
                  variant: widget.variant,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onFollowTap,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isFollowing ? null : AppTheme.goldGradient,
                    color: widget.isFollowing ? const Color(0xFF171717) : null,
                    border: Border.all(
                      color: widget.isFollowing ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.22),
                    ),
                    boxShadow: AppTheme.softShadow(opacity: 0.24),
                  ),
                  child: Icon(
                    widget.isFollowing ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: widget.isFollowing ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundThumbButton extends StatefulWidget {
  final String? imageRef;
  final bool muted;
  final VoidCallback onTap;

  const _SoundThumbButton({
    required this.imageRef,
    required this.muted,
    required this.onTap,
  });

  @override
  State<_SoundThumbButton> createState() => _SoundThumbButtonState();
}

class _SoundThumbButtonState extends State<_SoundThumbButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: AppTheme.softShadow(opacity: 0.36),
            color: const Color(0xFF101010),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LuxuryNetworkImage(
                  imageUrl: widget.imageRef,
                  fallbackUrl: (widget.imageRef ?? '').trim(),
                  bucket: 'reels',
                  borderRadius: BorderRadius.zero,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final String? caption;
  final List<String> hashtags;

  const _Caption({required this.caption, required this.hashtags});

  @override
  Widget build(BuildContext context) {
    final c = (caption ?? '').trim();
    final tags = hashtags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    if (c.isEmpty && tags.isEmpty) return const SizedBox.shrink();

    final parts = c.split(RegExp(r'\s+'));
    final spans = <TextSpan>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('#')) {
        spans.add(
          TextSpan(
            text: '$t ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$t ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spans.isNotEmpty)
          Text.rich(
            TextSpan(children: spans),
            maxLines: tags.isNotEmpty ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    '#${t.startsWith('#') ? t.substring(1) : t}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReelAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.text,
  });

  @override
  State<_ReelAction> createState() => _ReelActionState();
}

class _ReelActionState extends State<_ReelAction> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.94 : (_hovered ? 1.03 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F0F0F).withValues(alpha: 0.62),
                  border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.85)),
                  boxShadow: AppTheme.softShadow(opacity: 0.40),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelMedia extends ConsumerStatefulWidget {
  final Reel reel;
  final String variant;
  final VoidCallback? onDoubleTap;
  final bool isActive;
  final int index;

  const _ReelMedia({required this.reel, required this.variant, required this.isActive, required this.index, this.onDoubleTap});

  @override
  ConsumerState<_ReelMedia> createState() => _ReelMediaState();
}

class _ReelMediaState extends ConsumerState<_ReelMedia> {
  bool _showLike = false;
  Timer? _initTimer;
  bool _initTimedOut = false;
  String? _trackedVideoErrorKey;

  @override
  void dispose() {
    _initTimer?.cancel();
    _initTimer = null;
    super.dispose();
  }

  void _clearInitTimeout() {
    _initTimer?.cancel();
    _initTimer = null;
    _initTimedOut = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reel.mediaType == 'video') {
      final controller = ref.watch(exploreReelPlayerWindowProvider.select((s) => s.controllers[widget.index]));
      final failed = ref.watch(exploreReelPlayerWindowProvider.select((s) => s.failed.contains(widget.index)));
      final thumbRef = (widget.reel.thumbnailPath ?? '').trim().isNotEmpty
          ? widget.reel.thumbnailPath
          : (widget.reel.thumbnailUrl ?? '').trim().isNotEmpty
              ? widget.reel.thumbnailUrl
              : null;

      if (!widget.isActive) {
        _clearInitTimeout();
        if (thumbRef != null && thumbRef.trim().isNotEmpty) {
          return LuxuryNetworkImage(
            imageUrl: thumbRef,
            fallbackUrl: (ref.watch(brandAssetUrlProvider('default_reel_thumbnail')) ?? '').trim(),
            bucket: 'reels',
            borderRadius: BorderRadius.zero,
          );
        }

        final videoUrl = widget.reel.mediaUrl.trim();
        return FutureBuilder<Uint8List?>(
          future: generateVideoThumbnailFromUrl(videoUrl),
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
            }
            return LuxuryNetworkImage(
              imageUrl: null,
              fallbackUrl: (ref.watch(brandAssetUrlProvider('default_reel_thumbnail')) ?? '').trim(),
              bucket: 'reels',
              borderRadius: BorderRadius.zero,
            );
          },
        );
      }
      final v = controller?.value;
      if (v != null && v.isInitialized && !v.hasError) {
        _clearInitTimeout();
        return GestureDetector(
          onDoubleTap: () {
            widget.onDoubleTap?.call();
            setState(() => _showLike = true);
            Future<void>.delayed(const Duration(milliseconds: 550), () {
              if (!mounted) return;
              setState(() => _showLike = false);
            });
          },
          onTap: () => v.isPlaying ? controller!.pause() : controller!.play(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: v.size.width,
                  height: v.size.height,
                  child: VideoPlayer(controller!),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _showLike ? 1 : 0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: _showLike ? 1 : 0.6,
                  child: const Icon(Icons.favorite_rounded, size: 96, color: Color(0xFFFF2D55)),
                ),
              ),
            ],
          ),
        );
      }

      final hasError = v?.hasError ?? false;
      if (failed || hasError || _initTimedOut) {
        if (kDebugMode) {
          debugPrint(
            '[Explore] video_failed index=${widget.index} reel=${widget.reel.id} hasError=$hasError timedOut=$_initTimedOut err=${controller?.value.errorDescription}',
          );
        }
        final reason = hasError ? 'controller_error' : 'init_timeout';
        final key = '${widget.reel.id}:$reason';
        if (_trackedVideoErrorKey != key) {
          _trackedVideoErrorKey = key;
          try {
            final err = controller?.value.errorDescription;
            unawaited(
              ref.read(analyticsRepositoryProvider).track(
                    eventName: 'reel_video_playback_fail',
                    entityType: 'reel',
                    entityId: widget.reel.id,
                    meta: {
                      'index': widget.index,
                      'reason': reason,
                      if (err != null) 'error': err,
                    },
                  ),
            );
          } catch (_) {}
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            LuxuryNetworkImage(
              imageUrl: thumbRef,
              fallbackUrl: (ref.watch(brandAssetUrlProvider('default_reel_thumbnail')) ?? '').trim(),
              bucket: 'reels',
              borderRadius: BorderRadius.zero,
            ),
            const ColoredBox(color: Colors.black54),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not play video',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _initTimedOut = false);
                        ref.read(exploreReelPlayerWindowProvider.notifier).retryIndex(index: widget.index, reel: widget.reel);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x66FFFFFF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      if (controller == null || !controller.value.isInitialized) {
        _initTimer ??= Timer(const Duration(seconds: 20), () {
          if (!mounted) return;
          setState(() {
            _initTimedOut = true;
          });
        });
        return Stack(
          fit: StackFit.expand,
          children: [
            LuxuryNetworkImage(
              imageUrl: thumbRef,
              fallbackUrl: (ref.watch(brandAssetUrlProvider('default_reel_thumbnail')) ?? '').trim(),
              bucket: 'reels',
              borderRadius: BorderRadius.zero,
            ),
            const ColoredBox(color: Colors.black54),
            const Center(child: LuxuryLoader()),
          ],
        );
      }
    }

    final thumb = (widget.reel.thumbnailPath ?? '').trim().isNotEmpty
        ? widget.reel.thumbnailPath
        : (widget.reel.thumbnailUrl ?? '').trim().isNotEmpty
            ? widget.reel.thumbnailUrl
            : null;
    final full = (widget.reel.mediaPath ?? '').trim().isNotEmpty
        ? widget.reel.mediaPath
        : widget.reel.mediaUrl.trim().isNotEmpty
            ? widget.reel.mediaUrl.trim()
            : null;
    final imageUrl = widget.isActive ? (full ?? thumb) : thumb;
    return GestureDetector(
      onDoubleTap: () {
        widget.onDoubleTap?.call();
        setState(() => _showLike = true);
        Future<void>.delayed(const Duration(milliseconds: 550), () {
          if (!mounted) return;
          setState(() => _showLike = false);
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          LuxuryNetworkImage(
            imageUrl: imageUrl,
            fallbackUrl: (ref.watch(brandAssetUrlProvider('default_reel_thumbnail')) ?? '').trim(),
            bucket: 'reels',
            borderRadius: BorderRadius.zero,
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: _showLike ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: _showLike ? 1 : 0.6,
              child: const Icon(Icons.favorite_rounded, size: 96, color: Color(0xFFFF2D55)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  final String reelId;

  const _ReportSheet({required this.reelId});

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String _reason = 'Spam';
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final reasons = const ['Spam', 'Inappropriate', 'Harassment', 'Copyright', 'Other'];

    Future<void> submit() async {
      if (_submitting) return;
      setState(() => _submitting = true);
      final client = ref.read(supabaseClientProvider);
      final me = client.auth.currentUser;
      if (me == null) {
        if (context.mounted) {
          Navigator.of(context).pop();
          context.push('/auth/sign-in?next=/discover');
        }
        return;
      }

      final details = _detailsController.text.trim();
      try {
        await client.from('reel_reports').insert({
          'reel_id': widget.reelId,
          'profile_id': me.id,
          'reason': _reason,
          if (details.isNotEmpty) 'details': details,
        });
      } catch (_) {}

      try {
        await ref.read(analyticsRepositoryProvider).track(
              eventName: 'reel_report',
              entityType: 'reel',
              entityId: widget.reelId,
              meta: {'reason': _reason, if (details.isNotEmpty) 'details': details},
            );
      } catch (_) {}

      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks. We’ll review your report.')));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C0C0C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Report reel',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final r in reasons)
                      ChoiceChip(
                        label: Text(r),
                        selected: _reason == r,
                        onSelected: (_) => setState(() => _reason = r),
                        selectedColor: AppTheme.gold.withValues(alpha: 0.22),
                        backgroundColor: const Color(0xFF111111),
                        side: BorderSide(color: AppTheme.border),
                        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _reason == r ? AppTheme.gold : AppTheme.text,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _detailsController,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add details (optional)',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF111111),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.55))),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(_submitting ? 'Submitting…' : 'Submit', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String reelId;
  final String variant;

  const _CommentsSheet({required this.reelId, required this.variant});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final comments = ref.watch(reelCommentsProvider(widget.reelId));
    final myId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C0C0C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 54,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: AsyncValueWidget(
                  value: comments,
                  error: (e, st) {
                    return Center(
                      child: HallaqEmptyState(
                        title: 'Comments unavailable',
                        description: 'Tap retry to load comments.',
                        actionLabel: 'Retry',
                        onAction: () => ref.invalidate(reelCommentsProvider(widget.reelId)),
                      ),
                    );
                  },
                  data: (items) {
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LuxuryNetworkImage(
                              imageUrl: (ref.watch(brandAssetUrlProvider('default_empty_state')) ?? '').trim(),
                              fallbackUrl: (ref.watch(brandAssetUrlProvider('default_empty_state')) ?? '').trim(),
                              height: 180,
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Start the conversation',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to comment on this cut.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = items[index];
                        final canDelete = myId != null && c.profileId == myId;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HallaqAvatar(imageUrl: c.authorAvatarUrl, size: 34, variant: widget.variant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF151515).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.85)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.authorName ?? 'Customer',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      c.text,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.25),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (canDelete) ...[
                              const SizedBox(width: 10),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  HallaqHaptics.selection();
                                  try {
                                    await ref.read(reelCommentsRepositoryProvider).delete(c.id);
                                    ref.read(exploreFeedControllerProvider.notifier).bumpCommentsCount(widget.reelId, delta: -1);
                                    ref.invalidate(reelCommentsProvider(widget.reelId));
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Action failed. Please try again.')));
                                  }
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0F0F0F).withValues(alpha: 0.70),
                                    border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.85)),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textMuted),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(hintText: AppLocalizations.of(context).writeAComment),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _submit,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: AppTheme.goldGradient,
                          boxShadow: AppTheme.softShadow(opacity: 0.35),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      await ref.read(reelCommentsRepositoryProvider).add(reelId: widget.reelId, text: text);
      ref.read(exploreFeedControllerProvider.notifier).bumpCommentsCount(widget.reelId);
      ref.invalidate(reelCommentsProvider(widget.reelId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t post your comment. Please try again.')));
    }
  }
}
