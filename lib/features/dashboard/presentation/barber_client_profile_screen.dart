import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/offer.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../barber/data/barber_clients_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../offers/data/offer_targets_repository.dart';
import '../../offers/data/offers_management_repository.dart';

class _ClientProfileVm {
  final String profileId;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final int totalVisits;
  final double spentBhd;
  final int noShowCount;
  final DateTime? lastVisitAt;
  final String? favoriteServiceId;
  final String? favoriteServiceName;
  final String loyaltyTier;
  final String? note;
  final List<Map<String, dynamic>> history;

  const _ClientProfileVm({
    required this.profileId,
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.totalVisits,
    required this.spentBhd,
    required this.noShowCount,
    required this.lastVisitAt,
    required this.favoriteServiceId,
    required this.favoriteServiceName,
    required this.loyaltyTier,
    required this.note,
    required this.history,
  });
}

final _barberOffersForSendProvider = FutureProvider.autoDispose<List<Offer>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <Offer>[];
  final offers = await ref.watch(offersManagementRepositoryProvider).listForBarber(barber.id, limit: 100);
  final now = DateTime.now();
  return offers
      .where((o) => o.active)
      .where((o) => o.validFrom == null || !o.validFrom!.isAfter(now))
      .where((o) => o.validTo == null || !o.validTo!.isBefore(now))
      .toList(growable: false);
});

final _barberClientProfileProvider = FutureProvider.autoDispose.family<_ClientProfileVm?, String>((ref, customerProfileId) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(barberClientsRepositoryProvider);

  final profileData = await client.from('profiles').select('id, full_name, phone, avatar_url').eq('id', customerProfileId).limit(1);
  final profileList = (profileData as List);
  final profile = profileList.isEmpty ? const <String, dynamic>{} : Map<String, dynamic>.from(profileList.first as Map);
  final name = ((profile['full_name'] as String?) ?? '').trim();
  final phone = (profile['phone'] as String?)?.trim();
  final avatarUrl = (profile['avatar_url'] as String?)?.trim();

  final bookingsData = await client
      .from('bookings')
      .select('id, start_at, end_at, status, total_price, price_bhd, currency, service_id, services(name, name_en, name_ar)')
      .eq('barber_id', barber.id)
      .eq('customer_profile_id', customerProfileId)
      .order('start_at', ascending: false)
      .limit(60);

  final history = (bookingsData as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);

  var totalVisits = 0;
  var spent = 0.0;
  var noShows = 0;
  DateTime? lastVisitAt;
  final serviceCounts = <String, int>{};

  for (final b in history) {
    final status = (b['status'] as String?) ?? '';
    final startAt = DateTime.tryParse((b['start_at'] as String?) ?? '')?.toLocal();
    final currency = (b['currency'] as String?) ?? 'BHD';
    final price = (b['price_bhd'] as num?)?.toDouble() ?? (b['total_price'] as num?)?.toDouble() ?? 0;
    final serviceId = (b['service_id'] as String?)?.trim();

    if (status == 'completed') {
      totalVisits += 1;
      if (currency == 'BHD') spent += price;
      if (startAt != null) {
        lastVisitAt = lastVisitAt == null ? startAt : (startAt.isAfter(lastVisitAt!) ? startAt : lastVisitAt);
      }
      if (serviceId != null && serviceId.isNotEmpty) serviceCounts[serviceId] = (serviceCounts[serviceId] ?? 0) + 1;
    }
    if (status == 'no_show') noShows += 1;
  }

  String? favoriteServiceId;
  String? favoriteServiceName;
  if (serviceCounts.isNotEmpty) {
    final best = serviceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    favoriteServiceId = best.first.key;
    final found = history
        .map((e) => (e['services'] as Map?) == null ? null : Map<String, dynamic>.from(e['services'] as Map))
        .whereType<Map<String, dynamic>>()
        .map((e) => ((e['name_en'] as String?)?.trim().isNotEmpty ?? false) ? (e['name_en'] as String?)?.trim() : (e['name'] as String?)?.trim())
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    favoriteServiceName = found.isEmpty ? null : found.first;
  }

  final tier = (totalVisits <= 1)
      ? 'New'
      : (totalVisits >= 5 || spent >= 80)
          ? 'VIP'
          : 'Regular';

  final note = await repo.getNote(barberId: barber.id, customerProfileId: customerProfileId);

  return _ClientProfileVm(
    profileId: customerProfileId,
    name: name.isEmpty ? 'Customer' : name,
    phone: phone,
    avatarUrl: avatarUrl,
    totalVisits: totalVisits,
    spentBhd: spent,
    noShowCount: noShows,
    lastVisitAt: lastVisitAt,
    favoriteServiceId: favoriteServiceId,
    favoriteServiceName: favoriteServiceName,
    loyaltyTier: tier,
    note: note,
    history: history,
  );
});

class BarberClientProfileScreen extends ConsumerStatefulWidget {
  final String customerProfileId;

  const BarberClientProfileScreen({super.key, required this.customerProfileId});

  @override
  ConsumerState<BarberClientProfileScreen> createState() => _BarberClientProfileScreenState();
}

