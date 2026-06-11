import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../haptics/hallaq_haptics.dart';
import '../geo/location_controller.dart';
import '../l10n/app_localizations.dart';
import '../localization/area_controller.dart';
import '../localization/bahrain_areas.dart';
import '../theme/app_theme.dart';
import 'hallaq_ui.dart';
import 'luxury_icon_button.dart';

class AreaPickerSheet extends ConsumerStatefulWidget {
  const AreaPickerSheet({super.key});

  @override
  ConsumerState<AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends ConsumerState<AreaPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(areaControllerProvider);
    final isAr = l10n.locale.languageCode == 'ar';

    final list = BahrainAreas.items
        .where((a) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return a.en.toLowerCase().contains(q) || a.ar.toLowerCase().contains(q);
        })
        .toList();

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
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final a = list[index];
                  final label = isAr ? a.ar : a.en;
                  final isSelected = selected == a.en;
                  return HallaqCard(
                    glass: true,
                    onTap: () async {
                      HallaqHaptics.selection();
                      await ref.read(locationControllerProvider).saveAreaFallback(a.en);
                      await ref.read(areaControllerProvider.notifier).setArea(a.en);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppTheme.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                        if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: list.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
