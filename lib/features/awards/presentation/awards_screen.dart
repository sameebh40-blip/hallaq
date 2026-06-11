import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';

class AwardsScreen extends ConsumerWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final barbers = ref.watch(trendingBarbersProvider);
    final shops = ref.watch(featuredShopsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.awards, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          HallaqCard(
            glass: true,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LuxuryNetworkImage(
                        imageUrl: null,
                        fallbackUrl: HallaqImages.awardsHero(),
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
                              Colors.black.withValues(alpha: 0.86),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 16,
                      end: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.monthlyRankings, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 18, color: AppTheme.gold),
                              const SizedBox(width: 8),
                              Text(
                                l10n.bahrain,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
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
          const SizedBox(height: 16),
          SectionHeader(title: l10n.monthlyRankings),
          AsyncValueWidget<List<Barber>>(
            value: barbers,
            data: (items) {
              final list = items.isEmpty ? <Barber>[] : items;
              return Column(
                children: [
                  _LeaderboardBlock(title: l10n.awardBestBarber, winners: list.take(3).map((b) => (name: b.displayName, subtitle: b.area ?? l10n.bahrain, route: '/barber/${b.slug.isNotEmpty ? b.slug : b.id}')).toList()),
                  const SizedBox(height: 12),
                  _LeaderboardBlock(title: l10n.awardBestFade, winners: list.skip(1).take(3).map((b) => (name: b.displayName, subtitle: b.area ?? l10n.bahrain, route: '/barber/${b.slug.isNotEmpty ? b.slug : b.id}')).toList()),
                  const SizedBox(height: 12),
                  _LeaderboardBlock(title: l10n.awardMostBooked, winners: list.skip(2).take(3).map((b) => (name: b.displayName, subtitle: b.area ?? l10n.bahrain, route: '/barber/${b.slug.isNotEmpty ? b.slug : b.id}')).toList()),
                  const SizedBox(height: 12),
                  _LeaderboardBlock(title: l10n.awardRisingStar, winners: list.reversed.take(3).map((b) => (name: b.displayName, subtitle: b.area ?? l10n.bahrain, route: '/barber/${b.slug.isNotEmpty ? b.slug : b.id}')).toList()),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          AsyncValueWidget<List<Barbershop>>(
            value: shops,
            data: (items) {
              final list = items.isEmpty ? <Barbershop>[] : items;
              return _LeaderboardBlock(
                title: l10n.awardBestShop,
                winners: list.take(3).map((s) => (name: s.name, subtitle: s.area ?? l10n.bahrain, route: '/shop/${s.id}')).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardBlock extends StatelessWidget {
  final String title;
  final List<({String name, String subtitle, String route})> winners;

  const _LeaderboardBlock({required this.title, required this.winners});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...List.generate(winners.length, (i) {
            final w = winners[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == winners.length - 1 ? 0 : 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(w.route),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(w.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
