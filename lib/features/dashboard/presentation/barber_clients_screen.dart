import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_clients_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../offers/data/offer_targets_repository.dart';
import '../../offers/data/offers_management_repository.dart';
import '../../../core/models/offer.dart';

enum _ClientFilter { all, vip, regular, fresh }

class BarberClientsScreen extends ConsumerStatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  ConsumerState<BarberClientsScreen> createState() => _BarberClientsScreenState();
}

class _BarberClientsScreenState extends ConsumerState<BarberClientsScreen> {
  _ClientFilter _filter = _ClientFilter.all;

  bool _isVip(BarberClientSummary c) => c.loyaltyTier == 'VIP';
  bool _isFresh(BarberClientSummary c) => c.loyaltyTier == 'New';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(myBarberClientsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: const SizedBox.shrink(),
        title: Text('Clients', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: IconButton(
          onPressed: () => ref.invalidate(myBarberClientsProvider),
          icon: const Icon(Icons.refresh_rounded),
          color: AppTheme.text,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: _FilterChip(label: 'All', selected: _filter == _ClientFilter.all, onTap: () => setState(() => _filter = _ClientFilter.all))),
                const SizedBox(width: 10),
                Expanded(child: _FilterChip(label: 'VIP', selected: _filter == _ClientFilter.vip, onTap: () => setState(() => _filter = _ClientFilter.vip))),
                const SizedBox(width: 10),
                Expanded(child: _FilterChip(label: 'Regular', selected: _filter == _ClientFilter.regular, onTap: () => setState(() => _filter = _ClientFilter.regular))),
                const SizedBox(width: 10),
                Expanded(child: _FilterChip(label: 'New', selected: _filter == _ClientFilter.fresh, onTap: () => setState(() => _filter = _ClientFilter.fresh))),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<BarberClientSummary>>(
              value: value,
              onRetry: () => ref.invalidate(myBarberClientsProvider),
              data: (items) {
                final filtered = items.where((c) {
                  return switch (_filter) {
                    _ClientFilter.all => true,
                    _ClientFilter.vip => _isVip(c),
                    _ClientFilter.fresh => _isFresh(c),
                    _ClientFilter.regular => !_isVip(c) && !_isFresh(c),
                  };
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return Center(
                    child: HallaqEmptyState(
                      title: 'No clients',
                      description: 'Clients will appear after bookings are created.',
                      compact: true,
                      showMascot: true,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  itemBuilder: (context, i) => _ClientRow(client: filtered[i], vip: _isVip(filtered[i])),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold.withValues(alpha: 0.18) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.55) : AppTheme.border),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: selected ? AppTheme.gold : AppTheme.text),
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends ConsumerWidget {
  final BarberClientSummary client;
  final bool vip;

  const _ClientRow({required this.client, required this.vip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = client.lastVisitAt == null ? null : DateFormat('MMM d, yyyy').format(client.lastVisitAt!.toLocal());
    Future<void> open() async {
      context.push('${Routes.barberManageClients}/${client.profileId}');
    }

    Future<void> call() async {
      final phone = (client.phone ?? '').trim();
      if (phone.isEmpty) return;
      await launchUrl(Uri(scheme: 'tel', path: phone), mode: LaunchMode.externalApplication);
    }

    Future<void> whatsapp() async {
      final phone = (client.phone ?? '').trim().replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
      if (phone.isEmpty) return;
      await launchUrl(Uri.parse('https://wa.me/$phone'), mode: LaunchMode.externalApplication);
    }

    Future<void> sendOffer() async {
      final barber = await ref.read(myBarberProvider.future);
      if (barber == null) return;
      final offers = await ref.read(offersManagementRepositoryProvider).listForBarber(barber.id, limit: 100);
      final now = DateTime.now();
      final active = offers
          .where((o) => o.active)
          .where((o) => o.validFrom == null || !o.validFrom!.isAfter(now))
          .where((o) => o.validTo == null || !o.validTo!.isBefore(now))
          .toList(growable: false);

      if (!context.mounted) return;
      final offerId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SendOfferSheet(offers: active),
      );
      if (offerId == null || !context.mounted) return;
      try {
        await ref.read(offerTargetsRepositoryProvider).sendOfferToCustomer(
              offerId: offerId,
              customerProfileId: client.profileId,
              barberId: barber.id,
              shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent.')));
      } catch (_) {}
    }

    return HallaqCard(
      glass: true,
      onTap: open,
      child: Row(
        children: [
          HallaqAvatar(imageUrl: client.avatarUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if ((client.loyaltyTier).trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
                        ),
                        child: Text(client.loyaltyTier, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${client.totalVisits} visits${last == null ? '' : ' · last $last'}${(client.favoriteServiceName ?? '').trim().isEmpty ? '' : ' · ${(client.favoriteServiceName ?? '').trim()}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
                if ((client.phone ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    (client.phone ?? '').trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BD ${client.spentBhd.toStringAsFixed(3)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${client.noShowCount} no-shows', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              IconButton(
                onPressed: (client.phone ?? '').trim().isEmpty ? null : call,
                icon: const Icon(Icons.call_rounded),
                color: AppTheme.text,
              ),
              IconButton(
                onPressed: (client.phone ?? '').trim().isEmpty ? null : whatsapp,
                icon: const Icon(Icons.chat_rounded),
                color: AppTheme.text,
              ),
              IconButton(
                onPressed: sendOffer,
                icon: const Icon(Icons.local_offer_outlined),
                color: AppTheme.text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendOfferSheet extends StatelessWidget {
  final List<Offer> offers;

  const _SendOfferSheet({required this.offers});

  String _label(Offer offer) {
    return switch (offer.offerType) {
      'fixed' => offer.discountAmount == null ? 'DISCOUNT' : '${offer.discountAmount!.toStringAsFixed(3)} BHD OFF',
      'package' => 'PACKAGE',
      _ => offer.discountPercent == null ? 'DISCOUNT' : '${offer.discountPercent!.toStringAsFixed(0)}% OFF',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send offer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (offers.isEmpty)
                  const HallaqEmptyState(
                    title: 'No active offers',
                    description: 'Create an offer first, then you can send it to clients.',
                    compact: true,
                    showMascot: true,
                  )
                else
                  ...offers.take(10).map((o) {
                    final label = _label(o);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(o.id),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          alignment: Alignment.centerLeft,
                          side: BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                              ),
                              child: const Icon(Icons.local_offer_outlined, color: AppTheme.gold, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  }),
                OutlinedButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
