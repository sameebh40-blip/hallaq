import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';

typedef FollowRef = ({String targetType, String targetId});

final myFollowsProvider = FutureProvider<List<FollowRef>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return [];
  final data = await client.from('follows').select('target_type,target_id').eq('profile_id', user.id);
  final list = (data as List).cast<Map<String, dynamic>>();
  return list
      .map((e) => (targetType: (e['target_type'] as String?) ?? '', targetId: (e['target_id'] as String?) ?? ''))
      .where((e) => e.targetType.isNotEmpty && e.targetId.isNotEmpty)
      .toList();
});

final _barberByIdProvider = FutureProvider.family<Barber, String>((ref, id) async {
  return ref.watch(barberRepositoryProvider).getById(id);
});

final _shopByIdProvider = FutureProvider.family<Barbershop, String>((ref, id) async {
  return ref.watch(shopRepositoryProvider).getById(id);
});

class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({super.key});

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(myFollowsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.following, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _Segmented(
              value: _tab,
              labels: [l10n.trendingBarbers, l10n.featuredShops],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<FollowRef>>(
              value: value,
              data: (items) {
                final filtered = items.where((e) => e.targetType == (_tab == 0 ? 'barber' : 'shop')).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: HallaqEmptyState(
                      title: l10n.following,
                      description: _tab == 0 ? 'You are not following any barbers yet.' : 'You are not following any shops yet.',
                      showMascot: true,
                      actionLabel: l10n.exploreNow,
                      onAction: () => context.go('/discover'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  itemBuilder: (context, index) {
                    final f = filtered[index];
                    return f.targetType == 'barber' ? _FollowingBarberTile(id: f.targetId) : _FollowingShopTile(id: f.targetId);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingBarberTile extends ConsumerWidget {
  final String id;

  const _FollowingBarberTile({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueWidget<Barber>(
      value: ref.watch(_barberByIdProvider(id)),
      data: (b) {
        final v = ((b.id.hashCode.abs() % 6) + 1).toString().padLeft(2, '0');
        return LuxuryCard(
          onTap: () => context.push('/barber/${b.slug.isNotEmpty ? b.slug : b.id}'),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LuxuryNetworkImage(
                  imageUrl: b.avatarUrl,
                  fallbackUrl: HallaqImages.barberAvatar(variant: v),
                  width: 54,
                  height: 54,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (b.badgeVerified) const Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.area ?? AppLocalizations.of(context).bahrain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        );
      },
    );
  }
}

class _FollowingShopTile extends ConsumerWidget {
  final String id;

  const _FollowingShopTile({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueWidget<Barbershop>(
      value: ref.watch(_shopByIdProvider(id)),
      data: (s) {
        final v = ((s.id.hashCode.abs() % 6) + 1).toString().padLeft(2, '0');
        return LuxuryCard(
          onTap: () => context.push('/shop/${s.id}'),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LuxuryNetworkImage(
                  imageUrl: s.logoUrl,
                  fallbackUrl: HallaqImages.goldBarberPoleIllustration(variant: v),
                  width: 54,
                  height: 54,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (s.badgeVerified) const Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.area ?? AppLocalizations.of(context).bahrain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Segmented({required this.value, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selected ? AppTheme.gold.withValues(alpha: 0.16) : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? AppTheme.text : AppTheme.textMuted,
                          fontWeight: FontWeight.w900,
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
