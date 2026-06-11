import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/geo/maps_launcher.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/models/booking.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/gold_shimmer.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/hallaq_mascot.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/presentation/widgets/booking_cancel_reason_sheet.dart';
import '../../reviews/presentation/write_review_screen.dart';
import '../models/my_booking_card.dart';
import 'my_bookings_controller.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  static const _tabs = <BookingsTab>[
    BookingsTab.upcoming,
    BookingsTab.completed,
    BookingsTab.cancelled,
  ];

  BookingsTab get _currentTab => _tabs[_tab.clamp(0, _tabs.length - 1)];

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      header: LuxuryTopBar(
        title: Text('Bookings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.refresh_rounded,
          onPressed: () => ref.read(myBookingsControllerProvider(_currentTab).notifier).refresh(),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: HallaqCard(
              glass: true,
              padding: const EdgeInsets.all(8),
              child: _BookingsTabs(
                value: _tab,
                labels: const [
                  'Upcoming',
                  'Completed',
                  'Cancelled',
                ],
                onChanged: (v) {
                  HallaqHaptics.selection();
                  setState(() => _tab = v);
                },
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _BookingsTabList(
                key: ValueKey(_currentTab),
                tab: _currentTab,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsTabs extends StatelessWidget {
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _BookingsTabs({required this.value, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final children = <Widget>[];
        for (var i = 0; i < labels.length; i++) {
          final selected = i == value;
          final pad = compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          children.add(
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: pad,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: selected ? AppTheme.gold : AppTheme.surface,
                    border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.75) : AppTheme.border),
                    boxShadow: selected ? AppTheme.goldGlow(opacity: 0.10, blur: 18, y: 10) : AppTheme.softShadow(opacity: 0.08),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: selected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (i != labels.length - 1) children.add(const SizedBox(width: 10));
        }
        return Row(children: children);
      },
    );
  }
}

class _BookingsTabList extends ConsumerStatefulWidget {
  final BookingsTab tab;

  const _BookingsTabList({super.key, required this.tab});

  @override
  ConsumerState<_BookingsTabList> createState() => _BookingsTabListState();
}

class _BookingsTabListState extends ConsumerState<_BookingsTabList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final remaining = _controller.position.extentAfter;
    if (remaining < 320) {
      ref.read(myBookingsControllerProvider(widget.tab).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(myBookingsControllerProvider(widget.tab));
    final notifier = ref.read(myBookingsControllerProvider(widget.tab).notifier);

    if (value.isLoading && (value.valueOrNull == null || value.valueOrNull!.isEmpty)) {
      return ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        itemBuilder: (_, __) => const _BookingCardSkeleton(),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemCount: 4,
      );
    }

    return RefreshIndicator(
      color: AppTheme.gold,
      backgroundColor: AppTheme.surface,
      onRefresh: () async => notifier.refresh(),
      child: value.when(
        data: (items) {
          if (items.isEmpty) {
            return _EmptyBookingsState(tab: widget.tab, onDiscover: () => context.go('/discover'));
          }
          return ListView.separated(
            key: PageStorageKey('bookings_${widget.tab.name}'),
            controller: _controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemBuilder: (_, index) => _BookingCard(item: items[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemCount: items.length,
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, _) {
          return _BookingsErrorState(
            onRetry: () => notifier.refresh(),
          );
        },
      ),
    );
  }
}

class _EmptyBookingsState extends StatelessWidget {
  final BookingsTab tab;
  final VoidCallback onDiscover;

  const _EmptyBookingsState({required this.tab, required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (tab) {
      BookingsTab.completed => ('No completed bookings', 'Your completed bookings will appear here.'),
      BookingsTab.cancelled => ('No cancelled bookings', 'Cancelled bookings will appear here.'),
      _ => ('No upcoming bookings', 'Your upcoming appointments will appear here.'),
    };

    return Center(
      child: HallaqEmptyState(
        title: title,
        description: description,
        showMascot: true,
        actionLabel: 'Discover Barbers',
        onAction: onDiscover,
      ),
    );
  }
}

class _BookingsErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _BookingsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HallaqEmptyState(
        title: 'Could not load bookings',
        description: 'Please try again.',
        showMascot: true,
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final MyBookingCard item;

  const _BookingCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = item.startAt.toLocal();
    final end = item.endAt.toLocal();
    final languageCode = Localizations.localeOf(context).languageCode;
    final serviceName = (languageCode.toLowerCase().startsWith('ar') ? item.serviceNameAr : item.serviceNameEn) ??
        item.serviceNameEn ??
        item.serviceNameAr ??
        '';

    final statusUi = _statusUi(
      item.status,
      autoAccepted: item.autoAccepted,
      rescheduledAt: item.rescheduledAt,
      cancelOrigin: item.cancelOrigin,
    );
    final amount = item.amountBhd;
    final canDirections = (item.googleMapsUrl ?? '').trim().isNotEmpty || (item.lat != null && item.lng != null);
    final canCall = (item.shopPhone ?? '').trim().isNotEmpty;
    final canWhatsApp = (item.shopWhatsApp ?? '').trim().isNotEmpty;
    final canReschedule = item.startAt.isAfter(DateTime.now()) && (item.status == BookingStatus.pending || item.status == BookingStatus.rescheduled);
    final canCancel = item.status == BookingStatus.pending ||
        item.status == BookingStatus.confirmed ||
        item.status == BookingStatus.inProgress ||
        item.status == BookingStatus.rescheduled;

    Future<void> cancel() async {
      final reason = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BookingCancelReasonSheet(),
      );
      if (reason == null || !context.mounted) return;
      try {
        await ref.read(bookingRepositoryProvider).cancelBooking(item.id, reason: reason);
        ref.invalidate(myBookingsControllerProvider(BookingsTab.upcoming));
        ref.invalidate(myBookingsControllerProvider(BookingsTab.completed));
        ref.invalidate(myBookingsControllerProvider(BookingsTab.cancelled));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    void bookAgain() {
      final params = <String, String>{
        if ((item.barberId ?? '').trim().isNotEmpty) 'barberId': item.barberId!.trim(),
        if ((item.shopId ?? '').trim().isNotEmpty) 'shopId': item.shopId!.trim(),
        if ((item.serviceId ?? '').trim().isNotEmpty) 'serviceId': item.serviceId!.trim(),
        'bookAgain': '1',
      };
      context.push(Uri(path: Routes.bookingNew, queryParameters: params).toString());
    }

    void leaveReview() {
      final targetType = item.barberId != null ? 'barber' : 'shop';
      final targetId = item.barberId ?? item.shopId ?? '';
      if (targetId.trim().isEmpty) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => WriteReviewScreen(
          targetType: targetType,
          targetId: targetId,
          bookingId: item.id,
        ),
      );
    }

    return HallaqCard(
      glass: true,
      onTap: () => context.push('/booking/${item.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HallaqAvatar(
                imageUrl: item.barberAvatarUrl,
                size: 54,
                fallbackUrl: HallaqImages.barberAvatar(variant: '01'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              (item.barberName ?? '').isEmpty ? (item.shopName ?? '') : (item.barberName ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (item.barberVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if ((item.shopName ?? '').trim().isNotEmpty)
                        Text(
                          item.shopName!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                      if ((item.locationText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.locationText!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusUi.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusUi.color.withValues(alpha: 0.18)),
                ),
                child: Text(
                  statusUi.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusUi.color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (amount != null)
                Text(
                  _formatBd(amount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${MaterialLocalizations.of(context).formatFullDate(start)} • ${TimeOfDay.fromDateTime(start).format(context)} - ${TimeOfDay.fromDateTime(end).format(context)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (item.paymentMethodLabel ?? '').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (item.status == BookingStatus.completed)
            Row(
              children: [
                Expanded(
                  child: HallaqButton(
                    label: 'Leave Review',
                    icon: Icons.star_border_rounded,
                    variant: HallaqButtonVariant.secondary,
                    onPressed: leaveReview,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HallaqButton(
                    label: 'Book Again',
                    icon: Icons.refresh_rounded,
                    onPressed: bookAgain,
                  ),
                ),
              ],
            )
          else if (item.status == BookingStatus.cancelled || item.status == BookingStatus.noShow)
            HallaqButton(
              label: 'Book Again',
              icon: Icons.refresh_rounded,
              onPressed: bookAgain,
            )
          else if (canReschedule || canCancel)
            Column(
              children: [
                HallaqButton(
                  label: 'View Details',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => context.push('/booking/${item.id}'),
                ),
                if (canReschedule) const SizedBox(height: 10),
                if (canReschedule)
                  HallaqButton(
                    label: 'Reschedule',
                    icon: Icons.update_rounded,
                    variant: HallaqButtonVariant.secondary,
                    onPressed: () => context.push('/booking/${item.id}?openReschedule=1'),
                  ),
                if (canCancel) const SizedBox(height: 10),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: cancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Booking'),
                  ),
              ],
            )
          else
            Column(
              children: [
                HallaqButton(
                  label: 'View Details',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => context.push('/booking/${item.id}'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    LuxuryIconButton(icon: Icons.map_outlined, onPressed: canDirections ? () => _openMaps(item.googleMapsUrl, item.lat, item.lng) : null),
                    const SizedBox(width: 10),
                    LuxuryIconButton(
                      icon: Icons.call_outlined,
                      onPressed: canCall
                          ? () {
                              final v = (item.shopPhone ?? '').trim();
                              if (v.isEmpty) return;
                              launchUrl(Uri.parse('tel:$v'), mode: LaunchMode.externalApplication);
                            }
                          : null,
                    ),
                    const SizedBox(width: 10),
                    LuxuryIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: canWhatsApp
                          ? () {
                              final v = (item.shopWhatsApp ?? '').trim();
                              if (v.isEmpty) return;
                              final phone = v.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
                              launchUrl(Uri.parse('https://wa.me/$phone'), mode: LaunchMode.externalApplication);
                            }
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: HallaqButton(
                        label: 'Directions',
                        icon: Icons.directions_rounded,
                        variant: HallaqButtonVariant.secondary,
                        onPressed: canDirections ? () => _openMaps(item.googleMapsUrl, item.lat, item.lng) : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BookingCardSkeleton extends StatelessWidget {
  const _BookingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GoldShimmer(width: 58, height: 58, borderRadius: BorderRadius.circular(14)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoldShimmer(width: 120, height: 14, borderRadius: BorderRadius.circular(12)),
                    const SizedBox(height: 8),
                    GoldShimmer(width: 160, height: 12, borderRadius: BorderRadius.circular(12)),
                    const SizedBox(height: 6),
                    GoldShimmer(width: 140, height: 12, borderRadius: BorderRadius.circular(12)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GoldShimmer(width: 78, height: 26, borderRadius: BorderRadius.circular(999)),
            ],
          ),
          const SizedBox(height: 14),
          GoldShimmer(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 10),
          GoldShimmer(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 10),
          GoldShimmer(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 10),
          GoldShimmer(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: GoldShimmer(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(16))),
              const SizedBox(width: 12),
              Expanded(child: GoldShimmer(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(16))),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _openMaps(String? googleMapsUrl, double? lat, double? lng) async {
  await launchDirections(googleMapsUrl: googleMapsUrl, lat: lat, lng: lng);
}

String _formatBd(double amount) {
  final v = amount.abs();
  final s = (v - v.round()).abs() < 0.0001 ? v.toStringAsFixed(0) : v.toStringAsFixed(3);
  return 'BD $s';
}

({String label, Color color}) _statusUi(
  BookingStatus status, {
  bool autoAccepted = false,
  DateTime? rescheduledAt,
  BookingCancelOrigin cancelOrigin = BookingCancelOrigin.unknown,
}) {
  if ((rescheduledAt != null || status == BookingStatus.rescheduled) && status != BookingStatus.cancelled) {
    return (label: 'Rescheduled', color: AppTheme.gold);
  }
  return switch (status) {
    BookingStatus.pending => (label: 'Pending', color: AppTheme.gold),
    BookingStatus.confirmed => autoAccepted ? (label: 'Automatically Accepted', color: AppTheme.gold) : (label: 'Confirmed', color: AppTheme.success),
    BookingStatus.inProgress => (label: 'In progress', color: AppTheme.gold),
    BookingStatus.rescheduled => (label: 'Rescheduled', color: AppTheme.gold),
    BookingStatus.cancelled => switch (cancelOrigin) {
        BookingCancelOrigin.barber => (label: 'Cancelled by Barber', color: AppTheme.error),
        BookingCancelOrigin.shop => (label: 'Cancelled by Shop', color: AppTheme.error),
        BookingCancelOrigin.client => (label: 'Cancelled by Client', color: AppTheme.error),
        _ => (label: 'Cancelled', color: AppTheme.error),
      },
    BookingStatus.noShow => (label: 'No-show', color: AppTheme.error),
    BookingStatus.completed => (label: 'Completed', color: AppTheme.success),
  };
}
