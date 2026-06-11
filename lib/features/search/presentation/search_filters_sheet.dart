import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../data/search_filters.dart';

class SearchFiltersSheet extends ConsumerWidget {
  const SearchFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    final notifier = ref.read(searchFiltersProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            HallaqCard(
              glass: true,
              child: Column(
                children: [
                  _SortRow(
                    sort: filters.sort,
                    onChanged: notifier.setSort,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Max distance',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          filters.maxDistanceKm == null ? 'Any' : '${filters.maxDistanceKm!.toStringAsFixed(0)} km',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.gold,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: AppTheme.gold,
                      overlayColor: AppTheme.gold.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      min: 1,
                      max: 50,
                      divisions: 49,
                      value: (filters.maxDistanceKm ?? 50).clamp(1, 50),
                      onChanged: (v) => notifier.setMaxDistanceKm(v >= 50 ? null : v),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Price range',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          (filters.minPriceBhd == null && filters.maxPriceBhd == null)
                              ? 'Any'
                              : '${(filters.minPriceBhd ?? 0).toStringAsFixed(0)}–${(filters.maxPriceBhd ?? 50).toStringAsFixed(0)} BHD',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.gold,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: AppTheme.gold,
                      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                      overlayColor: AppTheme.gold.withValues(alpha: 0.12),
                    ),
                    child: RangeSlider(
                      min: 0,
                      max: 50,
                      divisions: 50,
                      values: RangeValues(
                        (filters.minPriceBhd ?? 0).clamp(0, 50),
                        (filters.maxPriceBhd ?? 50).clamp(0, 50),
                      ),
                      onChanged: (v) {
                        final minV = v.start;
                        final maxV = v.end;
                        if (minV <= 0.01 && maxV >= 49.99) {
                          notifier.setMinPriceBhd(null);
                          notifier.setMaxPriceBhd(null);
                          return;
                        }
                        notifier.setMinPriceBhd(minV);
                        notifier.setMaxPriceBhd(maxV);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: filters.openNow,
                    onChanged: notifier.setOpenNow,
                    title: const Text('Open Now'),
                    activeThumbColor: AppTheme.gold,
                    activeTrackColor: AppTheme.gold.withValues(alpha: 0.25),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  SwitchListTile.adaptive(
                    value: filters.availableToday,
                    onChanged: notifier.setAvailableToday,
                    title: const Text('Available Today'),
                    activeThumbColor: AppTheme.gold,
                    activeTrackColor: AppTheme.gold.withValues(alpha: 0.25),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  SwitchListTile.adaptive(
                    value: filters.verifiedOnly,
                    onChanged: notifier.setVerifiedOnly,
                    title: const Text('Verified Only'),
                    activeThumbColor: AppTheme.gold,
                    activeTrackColor: AppTheme.gold.withValues(alpha: 0.25),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  SwitchListTile.adaptive(
                    value: filters.homeServiceOnly,
                    onChanged: notifier.setHomeServiceOnly,
                    title: const Text('Home Service'),
                    activeThumbColor: AppTheme.gold,
                    activeTrackColor: AppTheme.gold.withValues(alpha: 0.25),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HallaqButton(
                    label: 'Reset',
                    variant: HallaqButtonVariant.ghost,
                    onPressed: notifier.reset,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HallaqButton(
                    label: 'Apply',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  final SearchSort sort;
  final ValueChanged<SearchSort> onChanged;

  const _SortRow({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text('Sort', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
          SegmentedButton<SearchSort>(
            segments: const [
              ButtonSegment(value: SearchSort.nearest, label: Text('Nearest')),
              ButtonSegment(value: SearchSort.topRated, label: Text('Top Rated')),
            ],
            selected: {sort},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              onChanged(s.first);
            },
          ),
        ],
      ),
    );
  }
}