class _BarberClientProfileScreenState extends ConsumerState<BarberClientProfileScreen> {
  final _note = TextEditingController();
  bool _noteInitialized = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _digitsOnly(String input) => input.trim().replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _call(String phone) async {
    final cleaned = _digitsOnly(phone);
    if (cleaned.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: cleaned), mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    final cleaned = _digitsOnly(phone).replaceAll('+', '');
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('https://wa.me/$cleaned'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_barberClientProfileProvider(widget.customerProfileId));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Client', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: IconButton(
          onPressed: () => ref.invalidate(_barberClientProfileProvider(widget.customerProfileId)),
          icon: const Icon(Icons.refresh_rounded),
          color: AppTheme.text,
        ),
      ),
      child: AsyncValueWidget<_ClientProfileVm?>(
        value: value,
        onRetry: () => ref.invalidate(_barberClientProfileProvider(widget.customerProfileId)),
        data: (vm) {
          if (vm == null) {
            return const Center(
              child: HallaqEmptyState(
                title: 'Client not found',
                description: 'This client profile is not available.',
                showMascot: true,
              ),
            );
          }

          if (!_noteInitialized) {
            _note.text = (vm.note ?? '').trim();
            _noteInitialized = true;
          }

          final last = vm.lastVisitAt == null ? null : DateFormat('MMM d, yyyy').format(vm.lastVisitAt!);
          final canCall = (vm.phone ?? '').trim().isNotEmpty;

          Future<void> saveNote() async {
            final barber = await ref.read(myBarberProvider.future);
            if (barber == null) return;
            try {
              final updated = await ref.read(barberClientsRepositoryProvider).upsertNote(
                    barberId: barber.id,
                    customerProfileId: vm.profileId,
                    note: _note.text,
                  );
              _note.text = updated;
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved.')));
            } catch (e) {
              if (!context.mounted) return;
              showErrorSnackBar(context, e);
            }
          }

          Future<void> bookAgain() async {
            final barber = await ref.read(myBarberProvider.future);
            if (barber == null) return;
            final params = <String, String>{'barberId': barber.id, 'bookAgain': '1'};
            final fav = (vm.favoriteServiceId ?? '').trim();
            if (fav.isNotEmpty) params['serviceId'] = fav;
            context.push(Uri(path: Routes.bookingNew, queryParameters: params).toString());
          }

          Future<void> sendOffer() async {
            final barber = await ref.read(myBarberProvider.future);
            if (barber == null) return;
            final offers = await ref.read(_barberOffersForSendProvider.future);
            if (!context.mounted) return;
            final offerId = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _SendOfferSheet(offers: offers),
            );
            if (offerId == null || !context.mounted) return;
            try {
              await ref.read(offerTargetsRepositoryProvider).sendOfferToCustomer(
                    offerId: offerId,
                    customerProfileId: vm.profileId,
                    barberId: barber.id,
                    shopId: (barber.shopId ?? '').trim().isEmpty ? null : barber.shopId,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent.')));
            } catch (e) {
              if (!context.mounted) return;
              showErrorSnackBar(context, e);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HallaqAvatar(imageUrl: vm.avatarUrl, size: 60),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vm.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (canCall) vm.phone!.trim(),
                                  if (last != null) 'last $last',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
                          ),
                          child: Text(vm.loyaltyTier, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _Metric(label: 'Visits', value: '${vm.totalVisits}')),
                        const SizedBox(width: 10),
                        Expanded(child: _Metric(label: 'Spent', value: 'BD ${vm.spentBhd.toStringAsFixed(3)}')),
                        const SizedBox(width: 10),
                        Expanded(child: _Metric(label: 'No-shows', value: '${vm.noShowCount}')),
                      ],
                    ),
                    if ((vm.favoriteServiceName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Favorite service', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Text((vm.favoriteServiceName ?? '').trim(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canCall ? () => _call(vm.phone!) : null,
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canCall ? () => _whatsapp(vm.phone!) : null,
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: HallaqButton(label: 'Book again', icon: Icons.calendar_month_rounded, onPressed: bookAgain)),
                        const SizedBox(width: 10),
                        Expanded(child: HallaqButton(label: 'Send offer', icon: Icons.local_offer_outlined, onPressed: sendOffer)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Add private notes about this client',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    HallaqButton(label: 'Save note', icon: Icons.check_rounded, onPressed: saveNote),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Booking history', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (vm.history.isEmpty)
                const HallaqEmptyState(
                  title: 'No bookings',
                  description: 'Bookings with this client will appear here.',
                  compact: true,
                  showMascot: true,
                )
              else
                ...vm.history.map((b) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _BookingHistoryTile(row: b))),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _BookingHistoryTile extends StatelessWidget {
  final Map<String, dynamic> row;

  const _BookingHistoryTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse((row['start_at'] as String?) ?? '')?.toLocal();
    final end = DateTime.tryParse((row['end_at'] as String?) ?? '')?.toLocal();
    final status = (row['status'] as String?) ?? '';
    final total = (row['price_bhd'] as num?)?.toDouble() ?? (row['total_price'] as num?)?.toDouble() ?? 0;
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = ((service?['name_en'] as String?)?.trim().isNotEmpty ?? false)
        ? (service?['name_en'] as String?)!.trim()
        : ((service?['name'] as String?) ?? 'Service');

    final when = start == null ? '' : DateFormat('MMM d, yyyy · h:mm a').format(start);
    final duration = (start == null || end == null) ? null : end.difference(start).inMinutes;

    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  [when, if (duration != null && duration > 0) '${duration}m'].where((e) => e.trim().isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BD ${total.toStringAsFixed(3)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
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
