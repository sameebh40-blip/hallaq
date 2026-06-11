import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../geo/location_controller.dart';
import '../haptics/hallaq_haptics.dart';
import '../l10n/app_localizations.dart';
import '../localization/area_controller.dart';
import '../localization/cities_repository.dart';
import '../theme/app_theme.dart';
import '../../features/home/presentation/home_reels_controller.dart';
import '../../features/home/presentation/nearby_barbers_controller.dart';
import '../../features/home/presentation/nearby_shops_controller.dart';
import '../../features/offers/data/offers_repository.dart';
import 'async_value_widget.dart';
import 'hallaq_ui.dart';
import 'luxury_icon_button.dart';

class CityPickerSheet extends ConsumerStatefulWidget {
  const CityPickerSheet({super.key});

  @override
  ConsumerState<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(areaControllerProvider).trim();

    final cities = ref.watch(activeCitiesProvider);

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
                    l10n.currentAreaLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            HallaqCard(
              glass: true,
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.searchHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: AsyncValueWidget<List<City>>(
                value: cities,
                loading: const Center(child: Padding(padding: EdgeInsets.all(18), child: HallaqLoading())),
                onRetry: () => ref.invalidate(activeCitiesProvider),
                data: (items) {
                  final list = items
                      .where((c) {
                        final q = _query.trim().toLowerCase();
                        if (q.isEmpty) return true;
                        return c.name.toLowerCase().contains(q) || c.country.toLowerCase().contains(q);
                      })
                      .toList(growable: false);

                  return ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final c = list[index];
                      final isSelected = selected.toLowerCase() == c.name.toLowerCase();
                      return HallaqCard(
                        glass: true,
                        onTap: () async {
                          HallaqHaptics.selection();
                          await ref.read(locationControllerProvider).saveManualLatLng(lat: c.lat, lng: c.lng);
                          await ref.read(areaControllerProvider.notifier).setArea(c.name);
                          ref.invalidate(nearbyShopsControllerProvider);
                          ref.invalidate(nearbyBarbersControllerProvider);
                          ref.invalidate(homeReelsControllerProvider);
                          ref.invalidate(activeOffersProvider);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppTheme.gold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${c.name}, ${c.country}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: list.length,
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
