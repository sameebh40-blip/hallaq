import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/formatters/currency_formatters.dart';
import '../../../core/formatters/number_formatters.dart';
import '../../../core/geo/eta.dart';
import '../../../core/geo/distance_providers.dart';
import '../../../core/geo/geo_distance.dart';
import '../../../core/geo/location_controller.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/social_proof/hallaq_badges.dart';
import '../../../core/social_proof/social_proof_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_badges_row.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../data/recent_searches_controller.dart';
import '../data/search_filters.dart';
import '../data/search_repository.dart';
import '../data/search_suggestions_repository.dart';
import 'search_filters_sheet.dart';

enum _SearchMode { barbers, shops }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _debouncer = Debouncer(const Duration(milliseconds: 280));
  static const int _pageSize = 20;

  _SearchMode _mode = _SearchMode.barbers;
  String _query = '';
  String? _seedQuery;
  String? _seedTab;

  var _requestId = 0;
  var _offset = 0;
  var _hasMore = true;
  var _loading = false;
  var _loadingMore = false;
  Object? _error;
  String _activeQuery = '';
  SearchFilters _activeFilters = const SearchFilters();

  List<Barber> _barbers = const [];
  List<Barbershop> _shops = const [];
  ProviderSubscription<SearchFilters>? _filtersSub;
  ProviderSubscription<AsyncValue<({double lat, double lng})?>>? _latLngSub;

  void _setQuery(String v) {
    _controller.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
    );
    setState(() => _query = v);
    _triggerSearch(immediate: true);
  }

  Future<void> _saveRecent(String v) async {
    await ref.read(recentSearchesProvider.notifier).add(v);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _filtersSub = ref.listenManual<SearchFilters>(searchFiltersProvider, (prev, next) {
      if (prev == next) return;
      if (_query.trim().isEmpty) return;
      _triggerSearch(immediate: true);
    });
    _latLngSub = ref.listenManual<AsyncValue<({double lat, double lng})?>>(effectiveLatLngProvider, (prev, next) {
      if (_query.trim().isEmpty) return;
      _triggerSearch(immediate: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    _filtersSub?.close();
    _latLngSub?.close();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _triggerSearch();
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      _loadMore();
    }
  }

  void _triggerSearch({bool immediate = false}) {
    if (immediate) {
      _runSearch(reset: true);
      return;
    }
    _debouncer.run(() {
      if (!mounted) return;
      _runSearch(reset: true);
    });
  }

  Future<void> _runSearch({required bool reset}) async {
    final q = (reset ? _query : _activeQuery).trim();
    if (q.isEmpty) {
      setState(() {
        _activeQuery = '';
        _offset = 0;
        _hasMore = true;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _barbers = const [];
        _shops = const [];
      });
      return;
    }

    final filters = reset ? ref.read(searchFiltersProvider) : _activeFilters;
    final requestId = ++_requestId;

    setState(() {
      _error = null;
      if (reset) {
        _activeQuery = q;
        _activeFilters = filters;
        _offset = 0;
        _hasMore = true;
        _barbers = const [];
        _shops = const [];
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final repo = ref.read(searchRepositoryProvider);
      final list = _mode == _SearchMode.barbers
          ? await repo.searchBarbers(q, filters: filters, limit: _pageSize, offset: _offset)
          : await repo.searchShops(q, filters: filters, limit: _pageSize, offset: _offset);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _offset += list.length;
        _hasMore = list.length == _pageSize;
        _loading = false;
        _loadingMore = false;
        if (_mode == _SearchMode.barbers) {
          _barbers = [..._barbers, ...(list as List<Barber>)];
        } else {
          _shops = [..._shops, ...(list as List<Barbershop>)];
        }
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_query.trim().isEmpty) return;
    if (!_hasMore || _loading || _loadingMore) return;
    await _runSearch(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seeded = GoRouterState.of(context).uri.queryParameters['q'];
    if (seeded != null && seeded.trim().isNotEmpty && seeded != _seedQuery) {
      _seedQuery = seeded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setQuery(seeded.trim());
      });
    }
    final seededTab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (seededTab != null && seededTab.trim().isNotEmpty && seededTab != _seedTab) {
      _seedTab = seededTab;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final v = seededTab.trim().toLowerCase();
        setState(() => _mode = v == 'shops' ? _SearchMode.shops : _SearchMode.barbers);
        _triggerSearch(immediate: true);
      });
    }
    final recent = ref.watch(recentSearchesProvider);
    final items = _mode == _SearchMode.barbers ? _barbers : _shops;

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.searchHint, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        trailing: LuxuryIconButton(
          icon: Icons.tune_rounded,
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const SearchFiltersSheet(),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: LuxuryCard(
              glass: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      onSubmitted: (v) => _saveRecent(v),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.searchHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _activeQuery = '';
                          _offset = 0;
                          _hasMore = true;
                          _loading = false;
                          _loadingMore = false;
                          _error = null;
                          _barbers = const [];
                          _shops = const [];
                        });
                      },
                      child: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Segmented(
              value: _mode,
              options: [
                (_SearchMode.barbers, l10n.searchBarbers),
                (_SearchMode.shops, l10n.searchShops),
              ],
              onChanged: (v) {
                setState(() => _mode = v);
                _triggerSearch(immediate: true);
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _query.trim().isEmpty
                ? _SearchSuggestions(
                    recent: recent,
                    onSelect: (q) async {
                      await _saveRecent(q);
                      _setQuery(q);
                    },
                    onClearRecent: () => ref.read(recentSearchesProvider.notifier).clear(),
                    onRemoveRecent: (q) => ref.read(recentSearchesProvider.notifier).remove(q),
                  )
                : _loading && items.isEmpty
                    ? const Center(child: HallaqLoading())
                    : _error != null && items.isEmpty
                        ? Center(
                            child: LuxuryCard(
                              glass: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.somethingWentWrongTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.somethingWentWrongDescription,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 10),
                                  LuxuryButton(
                                    label: l10n.tryAgain,
                                    onPressed: () => _triggerSearch(immediate: true),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : items.isEmpty
                            ? Center(child: Text(l10n.noResults, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted)))
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                                itemBuilder: (context, index) {
                                  if (_loadingMore && index >= items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: HallaqLoading()),
                                    );
                                  }
                                  if (_mode == _SearchMode.barbers) {
                                    return _BarberResultTile(barber: (items as List<Barber>)[index], variant: (index + 1).toString().padLeft(2, '0'));
                                  }
                                  return _ShopResultTile(shop: (items as List<Barbershop>)[index], variant: (index + 1).toString().padLeft(2, '0'));
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemCount: items.length + (_loadingMore ? 1 : 0),
                              ),
          ),
        ],
      ),
    );
  }
}

