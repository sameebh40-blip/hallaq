import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/geo/maps_launcher.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/role.dart';
import '../../../core/routing/routes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_availability_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/booking_repository.dart';
import 'widgets/booking_cancel_reason_sheet.dart';

class BookingDetailsVm {
  final Booking booking;
  final String customerName;
  final String? customerPhone;
  final String? customerAvatarUrl;
  final String serviceName;
  final String barberName;
  final String? barberAvatarUrl;
  final bool barberVerified;
  final String shopName;
  final String? shopPhone;
  final String? shopWhatsApp;
  final String? shopAddress;
  final String? shopArea;
  final String? shopGoogleMapsUrl;
  final double? shopLat;
  final double? shopLng;
  final String paymentLabel;
  final String? cancelledByLabel;
  final String? cancelReason;

  const BookingDetailsVm({
    required this.booking,
    required this.customerName,
    required this.customerPhone,
    required this.customerAvatarUrl,
    required this.serviceName,
    required this.barberName,
    required this.barberAvatarUrl,
    required this.barberVerified,
    required this.shopName,
    required this.shopPhone,
    required this.shopWhatsApp,
    required this.shopAddress,
    required this.shopArea,
    required this.shopGoogleMapsUrl,
    required this.shopLat,
    required this.shopLng,
    required this.paymentLabel,
    required this.cancelledByLabel,
    required this.cancelReason,
  });
}

