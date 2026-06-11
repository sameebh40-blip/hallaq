import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/saved_items_repository.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final barbers = ref.watch(mySavedBarbersProvider);
    final shops = ref.watch(mySavedShopsProvider);
    final reels = ref.watch(mySavedReelsCardsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Saved', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _Tabs(
              value: _tab,
              labels: const ['Barbers', 'Shops', 'Reels'],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              1 => AsyncValueWidget<List<Barbershop>>(
                  value: shops,
                  onRetry: () => ref.invalidate(mySavedShopsProvider),
                  data: (items) => _ShopsList(items: items),
                ),
              2 => AsyncValueWidget<List<SavedReelCard>>(
                  value: reels,
                  onRetry: () => ref.invalidate(mySavedReelsCardsProvider),
                  data: (items) => _ReelsList(items: items),
                ),
              _ => AsyncValueWidget<List<Barber>>(
                  value: barbers,
                  onRetry: () => ref.invalidate(mySavedBarbersProvider),
                  data: (items) => _BarbersList(items: items),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Tabs({required this.value, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final tabWidth = compact ? 110.0 : (constraints.maxWidth - 8) / labels.length;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(labels.length, (i) {
                final selected = i == value;
                return SizedBox(
                  width: tabWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: selected ? AppTheme.gold : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: selected ? Colors.black : AppTheme.textMuted,
                                fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _BarbersList extends ConsumerWidget {
  final List<Barber> items;

  const _BarbersList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No saved barbers yet',
          description: 'Barbers you save will appear here for quick booking later.',
          compact: true,
          showMascot: true,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemBuilder: (_, i) => _BarberTile(
        barber: items[i],
        onRemove: () async {
          try {
            await ref.read(savedItemsRepositoryProvider).remove(itemType: 'barber', itemId: items[i].id);
            ref.invalidate(mySavedBarbersProvider);
          } catch (e) {
            if (context.mounted) showErrorSnackBar(context, e);
          }
        },
        onOpen: () => context.push('/barber/${items[i].id}'),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _ShopsList extends ConsumerWidget {
  final List<Barbershop> items;

  const _ShopsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No saved shops yet',
          description: 'Your favorite shops will show up here for faster access.',
          compact: true,
          showMascot: true,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemBuilder: (_, i) => _ShopTile(
        shop: items[i],
        onRemove: () async {
          try {
            await ref.read(savedItemsRepositoryProvider).remove(itemType: 'shop', itemId: items[i].id);
            ref.invalidate(mySavedShopsProvider);
          } catch (e) {
            if (context.mounted) showErrorSnackBar(context, e);
          }
        },
        onOpen: () => context.push('/shop/${items[i].id}'),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _ReelsList extends ConsumerWidget {
  final List<SavedReelCard> items;

  const _ReelsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: HallaqEmptyState(
          title: 'No saved reels yet',
          description: 'Save inspiring reels and they will be ready here anytime.',
          compact: true,
          showMascot: true,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemBuilder: (_, i) {
        final r = items[i];
        return HallaqCard(
          glass: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LuxuryNetworkImage(
                  imageUrl: r.thumbnailUrl,
                  fallbackUrl: HallaqImages.blackGoldBackground(),
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved Reel', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      (r.caption ?? '').trim().isEmpty ? r.id : r.caption!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await ref.read(savedItemsRepositoryProvider).remove(itemType: 'reel', itemId: r.id);
                    ref.invalidate(mySavedReelsCardsProvider);
                  } catch (e) {
                    if (context.mounted) showErrorSnackBar(context, e);
                  }
                },
                icon: const Icon(Icons.bookmark_remove_outlined, color: AppTheme.error),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _BarberTile extends StatelessWidget {
  final Barber barber;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _BarberTile({required this.barber, required this.onOpen, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final verified = barber.badgeVerified;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipOval(
              child: LuxuryNetworkImage(
                imageUrl: barber.avatarUrl,
                fallbackUrl: HallaqImages.barberAvatar(),
                width: 54,
                height: 54,
                borderRadius: BorderRadius.circular(999),
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
                          barber.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(barber.area ?? '', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.favorite_rounded, color: AppTheme.gold)),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final Barbershop shop;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _ShopTile({required this.shop, required this.onOpen, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final verified = shop.badgeVerified;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LuxuryNetworkImage(
                imageUrl: shop.logoUrl,
                fallbackUrl: HallaqImages.barberShopExterior(),
                width: 54,
                height: 54,
                borderRadius: BorderRadius.circular(14),
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
                          shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(shop.area ?? '', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.bookmark_rounded, color: AppTheme.gold)),
          ],
        ),
      ),
    );
  }
}