class _ShopResultTile extends ConsumerWidget {
  final Barbershop shop;
  final String variant;

  const _ShopResultTile({required this.shop, required this.variant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider((targetType: 'shop', targetId: shop.id)));
    final badges = badgesForShop(context, shop).take(2).toList();
    final loc = ref.watch(effectiveLatLngProvider).valueOrNull;
    final km = shop.distanceKm ??
        ((loc != null && shop.lat != null && shop.lng != null)
            ? haversineKm(fromLat: loc.lat, fromLng: loc.lng, toLat: shop.lat!, toLng: shop.lng!)
            : null);
    final eta = km == null ? null : etaLabelFromMinutes(etaMinutesFromKm(km));
    final starting = shop.startingPriceBhd;

    return LuxuryCard(
      glass: true,
      onTap: () => context.push('/shop/${shop.id}'),
      child: Row(
        children: [
          LuxuryNetworkImage(
            imageUrl: shop.logoUrl,
            fallbackUrl: HallaqImages.shopCover(variant: variant),
            width: 52,
            height: 52,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(shop.area ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  HallaqBadgesRow(badges: badges),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                  const SizedBox(width: 6),
                  Text(shop.ratingAvg.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              if (km != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 6),
                    Text('${km.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(eta ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
              ],
              if (starting != null) ...[
                Text(
                  'From ${CurrencyFormatters.bd(starting)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.gold),
                  const SizedBox(width: 6),
                  Text(NumberFormatters.compactInt(followers.value ?? 0), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _BarberResultTile extends ConsumerWidget {
  final Barber barber;
  final String variant;

  const _BarberResultTile({required this.barber, required this.variant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider((targetType: 'barber', targetId: barber.id)));
    final badges = badgesForBarber(context, barber).take(3).toList();
    final loc = ref.watch(effectiveLatLngProvider).valueOrNull;
    final directKm = (loc != null && barber.lat != null && barber.lng != null)
        ? haversineKm(fromLat: loc.lat, fromLng: loc.lng, toLat: barber.lat!, toLng: barber.lng!)
        : null;
    final shopKm = barber.shopId != null ? ref.watch(distanceToShopKmProvider(barber.shopId!)).valueOrNull : null;
    final kmValue = barber.distanceKm ?? directKm ?? shopKm;
    final kmDisplay = (kmValue ?? _seededDistanceKm(barber.id)).toStringAsFixed(1);
    final eta = kmValue == null ? null : etaLabelFromMinutes(etaMinutesFromKm(kmValue));
    final starting = barber.startingPriceBhd;

    return LuxuryCard(
      glass: true,
      onTap: () => context.push('/barber/${barber.slug.isNotEmpty ? barber.slug : barber.id}'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: SizedBox(
          height: 122,
          child: Stack(
            children: [
              Positioned.fill(
                child: LuxuryNetworkImage(
                  imageUrl: null,
                  fallbackUrl: HallaqImages.professionalBarberPortrait(variant: variant),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      HallaqAvatar(imageUrl: barber.avatarUrl, size: 54, variant: variant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              barber.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              barber.area ?? 'Bahrain',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                            ),
                            if (badges.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              HallaqBadgesRow(badges: badges),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 6),
                              Text(
                                barber.ratingAvg.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 6),
                              Text(
                                '$kmDisplay km',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          if (eta != null) ...[
                            const SizedBox(height: 6),
                            Text(eta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 10),
                          if (starting != null) ...[
                            Text(
                              'From ${CurrencyFormatters.bd(starting)}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 6),
                              Text(
                                NumberFormatters.compactInt(followers.value ?? 0),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _seededDistanceKm(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final raw = (h % 58) / 10.0;
  return (0.8 + raw).clamp(0.6, 7.2).toDouble();
}

class _SearchSuggestions extends ConsumerWidget {
  final List<String> recent;
  final ValueChanged<String> onSelect;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onRemoveRecent;

  const _SearchSuggestions({
    required this.recent,
    required this.onSelect,
    required this.onClearRecent,
    required this.onRemoveRecent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(searchCategoriesProvider);
    final popular = ref.watch(popularServiceQueriesProvider);
    final barbers = ref.watch(trendingBarbersProvider);
    final shops = ref.watch(featuredShopsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(l10n.recentSearches, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              GestureDetector(
                onTap: () {
                  HallaqHaptics.selection();
                  onClearRecent();
                },
                child: Text(l10n.clear, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: recent
                .map(
                  (q) => GestureDetector(
                    onTap: () {
                      HallaqHaptics.selection();
                      onSelect(q);
                    },
                    onLongPress: () {
                      HallaqHaptics.selection();
                      onRemoveRecent(q);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFF141414),
                        border: Border.all(color: const Color(0xFF2A2A2A).withValues(alpha: 0.85)),
                      ),
                      child: Text(q, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
        ],
        categories.when(
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.categoriesTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items
                      .take(12)
                      .map(
                        (c) => GestureDetector(
                          onTap: () {
                            HallaqHaptics.selection();
                            onSelect(c.displayName(l10n.locale.languageCode));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFF0F0F0F).withValues(alpha: 0.7),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Text(
                              c.displayName(l10n.locale.languageCode),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: HallaqLoading()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        popular.when(
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trendingSearches, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items
                      .take(12)
                      .map(
                        (q) => GestureDetector(
                          onTap: () {
                            HallaqHaptics.selection();
                            onSelect(q);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFF0F0F0F).withValues(alpha: 0.7),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Text(q, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: HallaqLoading()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        LuxuryCard(
          glass: true,
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppTheme.gold),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.typeToSearch, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted))),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(l10n.trendingBarbers, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: AsyncValueWidget<List<Barber>>(
            value: barbers,
            data: (items) {
              final list = items.take(6).toList();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _MiniBarberCard(barber: list[index], variant: (index + 1).toString().padLeft(2, '0')),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Text(l10n.featuredShops, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: AsyncValueWidget<List<Barbershop>>(
            value: shops,
            data: (items) {
              final list = items.take(6).toList();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _MiniShopCard(shop: list[index], variant: (index + 1).toString().padLeft(2, '0')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniBarberCard extends ConsumerWidget {
  final Barber barber;
  final String variant;

  const _MiniBarberCard({required this.barber, required this.variant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider((targetType: 'barber', targetId: barber.id)));
    final badges = badgesForBarber(context, barber).take(2).toList();
    return SizedBox(
      width: 220,
      child: LuxuryCard(
        onTap: () => context.push('/barber/${barber.slug.isNotEmpty ? barber.slug : barber.id}'),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: SizedBox(
            height: 126,
            child: Stack(
              children: [
                Positioned.fill(
                  child: LuxuryNetworkImage(
                    imageUrl: null,
                    fallbackUrl: HallaqImages.professionalBarberPortrait(variant: variant),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 12,
                  top: 12,
                  end: 12,
                  child: badges.isEmpty ? const SizedBox.shrink() : HallaqBadgesRow(badges: badges),
                ),
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      HallaqAvatar(imageUrl: barber.avatarUrl, size: 44, variant: variant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              barber.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              barber.area ?? 'Bahrain',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 6),
                              Text(
                                barber.ratingAvg.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 6),
                              Text(
                                NumberFormatters.compactInt(followers.value ?? 0),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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

class _MiniShopCard extends ConsumerWidget {
  final Barbershop shop;
  final String variant;

  const _MiniShopCard({required this.shop, required this.variant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider((targetType: 'shop', targetId: shop.id)));
    final badges = badgesForShop(context, shop).take(2).toList();
    return SizedBox(
      width: 260,
      child: LuxuryCard(
        onTap: () => context.push('/shop/${shop.id}'),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            children: [
              Positioned.fill(
                child: LuxuryNetworkImage(
                  imageUrl: shop.coverUrl,
                  fallbackUrl: HallaqImages.shopCover(variant: variant),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(shop.area ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      HallaqBadgesRow(badges: badges, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(shop.ratingAvg.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(width: 12),
                        const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(NumberFormatters.compactInt(followers.value ?? 0), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                      ],
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
}

class _Segmented extends StatelessWidget {
  final _SearchMode value;
  final List<(_SearchMode, String)> options;
  final ValueChanged<_SearchMode> onChanged;

  const _Segmented({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final opt = options[i];
          final selected = opt.$1 == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HallaqHaptics.selection();
                onChanged(opt.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: selected ? AppTheme.goldGradient : null,
                ),
                child: Center(
                  child: Text(
                    opt.$2,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.black : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