final bookingDetailsProvider = FutureProvider.autoDispose.family<BookingDetailsVm?, String>((ref, bookingId) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(bookingRepositoryProvider);
  final booking = await repo.getBookingOverviewById(bookingId);
  if (booking == null) return null;

  final client = ref.watch(supabaseClientProvider);
  String customerName = 'Customer';
  String? customerPhone;
  String? customerAvatarUrl;
  String barberName = (booking.barberName ?? '').trim();
  String? barberAvatarUrl;
  bool barberVerified = false;
  String shopName = (booking.shopName ?? '').trim();
  String? shopPhone;
  String? shopWhatsApp;
  String? shopAddress;
  String? shopArea;
  String? shopGoogleMapsUrl;
  double? shopLat;
  double? shopLng;
  String paymentLabel = 'Cash at Shop';
  String? cancelledByLabel;
  String? cancelReason;
  String? barberProfileId;
  String? shopOwnerProfileId;

  try {
    final profile = await client
        .from('profiles')
        .select('id, full_name, phone, avatar_url')
        .eq('id', booking.customerProfileId)
        .maybeSingle();
    if (profile != null) {
      final m = Map<String, dynamic>.from(profile as Map);
      final fullName = (m['full_name'] as String?)?.trim() ?? '';
      customerName = fullName.isEmpty ? customerName : fullName;
      customerPhone = (m['phone'] as String?)?.trim();
      customerAvatarUrl = (m['avatar_url'] as String?)?.trim();
    }
  } catch (_) {}

  try {
    if ((booking.barberId ?? '').trim().isNotEmpty) {
      final barber = await client
          .from('barbers')
          .select('id, profile_id, display_name, avatar_url, badge_verified')
          .eq('id', booking.barberId!)
          .maybeSingle();
      if (barber != null) {
        final m = Map<String, dynamic>.from(barber as Map);
        final displayName = (m['display_name'] as String?)?.trim() ?? '';
        barberName = displayName.isEmpty ? barberName : displayName;
        barberAvatarUrl = (m['avatar_url'] as String?)?.trim();
        barberVerified = m['badge_verified'] == true;
        barberProfileId = (m['profile_id'] as String?)?.trim();
      }
    }
  } catch (_) {}

  try {
    if ((booking.shopId ?? '').trim().isNotEmpty) {
      final shop = await client
          .from('barbershops')
          .select('id, owner_profile_id, name, phone, whatsapp, area, address, google_maps_url, lat, lng')
          .eq('id', booking.shopId!)
          .maybeSingle();
      if (shop != null) {
        final m = Map<String, dynamic>.from(shop as Map);
        final name = (m['name'] as String?)?.trim() ?? '';
        shopName = name.isEmpty ? shopName : name;
        shopPhone = (m['phone'] as String?)?.trim();
        shopWhatsApp = (m['whatsapp'] as String?)?.trim();
        shopArea = (m['area'] as String?)?.trim();
        shopAddress = (m['address'] as String?)?.trim();
        shopGoogleMapsUrl = (m['google_maps_url'] as String?)?.trim();
        shopLat = (m['lat'] as num?)?.toDouble();
        shopLng = (m['lng'] as num?)?.toDouble();
        shopOwnerProfileId = (m['owner_profile_id'] as String?)?.trim();
      }
    }
  } catch (_) {}

  try {
    final raw = await client.from('bookings').select('payment_method, cancel_reason, cancelled_reason, cancelled_by_profile_id').eq('id', bookingId).maybeSingle();
    if (raw != null) {
      final m = Map<String, dynamic>.from(raw as Map);
      final method = (m['payment_method'] as String?)?.trim() ?? '';
      paymentLabel = switch (method) {
        'card' => 'Card',
        'benefitpay' => 'BenefitPay',
        'apple_pay' => 'Apple Pay',
        'stc_pay' => 'STC Pay',
        _ => 'Cash at Shop',
      };
      cancelReason = ((m['cancelled_reason'] as String?) ?? (m['cancel_reason'] as String?))?.trim();
      final by = (m['cancelled_by_profile_id'] as String?)?.trim();
      final viewerId = client.auth.currentUser?.id;
      if (booking.status == BookingStatus.cancelled) {
        if ((viewerId ?? '').trim().isNotEmpty && by == viewerId) {
          cancelledByLabel = 'You';
        } else if ((by ?? '').trim().isNotEmpty && by == booking.customerProfileId) {
          cancelledByLabel = 'Client';
        } else if ((by ?? '').trim().isNotEmpty && (barberProfileId ?? '').trim().isNotEmpty && by == barberProfileId) {
          cancelledByLabel = 'Barber';
        } else if ((by ?? '').trim().isNotEmpty && (shopOwnerProfileId ?? '').trim().isNotEmpty && by == shopOwnerProfileId) {
          cancelledByLabel = 'Shop';
        }
      }
    }
  } catch (_) {}

  final serviceName = (booking.serviceNameEn ?? booking.serviceNameAr ?? '').trim().isEmpty ? 'Service' : ((booking.serviceNameEn ?? booking.serviceNameAr)!).trim();

  return BookingDetailsVm(
    booking: booking,
    customerName: customerName,
    customerPhone: customerPhone,
    customerAvatarUrl: customerAvatarUrl,
    serviceName: serviceName,
    barberName: barberName.isEmpty ? 'Barber' : barberName,
    barberAvatarUrl: barberAvatarUrl,
    barberVerified: barberVerified,
    shopName: shopName.isEmpty ? 'Shop' : shopName,
    shopPhone: shopPhone,
    shopWhatsApp: shopWhatsApp,
    shopAddress: shopAddress,
    shopArea: shopArea,
    shopGoogleMapsUrl: shopGoogleMapsUrl,
    shopLat: shopLat,
    shopLng: shopLng,
    paymentLabel: paymentLabel,
    cancelledByLabel: cancelledByLabel,
    cancelReason: cancelReason,
  );
});

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final bool autoOpenReschedule;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.autoOpenReschedule = false,
  });

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  bool _didAutoOpenReschedule = false;

  @override
  Widget build(BuildContext context) {
    final bookingId = widget.bookingId;
    final vmValue = ref.watch(bookingDetailsProvider(bookingId));

    Future<void> call(String? phone) async {
      final value = (phone ?? '').trim();
      if (value.isEmpty) return;
      await launchUrl(Uri.parse('tel:$value'), mode: LaunchMode.externalApplication);
    }

    Future<void> whatsapp(String? phone) async {
      final raw = (phone ?? '').trim();
      if (raw.isEmpty) return;
      final normalized = raw.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
      if (normalized.isEmpty) return;
      await launchUrl(Uri.parse('https://wa.me/$normalized'), mode: LaunchMode.externalApplication);
    }

    Future<void> openCalendar(BookingDetailsVm vm) async {
      final booking = vm.booking;
      final startUtc = booking.startAt.toUtc();
      final endUtc = booking.endAt.toUtc();

      String fmt(DateTime dt) => DateFormat("yyyyMMdd'T'HHmmss'Z'").format(dt);

      final location = [vm.shopName, vm.shopArea, vm.shopAddress].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
      final url = Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': '${vm.serviceName} - ${vm.barberName}',
        'dates': '${fmt(startUtc)}/${fmt(endUtc)}',
        if (location.trim().isNotEmpty) 'location': location,
        'details': 'HALLAQ booking #${booking.id}',
      });
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    Future<void> openDirections(BookingDetailsVm vm) async {
      await launchDirections(googleMapsUrl: vm.shopGoogleMapsUrl, lat: vm.shopLat, lng: vm.shopLng);
    }

    Future<void> start(String id) async {
      await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: id, status: 'in_progress');
      ref.invalidate(bookingDetailsProvider(bookingId));
    }

    Future<void> done(String id) async {
      await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: id, status: 'completed');
      ref.invalidate(bookingDetailsProvider(bookingId));
    }

    Future<void> cancel(String id) async {
      final reason = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const BookingCancelReasonSheet(),
      );
      if (reason == null || !context.mounted) return;
      try {
        await ref.read(bookingRepositoryProvider).cancelBooking(id, reason: reason);
        ref.invalidate(bookingDetailsProvider(bookingId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      }
    }

    Future<void> reschedule(BookingDetailsVm vm) async {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _RescheduleBookingSheet(vm: vm),
      );
      ref.invalidate(bookingDetailsProvider(bookingId));
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Booking Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(icon: Icons.refresh_rounded, onPressed: () => ref.invalidate(bookingDetailsProvider(bookingId))),
      ),
      child: AsyncValueWidget<BookingDetailsVm?>(
        value: vmValue,
        onRetry: () => ref.invalidate(bookingDetailsProvider(bookingId)),
        data: (vm) {
          if (vm == null) {
            return const Center(
              child: HallaqEmptyState(
                title: 'Booking not found',
                description: 'This booking may have been deleted or you no longer have access.',
                showMascot: true,
              ),
            );
          }

          final booking = vm.booking;
          final startLocal = booking.startAt.toLocal();
          final endLocal = booking.endAt.toLocal();
          final dateText = DateFormat('EEE, d MMM yyyy').format(startLocal);
          final timeText = '${TimeOfDay.fromDateTime(startLocal).format(context)} - ${TimeOfDay.fromDateTime(endLocal).format(context)}';
          final locationText = [vm.shopArea, vm.shopAddress].where((e) => (e ?? '').trim().isNotEmpty).join(' • ');
          final status = _statusUi(booking.status);

          return FutureBuilder<AppUserRole>(
            future: ref.read(profileRepositoryProvider).getMyRoleFast(),
            builder: (context, snap) {
              final role = snap.data ?? AppUserRole.customer;
              final isCustomer = role == AppUserRole.customer;
              final canManage = role == AppUserRole.barber || role == AppUserRole.shopOwner || role == AppUserRole.admin;
              final canStart = canManage && (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.pending);
              final canDone = canManage && booking.status == BookingStatus.inProgress;
              final canCancel = (isCustomer || canManage) &&
                  (booking.status == BookingStatus.pending ||
                      booking.status == BookingStatus.confirmed ||
                      booking.status == BookingStatus.inProgress ||
                      booking.status == BookingStatus.rescheduled);
              final canReschedule = isCustomer &&
                  booking.startAt.isAfter(DateTime.now()) &&
                  (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed || booking.status == BookingStatus.rescheduled);

              if (widget.autoOpenReschedule && canReschedule && !_didAutoOpenReschedule) {
                _didAutoOpenReschedule = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  reschedule(vm);
                });
              }

              final primaryPhone = isCustomer ? vm.shopPhone : vm.customerPhone;
              final primaryWhatsApp = isCustomer ? vm.shopWhatsApp : vm.customerPhone;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  HallaqCard(
                    glass: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 360;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    HallaqAvatar(imageUrl: vm.barberAvatarUrl, size: 54),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  vm.barberName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                              if (vm.barberVerified) ...[
                                                const SizedBox(width: 6),
                                                Icon(Icons.verified_rounded, color: AppTheme.gold, size: 18),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            vm.shopName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!compact) ...[
                                      const SizedBox(width: 10),
                                      _StatusBadge(label: status.label, color: status.color),
                                    ],
                                  ],
                                ),
                                if (compact) ...[
                                  const SizedBox(height: 12),
                                  _StatusBadge(label: status.label, color: status.color),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(vm.serviceName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),
                        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Date', value: dateText),
                        _InfoRow(icon: Icons.schedule_rounded, label: 'Time', value: timeText),
                        _InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: locationText.isEmpty ? vm.shopName : locationText),
                        _InfoRow(icon: Icons.payments_outlined, label: 'Payment', value: vm.paymentLabel),
                        if (booking.status == BookingStatus.cancelled && (vm.cancelledByLabel ?? '').trim().isNotEmpty)
                          _InfoRow(icon: Icons.person_off_outlined, label: 'Cancelled by', value: vm.cancelledByLabel!.trim()),
                        if (booking.status == BookingStatus.cancelled && (vm.cancelReason ?? '').trim().isNotEmpty)
                          _InfoRow(icon: Icons.info_outline_rounded, label: 'Cancellation reason', value: vm.cancelReason!.trim()),
                        _InfoRow(icon: Icons.confirmation_number_outlined, label: 'Booking ID', value: booking.id),
                        if (booking.totalPrice != null)
                          _InfoRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Total',
                            value: 'BD ${booking.totalPrice!.toStringAsFixed(3)}',
                            valueColor: AppTheme.gold,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  HallaqCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if ((primaryPhone ?? '').trim().isNotEmpty)
                              _ActionPill(icon: Icons.call_rounded, label: isCustomer ? 'Call Shop' : 'Call Client', onTap: () => call(primaryPhone)),
                            if ((primaryWhatsApp ?? '').trim().isNotEmpty)
                              _ActionPill(icon: Icons.chat_rounded, label: 'WhatsApp', onTap: () => whatsapp(primaryWhatsApp)),
                            if (isCustomer && ((vm.shopGoogleMapsUrl ?? '').trim().isNotEmpty || (vm.shopLat != null && vm.shopLng != null)))
                              _ActionPill(icon: Icons.map_outlined, label: 'Directions', onTap: () => openDirections(vm)),
                            if (isCustomer) _ActionPill(icon: Icons.event_available_rounded, label: 'Add to Calendar', onTap: () => openCalendar(vm)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (canStart)
                    HallaqButton(
                      label: 'Start Booking',
                      icon: Icons.play_circle_outline_rounded,
                      onPressed: () => start(booking.id),
                    ),
                  if (canStart) const SizedBox(height: 10),
                  if (canDone)
                    HallaqButton(
                      label: 'Mark Completed',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () => done(booking.id),
                    ),
                  if (canDone) const SizedBox(height: 10),
                  if (canReschedule)
                    HallaqButton(
                      label: 'Reschedule Booking',
                      icon: Icons.update_rounded,
                      onPressed: () => reschedule(vm),
                    ),
                  if (canReschedule) const SizedBox(height: 10),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () => cancel(booking.id),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppTheme.error,
                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Booking'),
                    ),
                  const SizedBox(height: 10),
                  if (isCustomer)
                    OutlinedButton.icon(
                      onPressed: () {
                        final params = <String, String>{
                          if ((booking.barberId ?? '').trim().isNotEmpty) 'barberId': booking.barberId!.trim(),
                          if ((booking.shopId ?? '').trim().isNotEmpty) 'shopId': booking.shopId!.trim(),
                          if ((booking.serviceId ?? '').trim().isNotEmpty) 'serviceId': booking.serviceId!.trim(),
                          'bookAgain': '1',
                        };
                        context.push(Uri(path: Routes.bookingNew, queryParameters: params).toString());
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Book Again'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: valueColor ?? AppTheme.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
          color: AppTheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.gold),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RescheduleBookingSheet extends ConsumerStatefulWidget {
  final BookingDetailsVm vm;

  const _RescheduleBookingSheet({required this.vm});

  @override
  ConsumerState<_RescheduleBookingSheet> createState() => _RescheduleBookingSheetState();
}

class _RescheduleBookingSheetState extends ConsumerState<_RescheduleBookingSheet> {
  late DateTime _day = DateTime.now();
  TimeOfDay? _selected;
  bool _saving = false;

  int get _durationMin {
    final diff = widget.vm.booking.endAt.difference(widget.vm.booking.startAt).inMinutes;
    return diff > 0 ? diff : 30;
  }

  DateTime get _dayOnly => DateTime(_day.year, _day.month, _day.day);

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dayOnly.isAfter(DateTime.now()) ? _dayOnly : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(data: AppTheme.dark(), child: child!),
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final barberId = widget.vm.booking.barberId;
    if (barberId == null || barberId.trim().isEmpty) return const SizedBox.shrink();

    final timesValue = ref.watch(availableTimesForDayProvider((barberId: barberId, day: _dayOnly, durationMin: _durationMin)));

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          child: HallaqCard(
            glass: true,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reschedule Booking',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  LuxuryIconButton(icon: Icons.close_rounded, onPressed: _saving ? null : () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a new date and time for ${widget.vm.serviceName}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              HallaqButton(
                label: DateFormat('EEE, d MMM yyyy').format(_dayOnly),
                icon: Icons.calendar_today_rounded,
                variant: HallaqButtonVariant.secondary,
                onPressed: _saving ? null : () => _pickDay(context),
              ),
              const SizedBox(height: 16),
              Text('Available Times', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              timesValue.when(
                data: (times) {
                  if (times.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No available times for this day.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: times.map((t) {
                      final selected = _selected?.hour == t.hour && _selected?.minute == t.minute;
                      return GestureDetector(
                        onTap: _saving
                            ? null
                            : () {
                                HallaqHaptics.selection();
                                setState(() => _selected = t);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.gold : AppTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: selected ? AppTheme.gold : AppTheme.border),
                            boxShadow: selected ? AppTheme.goldGlow(opacity: 0.16, blur: 18, y: 10) : AppTheme.softShadow(opacity: 0.08),
                          ),
                          child: Text(
                            t.format(context),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: selected ? Colors.black : AppTheme.text),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Could not load times right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              HallaqButton(
                label: 'Confirm Changes',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _saving,
                onPressed: _saving
                    ? null
                    : () async {
                        final selected = _selected;
                        if (selected == null) return;
                        final newStart = DateTime(_dayOnly.year, _dayOnly.month, _dayOnly.day, selected.hour, selected.minute);
                        setState(() => _saving = true);
                        try {
                          await ref.read(bookingRepositoryProvider).rescheduleBooking(bookingId: widget.vm.booking.id, newStartAt: newStart);
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          if (!context.mounted) return;
                          final friendly = e is AppException ? e.message : 'Could not reschedule booking.';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

({String label, Color color}) _statusUi(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => (label: 'Pending', color: AppTheme.gold),
    BookingStatus.confirmed => (label: 'Confirmed', color: AppTheme.success),
    BookingStatus.inProgress => (label: 'In Progress', color: AppTheme.gold),
    BookingStatus.rescheduled => (label: 'Rescheduled', color: AppTheme.gold),
    BookingStatus.cancelled => (label: 'Cancelled', color: AppTheme.error),
    BookingStatus.noShow => (label: 'No Show', color: AppTheme.error),
    BookingStatus.completed => (label: 'Completed', color: AppTheme.success),
  };
}
