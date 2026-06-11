import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/geo/opening_status.dart';
import '../../../core/routing/routes.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/barber.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../shop/data/shop_repository.dart';
import '../data/shop_dashboard_repository.dart';
import '../../booking/presentation/widgets/booking_cancel_reason_sheet.dart';
import '../../../core/storage/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/service.dart';
import '../../services/data/services_management_repository.dart';
import '../../../core/models/product.dart';
import '../../products/data/products_repository.dart';
import '../../products/presentation/shop_product_editor_screen.dart';
import 'shop_customers_screen.dart';
import 'shop_manage_barber_availability_screen.dart';

final _shopBarbersManageProvider = FutureProvider<List<Barber>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Barber>[];
  return ref.watch(barberRepositoryProvider).listForShopManage(shop.id);
});

final _unassignedBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  return ref.watch(barberRepositoryProvider).listUnassignedManage();
});

final _shopServicesManageProvider = FutureProvider<List<Service>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Service>[];
  return ref.watch(servicesManagementRepositoryProvider).listForShopManage(shop.id);
});

final _serviceAssignedBarbersProvider = FutureProvider.family<Set<String>, String>((ref, serviceId) async {
  return ref.watch(servicesManagementRepositoryProvider).listAssignedBarbers(serviceId);
});

final _myShopIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).getMyShopId();
});

final _shopOrdersByStatusProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) async {
  return ref.watch(shopDashboardRepositoryProvider).listShopOrdersByStatus(status: status == 'all' ? null : status);
});

class ShopOwnerDashboardTab extends ConsumerWidget {
  const ShopOwnerDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(myShopProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final unreadCountValue = ref.watch(myUnreadNotificationsCountProvider).valueOrNull ?? 0;
    final overviewValue = ref.watch(shopDashboardTodayOverviewWithChangeProvider);
    final todayAppointmentsValue = ref.watch(shopDashboardTodayAppointmentsProvider);
    final activityValue = ref.watch(shopDashboardActivityProvider);
    final bottomPad = 122.0 + MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad),
      children: [
        AsyncValueWidget(
          value: shopValue,
          data: (shop) {
            if (shop == null) {
              return const HallaqCard(glass: true, child: Text('No shop assigned to this account.'));
            }
            final status = openingStatusFromHours(shop.openingHours, DateTime.now());

            Future<void> openWhatsApp() async {
              final raw = (shop.whatsapp ?? shop.phone ?? '').trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp number found for this shop.')));
                return;
              }
              final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
              final uri = Uri.parse(digits.isEmpty ? raw : 'https://wa.me/$digits');
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
              }
            }

            Future<void> openAllActionsSheet() async {
              await showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: HallaqCard(
                        glass: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.70),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('All Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _ActionChip(icon: Icons.person_add_alt_1_rounded, label: 'Add Barber', route: Routes.shopManageBarbers),
                                    _ActionChip(icon: Icons.add_circle_outline_rounded, label: 'Add Service', route: Routes.shopManageServices),
                                    _ActionChip(icon: Icons.video_call_rounded, label: 'Upload Reel', route: Routes.shopUploadReel),
                                    _ActionChip(icon: Icons.local_offer_rounded, label: 'Create Offer', route: Routes.shopManageOffers),
                                    _ActionChip(icon: Icons.qr_code_rounded, label: 'QR Center', route: Routes.shopQrCenter),
                                    _ActionChip(icon: Icons.settings_rounded, label: 'Shop Settings', route: Routes.shopManageSettings),
                                    _ActionChip(icon: Icons.shopping_bag_rounded, label: 'Add Product', route: Routes.shopManageProducts),
                                    _ActionChip(icon: Icons.access_time_rounded, label: 'Manage Hours', route: Routes.shopManageProfile),
                                    _ActionChip(icon: Icons.bar_chart_rounded, label: 'Reports', route: Routes.shopManageAnalytics),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: HallaqButton(
                                    label: 'Close',
                                    variant: HallaqButtonVariant.secondary,
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            final ownerName = (profile?.fullName ?? '').trim().isEmpty ? shop.name : profile!.fullName!.trim();
            final greeting = _greetingLabel(DateTime.now());

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    final brand = Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            children: [
                              TextSpan(text: 'HALLAQ', style: TextStyle(color: AppTheme.gold, letterSpacing: 0.8)),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: 'SHOP',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    final actions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconBadgeButton(
                          icon: Icons.notifications_none_rounded,
                          count: unreadCountValue,
                          onTap: () => context.push('/notifications'),
                        ),
                        const SizedBox(width: 8),
                        LuxuryIconButton(icon: Icons.chat_bubble_outline_rounded, onPressed: openWhatsApp),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.push('${Routes.shopProfile}/${shop.id}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: LuxuryNetworkImage(
                              imageUrl: shop.logoUrl,
                              fallbackUrl: HallaqImages.shopLogo(variant: '01'),
                              width: 36,
                              height: 36,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ],
                    );

                    if (!compact) {
                      return Row(
                        children: [
                          LuxuryIconButton(icon: Icons.menu_rounded, onPressed: openAllActionsSheet),
                          const SizedBox(width: 10),
                          Expanded(child: brand),
                          actions,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LuxuryIconButton(icon: Icons.menu_rounded, onPressed: openAllActionsSheet),
                            const SizedBox(width: 10),
                            Expanded(child: brand),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $ownerName!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Here’s what’s happening with your shop today.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ShopStatusPill(
                      isOpen: status.isOpen,
                      label: status.primaryLabel,
                      onTap: () => context.push(Routes.shopManageProfile),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ShopProfileCard(
                  shopName: shop.name,
                  logoUrl: shop.logoUrl,
                  area: shop.area,
                  rating: shop.ratingAvg,
                  ratingCount: shop.ratingCount,
                  verified: shop.badgeVerified,
                  onViewProfile: () => context.push('${Routes.shopProfile}/${shop.id}'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AsyncValueWidget(
          value: overviewValue,
          data: (o) {
            if (o == null) {
              return const HallaqCard(glass: true, child: Text('No shop assigned to this account.'));
            }
            return _KpiGrid(
              bookings: o.todayBookings,
              bookingsChangePct: o.todayBookingsChangePct,
              revenueBhd: o.revenueTodayBhd,
              revenueChangePct: o.revenueTodayChangePct,
              customers: o.newCustomers,
              customersChangePct: o.newCustomersChangePct,
              pending: o.pendingApprovals,
              pendingChangePct: o.pendingApprovalsChangePct,
              onTapBookings: () => context.go(Routes.shopDashboardBookings),
              onTapPending: () => context.go(Routes.shopDashboardBookings),
            );
          },
        ),
        const SizedBox(height: 14),
        AsyncValueWidget(
          value: shopValue,
          data: (shop) {
            if (shop == null) return const SizedBox.shrink();
            return AsyncValueWidget<List<Map<String, dynamic>>>(
              value: todayAppointmentsValue,
              data: (rows) => _TodayAppointmentsCard(
                shopOpeningHours: shop.openingHours,
                bookings: rows,
                onViewCalendar: () => context.go(Routes.shopDashboardBookings),
                onViewFullCalendar: () => context.push(Routes.shopManageBookings),
                onOpenBooking: (row) => _openBookingDetailsSheet(context: context, ref: ref, row: row),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;
            void retryActivity() => ref.invalidate(shopDashboardActivityProvider);
            final live = AsyncValueWidget<List<Map<String, dynamic>>>(
              value: activityValue,
              data: (rows) => _LiveActivityCard(
                rows: rows,
                onViewAll: () => context.push(Routes.shopActivity),
              ),
              error: (e, st) => _LiveActivityCard(
                rows: const [],
                onViewAll: () => context.push(Routes.shopActivity),
                onRetry: retryActivity,
              ),
            );
            final actions = _QuickActionsCard(
              onAddBarber: () => context.push(Routes.shopManageBarbers),
              onAddService: () => context.push(Routes.shopManageServices),
              onUploadReel: () => context.push(Routes.shopUploadReel),
              onCreateOffer: () => context.push(Routes.shopManageOffers),
              onOpenQr: () => context.push(Routes.shopQrCenter),
              onShopSettings: () => context.push(Routes.shopManageSettings),
              onAddProduct: () => context.push(Routes.shopManageProducts),
              onManageHours: () => context.push(Routes.shopManageProfile),
              onReports: () => context.push(Routes.shopManageAnalytics),
              onAllActions: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: HallaqCard(
                        glass: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.70),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('All Actions', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _ActionChip(icon: Icons.person_add_alt_1_rounded, label: 'Add Barber', route: Routes.shopManageBarbers),
                                    _ActionChip(icon: Icons.add_circle_outline_rounded, label: 'Add Service', route: Routes.shopManageServices),
                                    _ActionChip(icon: Icons.video_call_rounded, label: 'Upload Reel', route: Routes.shopUploadReel),
                                    _ActionChip(icon: Icons.local_offer_rounded, label: 'Create Offer', route: Routes.shopManageOffers),
                                    _ActionChip(icon: Icons.qr_code_rounded, label: 'QR Center', route: Routes.shopQrCenter),
                                    _ActionChip(icon: Icons.shopping_bag_rounded, label: 'Add Product', route: Routes.shopManageProducts),
                                    _ActionChip(icon: Icons.access_time_rounded, label: 'Manage Hours', route: Routes.shopManageProfile),
                                    _ActionChip(icon: Icons.bar_chart_rounded, label: 'Reports', route: Routes.shopManageAnalytics),
                                    _ActionChip(icon: Icons.settings_rounded, label: 'Shop Settings', route: Routes.shopManageSettings),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: HallaqButton(
                                    label: 'Close',
                                    variant: HallaqButtonVariant.secondary,
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
            if (!wide) return Column(children: [live, const SizedBox(height: 12), actions]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: live),
                const SizedBox(width: 12),
                Expanded(child: actions),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _greetingLabel(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class _IconBadgeButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _IconBadgeButton({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final show = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LuxuryIconButton(icon: icon, onPressed: onTap),
        if (show)
          Positioned(
            right: 3,
            top: -1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.0),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShopStatusPill extends StatelessWidget {
  final bool isOpen;
  final String label;
  final VoidCallback onTap;

  const _ShopStatusPill({required this.isOpen, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = isOpen ? AppTheme.success : AppTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.softShadow(opacity: 0.10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ShopProfileCard extends StatelessWidget {
  final String shopName;
  final String? logoUrl;
  final String? area;
  final double rating;
  final int ratingCount;
  final bool verified;
  final VoidCallback onViewProfile;

  const _ShopProfileCard({
    required this.shopName,
    required this.logoUrl,
    required this.area,
    required this.rating,
    required this.ratingCount,
    required this.verified,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: LuxuryNetworkImage(
              imageUrl: logoUrl,
              fallbackUrl: HallaqImages.shopLogo(variant: '01'),
              width: 56,
              height: 56,
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
                    Flexible(
                      child: Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: AppTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.goldDeep),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (area ?? '').trim().isEmpty ? '—' : area!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} ($ratingCount reviews)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _GoldOutlineButton(label: 'View Profile', onTap: onViewProfile),
        ],
      ),
    );
  }
}

class _GoldOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GoldOutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.gold)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.gold),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final int bookings;
  final double bookingsChangePct;
  final double revenueBhd;
  final double revenueChangePct;
  final int customers;
  final double customersChangePct;
  final int pending;
  final double pendingChangePct;
  final VoidCallback onTapBookings;
  final VoidCallback onTapPending;

  const _KpiGrid({
    required this.bookings,
    required this.bookingsChangePct,
    required this.revenueBhd,
    required this.revenueChangePct,
    required this.customers,
    required this.customersChangePct,
    required this.pending,
    required this.pendingChangePct,
    required this.onTapBookings,
    required this.onTapPending,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiCard(
              width: w,
              icon: Icons.event_available_rounded,
              title: 'Today’s Bookings',
              value: '$bookings',
              changePct: bookingsChangePct,
              onTap: onTapBookings,
            ),
            _KpiCard(
              width: w,
              icon: Icons.payments_rounded,
              title: 'Revenue Today',
              value: 'BHD ${revenueBhd.toStringAsFixed(0)}',
              changePct: revenueChangePct,
            ),
            _KpiCard(
              width: w,
              icon: Icons.people_alt_rounded,
              title: 'New Customers',
              value: '$customers',
              changePct: customersChangePct,
            ),
            _KpiCard(
              width: w,
              icon: Icons.timelapse_rounded,
              title: 'Pending Approvals',
              value: '$pending',
              changePct: pendingChangePct,
              trailing: 'View all',
              onTap: onTapPending,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final double changePct;
  final String? trailing;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.changePct,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final up = changePct >= 0;
    final pctLabel = '${changePct.abs().toStringAsFixed(0)}%';
    final arrow = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final arrowColor = up ? AppTheme.success : AppTheme.error;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: HallaqCard(
          glass: true,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(icon, color: AppTheme.gold, size: 20),
                  ),
                  const Spacer(),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(arrow, size: 16, color: arrowColor),
                  const SizedBox(width: 2),
                  Text(pctLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: arrowColor, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Text('vs yesterday', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({DateTime start, DateTime end})? _parseOpeningRange(Map<String, dynamic>? openingHours, DateTime day) {
  final hours = openingHours ?? const <String, dynamic>{};
  final key = switch (day.weekday) {
    DateTime.monday => 'mon',
    DateTime.tuesday => 'tue',
    DateTime.wednesday => 'wed',
    DateTime.thursday => 'thu',
    DateTime.friday => 'fri',
    DateTime.saturday => 'sat',
    _ => 'sun',
  };
  final raw = (hours[key] ?? '').toString().trim();
  if (raw.isEmpty) return null;
  final parts = raw.split('-').map((e) => e.trim()).toList();
  if (parts.length != 2) return null;
  DateTime? parseTime(String v) {
    final p = v.split(':').map((e) => e.trim()).toList();
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  final start = parseTime(parts[0]);
  final end = parseTime(parts[1]);
  if (start == null || end == null) return null;
  if (!end.isAfter(start)) return (start: start, end: end.add(const Duration(days: 1)));
  return (start: start, end: end);
}

DateTime _bookingEndLocal(Map<String, dynamic> row, DateTime startLocal) {
  final endRaw = row['end_at'] as String?;
  final parsed = endRaw == null ? null : DateTime.tryParse(endRaw)?.toLocal();
  if (parsed != null) return parsed;
  final services = row['services'] as Map?;
  final mins = ((services?['duration_minutes'] as num?)?.toInt() ?? 30).clamp(10, 360);
  return startLocal.add(Duration(minutes: mins));
}

class _TodayAppointmentsCard extends StatelessWidget {
  final Map<String, dynamic>? shopOpeningHours;
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onViewCalendar;
  final VoidCallback onViewFullCalendar;
  final ValueChanged<Map<String, dynamic>> onOpenBooking;

  const _TodayAppointmentsCard({
    required this.shopOpeningHours,
    required this.bookings,
    required this.onViewCalendar,
    required this.onViewFullCalendar,
    required this.onOpenBooking,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = _parseOpeningRange(shopOpeningHours, now);
    final entries = <Map<String, dynamic>>[];

    for (final b in bookings) {
      final startRaw = b['start_at'] as String?;
      final start = startRaw == null ? null : DateTime.tryParse(startRaw)?.toLocal();
      if (start == null) continue;
      entries.add({
        'type': 'booking',
        'start': start,
        'row': b,
      });
    }

    if (range != null) {
      final slotDuration = const Duration(hours: 1);
      var t = range.start;
      while (t.isBefore(range.end)) {
        final slotEnd = t.add(slotDuration);
        var overlaps = false;
        for (final b in bookings) {
          final startRaw = b['start_at'] as String?;
          final start = startRaw == null ? null : DateTime.tryParse(startRaw)?.toLocal();
          if (start == null) continue;
          final end = _bookingEndLocal(b, start);
          if (start.isBefore(slotEnd) && end.isAfter(t)) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) {
          entries.add({
            'type': 'slot',
            'start': t,
          });
        }
        t = t.add(slotDuration);
      }
    }

    entries.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

    final visible = entries.take(6).toList(growable: false);

    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Today’s Appointments', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
              InkWell(
                onTap: onViewCalendar,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.gold),
                      const SizedBox(width: 6),
                      Text('View Calendar', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_weekdayLabel(now.weekday)}, ${now.day.toString().padLeft(2, '0')} ${_monthLabel(now.month)} ${now.year}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: HallaqEmptyState(
                title: 'No appointments today',
                description: 'Your schedule is clear. Check your calendar or add bookings.',
                compact: true,
                actionLabel: 'View Calendar',
                onAction: onViewCalendar,
              ),
            )
          else
            Column(
              children: visible
                  .map((e) {
                    final type = e['type'] as String;
                    final start = e['start'] as DateTime;
                    if (type == 'slot') {
                      return _AppointmentRow.available(start: start, onTap: onViewCalendar);
                    }
                    return _AppointmentRow.booking(row: e['row'] as Map<String, dynamic>, onTap: () => onOpenBooking(e['row'] as Map<String, dynamic>));
                  })
                  .toList(growable: false),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewFullCalendar,
              icon: Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.gold),
              label: Text('View Full Calendar', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    _ => 'Sunday',
  };
}

String _monthLabel(int month) {
  return switch (month) {
    1 => 'January',
    2 => 'February',
    3 => 'March',
    4 => 'April',
    5 => 'May',
    6 => 'June',
    7 => 'July',
    8 => 'August',
    9 => 'September',
    10 => 'October',
    11 => 'November',
    _ => 'December',
  };
}

class _AppointmentRow extends StatelessWidget {
  final DateTime start;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final bool available;
  final VoidCallback? onTap;

  const _AppointmentRow._({
    required this.start,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.available,
    required this.onTap,
  });

  factory _AppointmentRow.available({required DateTime start, required VoidCallback onTap}) {
    return _AppointmentRow._(
      start: start,
      title: 'Available Slot',
      subtitle: '',
      statusLabel: 'Available',
      statusColor: AppTheme.textMuted,
      available: true,
      onTap: onTap,
    );
  }

  factory _AppointmentRow.booking({required Map<String, dynamic> row, required VoidCallback onTap}) {
    final startRaw = row['start_at'] as String?;
    final start = startRaw == null ? DateTime.now() : (DateTime.tryParse(startRaw)?.toLocal() ?? DateTime.now());
    final profiles = row['profiles'] as Map?;
    final customerName = (profiles?['full_name'] as String?) ?? 'Customer';
    final services = row['services'] as Map?;
    final serviceName = (services?['name_en'] as String?) ?? 'Service';
    final barber = row['barbers'] as Map?;
    final barberName = (barber?['display_name'] as String?) ?? '';

    final rawStatus = (row['status'] as String?) ?? 'pending';
    final now = DateTime.now();
    final end = _bookingEndLocal(row, start);
    var label = _statusLabel(rawStatus);
    var color = _statusColor(rawStatus);
    if (rawStatus == 'confirmed' && now.isAfter(start) && now.isBefore(end)) {
      label = 'In Progress';
      color = AppTheme.gold;
    }

    return _AppointmentRow._(
      start: start,
      title: customerName,
      subtitle: '$serviceName${barberName.isEmpty ? '' : ' • $barberName'}',
      statusLabel: label,
      statusColor: color,
      available: false,
      onTap: onTap,
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'confirmed' => 'Confirmed',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'pending' => 'Pending',
      _ => status,
    };
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'confirmed' => AppTheme.success,
      'completed' => AppTheme.textMuted,
      'cancelled' => AppTheme.error,
      'pending' => AppTheme.gold,
      _ => AppTheme.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(start);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (available)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(Icons.person_outline_rounded, color: AppTheme.textMuted, size: 18),
              )
            else
              const HallaqAvatar(imageUrl: null, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.30)),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: statusColor),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  var hour = time.hour;
  final minute = time.minute;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final mm = minute.toString().padLeft(2, '0');
  return '$hour:$mm $ampm';
}

Future<void> _openBookingDetailsSheet({required BuildContext context, required WidgetRef ref, required Map<String, dynamic> row}) async {
  final repo = ref.read(shopDashboardRepositoryProvider);
  final id = (row['id'] as String?) ?? '';
  if (id.trim().isEmpty) return;

  final profiles = row['profiles'] as Map?;
  final customerName = (profiles?['full_name'] as String?) ?? 'Customer';
  final phone = (profiles?['phone'] as String?) ?? '';
  final services = row['services'] as Map?;
  final serviceName = (services?['name_en'] as String?) ?? 'Service';
  final barber = row['barbers'] as Map?;
  final barberName = (barber?['display_name'] as String?) ?? '';

  final startRaw = row['start_at'] as String?;
  final start = startRaw == null ? null : DateTime.tryParse(startRaw)?.toLocal();
  final status = (row['status'] as String?) ?? 'pending';

  Future<void> call() async {
    final v = phone.trim();
    if (v.isEmpty) return;
    final uri = Uri.parse('tel:$v');
    await launchUrl(uri);
  }

  Future<void> whatsapp() async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication);
  }

  Future<void> reschedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      initialDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (time == null) return;
    final startAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await repo.rescheduleBooking(bookingId: id, newStartAt: startAt);
    ref.invalidate(shopDashboardTodayAppointmentsProvider);
    ref.invalidate(shopDashboardTodayOverviewWithChangeProvider);
    ref.invalidate(shopBookingsByStatusProvider);
  }

  Future<void> markCompleted() async {
    await repo.updateBookingStatus(bookingId: id, status: 'completed');
    ref.invalidate(shopDashboardTodayAppointmentsProvider);
    ref.invalidate(shopDashboardTodayOverviewWithChangeProvider);
    ref.invalidate(shopBookingsByStatusProvider);
  }

  Future<void> cancel() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BookingCancelReasonSheet(),
    );
    if (reason == null || !context.mounted) return;
    try {
      await repo.updateBookingStatus(bookingId: id, status: 'cancelled', cancelReason: reason);
      ref.invalidate(shopDashboardTodayAppointmentsProvider);
      ref.invalidate(shopDashboardTodayOverviewWithChangeProvider);
      ref.invalidate(shopBookingsByStatusProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: HallaqCard(
            glass: true,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    '$serviceName${barberName.isEmpty ? '' : ' • $barberName'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${start == null ? '—' : '${_weekdayLabel(start.weekday)} ${start.day}/${start.month} ${_formatTime(start)}'} • $status',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: phone.trim().isEmpty ? null : call, child: const Text('Call'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: phone.trim().isEmpty ? null : whatsapp, child: const Text('WhatsApp'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: reschedule, child: const Text('Reschedule'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: cancel, child: const Text('Cancel'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: HallaqButton(
                      label: 'Mark Completed',
                      icon: Icons.check_rounded,
                      variant: HallaqButtonVariant.primary,
                      onPressed: status == 'completed' ? null : markCompleted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _LiveActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final VoidCallback onViewAll;
  final VoidCallback? onRetry;

  const _LiveActivityCard({required this.rows, required this.onViewAll, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(4).toList(growable: false);
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Live Activity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Text('View all', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: HallaqEmptyState(
                title: 'No recent activity',
                description: 'Once customers book, review, or engage, you’ll see it here.',
                compact: true,
                actionLabel: onRetry == null ? null : 'Retry',
                onAction: onRetry,
              ),
            )
          else
            Column(children: visible.map((r) => _ActivityRow(row: r)).toList(growable: false)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ActivityRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] ?? row['type'] ?? row['event'] ?? '').toString();
    final title = (row['title'] ?? row['message'] ?? row['description'] ?? action).toString();
    final createdRaw = row['created_at']?.toString();
    final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
    final timeLabel = created == null ? '' : timeago.format(created);

    IconData icon = Icons.bolt_rounded;
    Color color = AppTheme.gold;
    final low = action.toLowerCase();
    if (low.contains('cancel')) {
      icon = Icons.close_rounded;
      color = AppTheme.error;
    } else if (low.contains('review') || low.contains('rating')) {
      icon = Icons.star_rounded;
      color = AppTheme.gold;
    } else if (low.contains('booking') || low.contains('appointment')) {
      icon = Icons.event_available_rounded;
      color = AppTheme.success;
    } else if (low.contains('reel') || low.contains('post')) {
      icon = Icons.movie_rounded;
      color = AppTheme.gold;
    } else if (low.contains('customer')) {
      icon = Icons.person_add_alt_1_rounded;
      color = AppTheme.gold;
    } else if (low.contains('offer')) {
      icon = Icons.local_offer_rounded;
      color = AppTheme.goldDeep;
    } else if (low.contains('order')) {
      icon = Icons.shopping_bag_rounded;
      color = AppTheme.gold;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(timeLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onAddBarber;
  final VoidCallback onAddService;
  final VoidCallback onUploadReel;
  final VoidCallback onCreateOffer;
  final VoidCallback onOpenQr;
  final VoidCallback onShopSettings;
  final VoidCallback onAddProduct;
  final VoidCallback onManageHours;
  final VoidCallback onReports;
  final VoidCallback onAllActions;

  const _QuickActionsCard({
    required this.onAddBarber,
    required this.onAddService,
    required this.onUploadReel,
    required this.onCreateOffer,
    required this.onOpenQr,
    required this.onShopSettings,
    required this.onAddProduct,
    required this.onManageHours,
    required this.onReports,
    required this.onAllActions,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile({required IconData icon, required String label, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: AppTheme.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      );
    }

    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 320 ? 2 : 1;
              final w = cols == 2 ? (c.maxWidth - 10) / 2 : c.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: w, child: tile(icon: Icons.person_add_alt_1_rounded, label: 'Add Barber', onTap: onAddBarber)),
                  SizedBox(width: w, child: tile(icon: Icons.add_circle_outline_rounded, label: 'Add Service', onTap: onAddService)),
                  SizedBox(width: w, child: tile(icon: Icons.video_call_rounded, label: 'Upload Reel', onTap: onUploadReel)),
                  SizedBox(width: w, child: tile(icon: Icons.local_offer_rounded, label: 'Create Offer', onTap: onCreateOffer)),
                  SizedBox(width: w, child: tile(icon: Icons.qr_code_rounded, label: 'Open QR', onTap: onOpenQr)),
                  SizedBox(width: w, child: tile(icon: Icons.settings_rounded, label: 'Shop Settings', onTap: onShopSettings)),
                  SizedBox(width: w, child: tile(icon: Icons.shopping_bag_rounded, label: 'Add Product', onTap: onAddProduct)),
                  SizedBox(width: w, child: tile(icon: Icons.access_time_rounded, label: 'Manage Hours', onTap: onManageHours)),
                  SizedBox(width: w, child: tile(icon: Icons.bar_chart_rounded, label: 'Reports', onTap: onReports)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: HallaqButton(
              label: 'All Actions',
              icon: Icons.apps_rounded,
              variant: HallaqButtonVariant.secondary,
              onPressed: onAllActions,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _ActionChip({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        Future<void>.microtask(() => router.push(route));
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.gold),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class ShopOwnerBarbersTab extends ConsumerWidget {
  const ShopOwnerBarbersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersValue = ref.watch(_shopBarbersManageProvider);
    final shopValue = ref.watch(myShopProvider);

    Future<void> openAdd() async {
      final shop = shopValue.valueOrNull;
      if (shop == null) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _AddBarberSheet(shopId: shop.id),
      );
      ref.invalidate(_shopBarbersManageProvider);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text('Barbers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              LuxuryIconButton(icon: Icons.add_rounded, onPressed: openAdd),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<Barber>>(
            value: barbersValue,
            onRetry: () => ref.invalidate(_shopBarbersManageProvider),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 110),
                  child: HallaqCard(glass: true, child: Text('No barbers in this shop yet.')),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                children: items.map((b) => _ShopBarberCard(barber: b)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShopBarberCard extends ConsumerWidget {
  final Barber barber;

  const _ShopBarberCard({required this.barber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = barber.isActive ? 'Active' : 'Inactive';
    final statusColor = barber.isActive ? AppTheme.success : AppTheme.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ShopBarberDetailsScreen(barberId: barber.id)));
          ref.invalidate(_shopBarbersManageProvider);
        },
        child: Row(
          children: [
            HallaqAvatar(imageUrl: barber.avatarUrl, size: 48, variant: '01'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(barber.displayName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HallaqRating(value: barber.ratingAvg, count: barber.reviewsCount, iconSize: 14),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                        ),
                        child: Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AddBarberSheet extends ConsumerStatefulWidget {
  final String shopId;

  const _AddBarberSheet({required this.shopId});

  @override
  ConsumerState<_AddBarberSheet> createState() => _AddBarberSheetState();
}

class _AddBarberSheetState extends ConsumerState<_AddBarberSheet> {
  final _uid = TextEditingController();
  Barber? _found;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(barberRepositoryProvider);

    Future<void> lookup() async {
      final input = _uid.text.trim();
      if (input.isEmpty) return;
      setState(() {
        _busy = true;
        _error = null;
        _found = null;
      });
      try {
        try {
          _found = await repo.getById(input);
        } catch (_) {
          _found = await repo.getByProfileId(input);
        }
        if (_found?.shopId != null) {
          _error = 'This barber is already assigned to a shop.';
          _found = null;
        }
      } catch (e) {
        _error = 'Barber not found.';
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    Future<void> add() async {
      if (_busy) return;
      if (_found == null) {
        await lookup();
        if (_found == null) return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await repo.assignToShop(barberId: _found!.id, shopId: widget.shopId);
        ref.invalidate(_unassignedBarbersProvider);
        ref.invalidate(_shopBarbersManageProvider);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        setState(() => _error = 'Failed to add barber. Please try again.');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add barber', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(
                  controller: _uid,
                  decoration: const InputDecoration(
                    labelText: 'Barber UID',
                    hintText: 'Paste barber UID',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => lookup(),
                        child: const Text('Find'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => add(),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _found == null
                ? const Center(child: Text('Enter a barber UID to add them to your shop.'))
                : HallaqCard(
                    glass: true,
                    child: Row(
                      children: [
                        HallaqAvatar(imageUrl: _found!.avatarUrl, size: 44, variant: '01'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _found!.displayName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

final _barberByIdProvider = FutureProvider.family<Barber?, String>((ref, id) async {
  try {
    return ref.watch(barberRepositoryProvider).getById(id);
  } catch (_) {
    return null;
  }
});

class _ShopBarberDetailsScreen extends ConsumerStatefulWidget {
  final String barberId;

  const _ShopBarberDetailsScreen({required this.barberId});

  @override
  ConsumerState<_ShopBarberDetailsScreen> createState() => _ShopBarberDetailsScreenState();
}

class _ShopBarberDetailsScreenState extends ConsumerState<_ShopBarberDetailsScreen> {
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _bio = TextEditingController();
  final _waitingTimeMin = TextEditingController();
  final _queueLength = TextEditingController();
  var _isActive = true;
  var _availableNow = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _bio.dispose();
    _waitingTimeMin.dispose();
    _queueLength.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barberValue = ref.watch(_barberByIdProvider(widget.barberId));
    final storage = ref.watch(storageServiceProvider);
    final media = ref.watch(mediaServiceProvider);
    final repo = ref.watch(barberRepositoryProvider);

    Future<void> pickAndUpload({required bool cover, required Barber barber}) async {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: cover ? 1800 : 900);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final previousPath = (cover ? barber.coverPath : barber.avatarPath) ?? '';
      if (previousPath.trim().isNotEmpty && !previousPath.startsWith('http')) {
        try {
          await storage.removeObject(bucket: 'barber-images', path: previousPath);
        } catch (_) {}
      }
      final stored = await media.uploadImage(
        bucket: 'barber-images',
        pathPrefix: 'barbers/${barber.id}',
        bytes: bytes,
        options: cover
            ? const MediaImageProcessOptions(cropAspectRatio: 16 / 9, maxWidth: 1280, maxHeight: 720)
            : const MediaImageProcessOptions(cropAspectRatio: 1, maxWidth: 512, maxHeight: 512),
        uploadThumbnail: false,
      );
      await repo.updateBarber(barberId: barber.id, avatarPath: cover ? null : stored.path, coverPath: cover ? stored.path : null);
      ref.invalidate(_barberByIdProvider(widget.barberId));
    }

    Future<void> save(Barber barber) async {
      setState(() => _busy = true);
      try {
        final waiting = int.tryParse(_waitingTimeMin.text.trim());
        final queue = int.tryParse(_queueLength.text.trim());
        await repo.updateBarber(
          barberId: barber.id,
          displayName: _name.text,
          specialty: _specialty.text,
          bio: _bio.text,
          isActive: _isActive,
          availableNow: _availableNow,
          waitingTimeMin: waiting,
          queueLength: queue,
        );
        ref.invalidate(_barberByIdProvider(widget.barberId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    Future<void> removeFromShop(Barber barber) async {
      final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove barber'),
              content: const Text('This will remove the barber from your shop.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      await repo.removeFromShop(barberId: barber.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Barber'),
        actions: [
          IconButton(
            onPressed: barberValue.valueOrNull == null ? null : () => removeFromShop(barberValue.valueOrNull!),
            icon: const Icon(Icons.person_remove_alt_1_rounded),
          ),
        ],
      ),
      body: AsyncValueWidget<Barber?>(
        value: barberValue,
        onRetry: () => ref.invalidate(_barberByIdProvider(widget.barberId)),
        data: (barber) {
          if (barber == null) return const Center(child: Text('Barber not found.'));
          if (_name.text.isEmpty) {
            _name.text = barber.displayName;
            _specialty.text = barber.specialty ?? '';
            _bio.text = barber.bio ?? '';
            _isActive = barber.isActive;
            _availableNow = barber.availableNow;
            _waitingTimeMin.text = (barber.waitingTimeMin ?? 0).toString();
            _queueLength.text = (barber.queueLength ?? 0).toString();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              HallaqCard(
                glass: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Photos', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                        Text('${barber.ratingAvg.toStringAsFixed(1)} ★', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy ? null : () => pickAndUpload(cover: true, barber: barber),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: LuxuryNetworkImage(
                          imageUrl: barber.coverUrl,
                          fallbackUrl: HallaqImages.professionalBarberPortrait(variant: '01'),
                          height: 160,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _busy ? null : () => pickAndUpload(cover: false, barber: barber),
                          child: HallaqAvatar(imageUrl: barber.avatarUrl, size: 62, variant: '01'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Active')),
                                  Switch(value: _isActive, onChanged: _busy ? null : (v) => setState(() => _isActive = v)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Expanded(child: Text('Available now')),
                                  Switch(value: _availableNow, onChanged: _busy ? null : (v) => setState(() => _availableNow = v)),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _waitingTimeMin,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Waiting (min)'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _queueLength,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Queue'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: true,
                child: Column(
                  children: [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 10),
                    TextField(controller: _specialty, decoration: const InputDecoration(labelText: 'Specialty')),
                    const SizedBox(height: 10),
                    TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HallaqButton(
                label: 'Manage availability',
                icon: Icons.calendar_month_rounded,
                variant: HallaqButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShopManageBarberAvailabilityScreen(barberId: barber.id, title: barber.displayName),
                          ),
                        ),
              ),
              const SizedBox(height: 12),
              HallaqButton(
                label: 'Save',
                icon: Icons.check_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : () => save(barber),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ShopOwnerBookingsTab extends StatelessWidget {
  const ShopOwnerBookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ShopOwnerBookingsTabBody();
  }
}

class ShopOwnerCustomersTab extends StatelessWidget {
  const ShopOwnerCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopCustomersScreen(showAppBar: false);
  }
}

class _ShopOwnerBookingsTabBody extends ConsumerWidget {
  const _ShopOwnerBookingsTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shopDashboardRepositoryProvider);

    Future<void> setStatus(String bookingId, String status) async {
      if (status == 'cancelled') {
        final reason = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const BookingCancelReasonSheet(),
        );
        if (reason == null || !context.mounted) return;
        await repo.updateBookingStatus(bookingId: bookingId, status: status, cancelReason: reason);
      } else {
        await repo.updateBookingStatus(bookingId: bookingId, status: status);
      }
      ref.invalidate(shopBookingsByStatusProvider);
      ref.invalidate(shopDashboardUpcomingAppointmentsProvider);
      ref.invalidate(shopDashboardTodayOverviewProvider);
    }

    Future<void> reschedule(String bookingId) async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 1),
        initialDate: now,
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
      if (time == null) return;
      final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      await repo.rescheduleBooking(bookingId: bookingId, newStartAt: start);
      ref.invalidate(shopBookingsByStatusProvider);
      ref.invalidate(shopDashboardUpcomingAppointmentsProvider);
      ref.invalidate(shopDashboardTodayOverviewProvider);
    }

    const tabs = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('confirmed', 'Confirmed'),
      ('completed', 'Completed'),
      ('cancelled', 'Cancelled'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text('Bookings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                LuxuryIconButton(icon: Icons.refresh_rounded, onPressed: () => ref.invalidate(shopBookingsByStatusProvider)),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Confirmed'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: tabs.map((t) {
                final value = ref.watch(shopBookingsByStatusProvider(t.$1));
                return AsyncValueWidget<List<Map<String, dynamic>>>(
                  value: value,
                  onRetry: () => ref.invalidate(shopBookingsByStatusProvider(t.$1)),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 110),
                        child: HallaqCard(glass: true, child: Text('No bookings.')),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                      children: rows
                          .map(
                            (r) => _BookingCard(
                              row: r,
                              onAccept: () => setStatus(r['id'] as String, 'confirmed'),
                              onReject: () => setStatus(r['id'] as String, 'cancelled'),
                              onComplete: () => setStatus(r['id'] as String, 'completed'),
                              onReschedule: () => reschedule(r['id'] as String),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onReschedule;
  final VoidCallback onComplete;

  const _BookingCard({
    required this.row,
    required this.onAccept,
    required this.onReject,
    required this.onReschedule,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final startRaw = row['start_at'] as String?;
    final start = startRaw == null ? null : DateTime.tryParse(startRaw)?.toLocal();
    final status = (row['status'] as String?) ?? 'pending';

    final profiles = row['profiles'] as Map?;
    final customerName = (profiles?['full_name'] as String?) ?? 'Customer';

    final services = row['services'] as Map?;
    final serviceName = (services?['name_en'] as String?) ?? 'Service';
    final servicePrice = (services?['price_bhd'] as num?)?.toDouble();

    final barber = row['barbers'] as Map?;
    final barberName = (barber?['display_name'] as String?) ?? '';

    final price = (row['price_bhd'] as num?)?.toDouble() ?? servicePrice ?? 0;

    final timeLabel = start == null
        ? '—'
        : '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(timeLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const HallaqAvatar(imageUrl: null, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        '$serviceName${barberName.isEmpty ? '' : ' • $barberName'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${price.toStringAsFixed(3)} BHD',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: status == 'pending' ? onAccept : null, child: const Text('Accept'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: status == 'pending' ? onReject : null, child: const Text('Reject'))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: (status == 'pending' || status == 'confirmed') ? onReschedule : null, child: const Text('Reschedule'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: status == 'confirmed' ? onComplete : null, child: const Text('Mark Completed'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShopOwnerServicesTab extends StatelessWidget {
  const ShopOwnerServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ShopOwnerServicesTabBody();
  }
}

class _ShopOwnerServicesTabBody extends ConsumerWidget {
  const _ShopOwnerServicesTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesValue = ref.watch(_shopServicesManageProvider);
    final shopValue = ref.watch(myShopProvider);

    Future<void> openEditor({Service? service}) async {
      final shop = shopValue.valueOrNull;
      if (shop == null) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ServiceEditorScreen(shopId: shop.id, service: service)));
      ref.invalidate(_shopServicesManageProvider);
    }

    Future<void> addDefaults() async {
      final shop = shopValue.valueOrNull;
      if (shop == null) return;
      final repo = ref.read(servicesManagementRepositoryProvider);
      final defaults = const [
        ('Haircut', 'حلاقة شعر', 3.500, 30),
        ('Skin Fade', 'تدريج سكن فيد', 4.000, 35),
        ('Beard Trim', 'تهذيب اللحية', 2.500, 20),
        ('Hair + Beard Package', 'باكج شعر + لحية', 5.500, 50),
        ('Hot Towel Shave', 'حلاقة منشفة ساخنة', 3.000, 25),
        ('Kids Haircut', 'حلاقة أطفال', 2.000, 25),
      ];
      for (final d in defaults) {
        await repo.upsert(
          payload: {
            'shop_id': shop.id,
            'barber_id': null,
            'name_en': d.$1,
            'name_ar': d.$2,
            'description_en': '',
            'description_ar': '',
            'price_bhd': d.$3,
            'duration_minutes': d.$4,
            'category': 'General',
            'is_active': true,
            'is_popular': false,
            'deleted_at': null,
          },
        );
      }
      ref.invalidate(_shopServicesManageProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default services added')));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text('Services', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              LuxuryIconButton(icon: Icons.add_rounded, onPressed: () => openEditor()),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<Service>>(
            value: servicesValue,
            onRetry: () => ref.invalidate(_shopServicesManageProvider),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  child: Column(
                    children: [
                      const HallaqCard(glass: true, child: Text('No services yet.')),
                      const SizedBox(height: 12),
                      HallaqButton(label: 'Add default services', onPressed: addDefaults, icon: Icons.auto_awesome_rounded),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                children: items.map((s) => _ServiceManageCard(service: s, onEdit: () => openEditor(service: s))).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceManageCard extends ConsumerWidget {
  final Service service;
  final VoidCallback onEdit;

  const _ServiceManageCard({required this.service, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(servicesManagementRepositoryProvider);

    Future<void> toggle() async {
      await repo.upsert(
        payload: {
          'id': service.id,
          'shop_id': service.shopId,
          'barber_id': null,
          'is_active': !service.isActive,
        },
      );
      ref.invalidate(_shopServicesManageProvider);
    }

    Future<void> remove() async {
      final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete service'),
              content: const Text('This will remove the service.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      await repo.delete(service.id);
      ref.invalidate(_shopServicesManageProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        onTap: onEdit,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 66,
                height: 66,
                child: LuxuryNetworkImage(imageUrl: service.imageUrl, fallbackUrl: '', bucket: 'service-images', borderRadius: BorderRadius.zero),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.nameEn, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '${service.priceBhd.toStringAsFixed(3)} BHD • ${service.durationMinutes} min${(service.category ?? '').isEmpty ? '' : ' • ${service.category}'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: toggle, child: Text(service.isActive ? 'Disable' : 'Enable'))),
                      const SizedBox(width: 10),
                      IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceEditorScreen extends ConsumerStatefulWidget {
  final String shopId;
  final Service? service;

  const _ServiceEditorScreen({required this.shopId, this.service});

  @override
  ConsumerState<_ServiceEditorScreen> createState() => _ServiceEditorScreenState();
}

class _ServiceEditorScreenState extends ConsumerState<_ServiceEditorScreen> {
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _descEn = TextEditingController();
  final _descAr = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();
  final _category = TextEditingController();

  var _active = true;
  var _popular = false;
  var _busy = false;
  Uint8List? _pickedImageBytes;
  Set<String> _selectedBarbers = {};

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _descEn.dispose();
    _descAr.dispose();
    _price.dispose();
    _duration.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.service;
    final repo = ref.watch(servicesManagementRepositoryProvider);
    final storage = ref.watch(storageServiceProvider);
    final media = ref.watch(mediaServiceProvider);
    final barbersValue = ref.watch(_shopBarbersManageProvider);
    final assignedValue = existing == null ? const AsyncValue<Set<String>>.data({}) : ref.watch(_serviceAssignedBarbersProvider(existing.id));

    if (existing != null && _nameEn.text.isEmpty) {
      _nameEn.text = existing.nameEn;
      _nameAr.text = existing.nameAr;
      _descEn.text = existing.descriptionEn;
      _descAr.text = existing.descriptionAr;
      _price.text = existing.priceBhd.toStringAsFixed(3);
      _duration.text = existing.durationMinutes.toString();
      _category.text = existing.category ?? '';
      _active = existing.isActive;
      _popular = existing.isPopular;
    }

    if (existing != null) {
      ref.listen(_serviceAssignedBarbersProvider(existing.id), (_, next) {
        final set = next.valueOrNull;
        if (set != null && _selectedBarbers.isEmpty) {
          setState(() => _selectedBarbers = set);
        }
      });
    }

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1400);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
      });
    }

    Future<void> save() async {
      setState(() => _busy = true);
      try {
        final payload = <String, dynamic>{
          if (existing != null) 'id': existing.id,
          'shop_id': widget.shopId,
          'barber_id': null,
          'name_en': _nameEn.text.trim(),
          'name_ar': _nameAr.text.trim(),
          'description_en': _descEn.text.trim(),
          'description_ar': _descAr.text.trim(),
          'price_bhd': double.tryParse(_price.text.trim()) ?? 0,
          'duration_minutes': int.tryParse(_duration.text.trim()) ?? 30,
          'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
          'status': 'approved',
          'is_active': _active,
          'is_popular': _popular,
          'deleted_at': null,
        };

        var saved = await repo.upsert(payload: payload);

        if (_pickedImageBytes != null) {
          final previousRef = (existing?.imageUrl ?? '').trim();
          final stored = await media.uploadImage(
            bucket: 'service-images',
            pathPrefix: 'shops/${widget.shopId}/services',
            bytes: _pickedImageBytes!,
            uploadThumbnail: false,
          );
          final publicUrl = media.publicUrlFor(bucket: 'service-images', path: stored.path);
          saved = await repo.upsert(payload: {'id': saved.id, 'image_url': publicUrl});
          if (previousRef.isNotEmpty && previousRef != stored.path && previousRef != publicUrl) {
            try {
              final parsed = parseSupabasePublicStorageUrl(previousRef);
              final p = parsed?.bucket == 'service-images' ? parsed!.path : (previousRef.startsWith('http') ? '' : previousRef);
              if (p.trim().isNotEmpty) await storage.removeObject(bucket: 'service-images', path: p.trim());
            } catch (_) {}
          }
        }

        await repo.setAssignedBarbers(serviceId: saved.id, barberIds: _selectedBarbers);

        ref.invalidate(_shopServicesManageProvider);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(existing == null ? 'New service' : 'Edit service')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HallaqCard(
            glass: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: _pickedImageBytes != null
                        ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                        : LuxuryNetworkImage(imageUrl: existing?.imageUrl, fallbackUrl: '', bucket: 'service-images', borderRadius: BorderRadius.zero),
                  ),
                ),
                const SizedBox(height: 10),
                HallaqButton(
                  label: 'Upload image',
                  icon: Icons.photo_library_rounded,
                  variant: HallaqButtonVariant.secondary,
                  onPressed: _busy ? null : pickImage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _nameEn, decoration: const InputDecoration(labelText: 'Name English')),
                const SizedBox(height: 10),
                TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'Name Arabic')),
                const SizedBox(height: 10),
                TextField(controller: _descEn, decoration: const InputDecoration(labelText: 'Description English')),
                const SizedBox(height: 10),
                TextField(controller: _descAr, decoration: const InputDecoration(labelText: 'Description Arabic')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        decoration: const InputDecoration(labelText: 'Price (BHD)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _duration,
                        decoration: const InputDecoration(labelText: 'Duration (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
                SwitchListTile.adaptive(
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v),
                  title: const Text('Active'),
                ),
                SwitchListTile.adaptive(
                  value: _popular,
                  onChanged: _busy ? null : (v) => setState(() => _popular = v),
                  title: const Text('Popular'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Assign Barbers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AsyncValueWidget<List<Barber>>(
            value: barbersValue,
            data: (barbers) {
              if (barbers.isEmpty) return const HallaqCard(glass: true, child: Text('No barbers in this shop yet.'));
              return HallaqCard(
                glass: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: barbers.map((b) {
                    final checked = _selectedBarbers.contains(b.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _selectedBarbers.add(b.id);
                                } else {
                                  _selectedBarbers.remove(b.id);
                                }
                              }),
                      title: Text(b.displayName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      subtitle: Text(b.status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AsyncValueWidget<Set<String>>(
            value: assignedValue,
            data: (_) => const SizedBox.shrink(),
          ),
          HallaqButton(label: 'Save', icon: Icons.check_rounded, isLoading: _busy, onPressed: _busy ? null : save),
        ],
      ),
    );
  }
}

class ShopOwnerProductsTab extends StatelessWidget {
  const ShopOwnerProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ShopOwnerProductsTabBody();
  }
}

class _ShopOwnerProductsTabBody extends ConsumerWidget {
  const _ShopOwnerProductsTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopIdValue = ref.watch(_myShopIdProvider);

    return AsyncValueWidget<String?>(
      value: shopIdValue,
      onRetry: () => ref.invalidate(_myShopIdProvider),
      data: (shopId) {
        if (shopId == null) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: HallaqCard(glass: true, child: Text('No shop assigned to this account.')),
          );
        }

        Future<void> openNewProduct() async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopProductEditorScreen()));
          ref.invalidate(shopProductsManagementProvider(shopId));
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    LuxuryIconButton(icon: Icons.add_rounded, onPressed: openNewProduct),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Products'),
                  Tab(text: 'Orders'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ProductsList(shopId: shopId),
                    _OrdersList(shopId: shopId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductsList extends ConsumerWidget {
  final String shopId;

  const _ProductsList({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsValue = ref.watch(shopProductsManagementProvider(shopId));
    final repo = ref.watch(productsRepositoryProvider);

    return AsyncValueWidget<List<Product>>(
      value: productsValue,
      onRetry: () => ref.invalidate(shopProductsManagementProvider(shopId)),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: HallaqCard(glass: true, child: Text('No products yet.')),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: items.map((p) => _ProductManageCard(shopId: shopId, product: p, repo: repo)).toList(),
        );
      },
    );
  }
}

class _ProductManageCard extends StatelessWidget {
  final String shopId;
  final Product product;
  final ProductsRepository repo;

  const _ProductManageCard({required this.shopId, required this.product, required this.repo});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl ?? (product.images.isEmpty ? null : product.images.first);

    Future<void> toggleActive(WidgetRef ref) async {
      await repo.update(id: product.id, active: !product.active);
      ref.invalidate(shopProductsManagementProvider(shopId));
    }

    Future<void> delete(WidgetRef ref) async {
      final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete product'),
              content: const Text('This will remove the product.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      await repo.delete(id: product.id);
      ref.invalidate(shopProductsManagementProvider(shopId));
    }

    return Consumer(
      builder: (context, ref, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HallaqCard(
            glass: true,
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopProductEditorScreen(productId: product.id))),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: LuxuryNetworkImage(imageUrl: imageUrl, fallbackUrl: '', borderRadius: BorderRadius.zero),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        '${product.price.toStringAsFixed(3)} ${product.currency} • Stock ${product.stock}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => toggleActive(ref), child: Text(product.active ? 'Disable' : 'Enable'))),
                          const SizedBox(width: 10),
                          IconButton(onPressed: () => delete(ref), icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrdersList extends ConsumerWidget {
  final String shopId;

  const _OrdersList({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = [
      ('pending', 'Pending'),
      ('accepted', 'Accepted'),
      ('delivered', 'Completed'),
      ('cancelled', 'Cancelled'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          const TabBar(isScrollable: true, tabs: [Tab(text: 'Pending'), Tab(text: 'Accepted'), Tab(text: 'Completed'), Tab(text: 'Cancelled')]),
          Expanded(
            child: TabBarView(
              children: tabs.map((t) {
                final value = ref.watch(_shopOrdersByStatusProvider(t.$1));
                return AsyncValueWidget<List<Map<String, dynamic>>>(
                  value: value,
                  onRetry: () => ref.invalidate(_shopOrdersByStatusProvider(t.$1)),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 110),
                        child: HallaqCard(glass: true, child: Text('No orders.')),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                      children: rows.map((r) => _OrderManageCard(row: r)).toList(),
                    );
                  },
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderManageCard extends ConsumerWidget {
  final Map<String, dynamic> row;

  const _OrderManageCard({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shopDashboardRepositoryProvider);
    final status = (row['status'] as String?) ?? 'pending';
    final profiles = row['profiles'] as Map?;
    final name = (profiles?['full_name'] as String?) ?? 'Customer';
    final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
    final currency = (row['currency'] as String?) ?? 'BHD';

    Future<void> set(String s) async {
      await repo.updateOrderStatus(orderId: row['id'] as String, status: s);
      ref.invalidate(_shopOrdersByStatusProvider);
      ref.invalidate(shopDashboardOrdersProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('${Routes.shopOrderDetails}/${row['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${total.toStringAsFixed(3)} $currency',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: status == 'accepted' ? null : () => set('accepted'), child: const Text('Accept'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: status == 'rejected' ? null : () => set('rejected'), child: const Text('Reject'))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: status == 'shipped' ? null : () => set('shipped'), child: const Text('Shipped'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: status == 'delivered' ? null : () => set('delivered'), child: const Text('Delivered'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShopOwnerMoreTab extends ConsumerWidget {
  const ShopOwnerMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider).valueOrNull;
    final shopId = shop?.id;
    final bottomPad = 122.0 + MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad),
      children: [
        Text('More', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        HallaqCard(
          glass: true,
          child: Column(
            children: [
              _MoreRow(label: 'Shop Profile', icon: Icons.storefront_rounded, onTap: () => context.push(Routes.shopManageProfile)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Services', icon: Icons.design_services_rounded, onTap: () => context.push(Routes.shopManageServices)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Products', icon: Icons.shopping_bag_rounded, onTap: () => context.push(Routes.shopManageProducts)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Gallery', icon: Icons.photo_library_rounded, onTap: () => context.push(Routes.shopManageGallery)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Customers', icon: Icons.people_alt_rounded, onTap: () => context.go(Routes.shopDashboardCustomers)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Reels Center', icon: Icons.movie_rounded, onTap: () => context.push(Routes.shopManageReels)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Upload Reel', icon: Icons.video_call_rounded, onTap: () => context.push(Routes.shopUploadReel)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Offers', icon: Icons.local_offer_rounded, onTap: () => context.push(Routes.shopManageOffers)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Reviews', icon: Icons.star_rounded, onTap: shopId == null ? null : () => context.push('/reviews?targetType=shop&targetId=$shopId')),
              const SizedBox(height: 10),
              _MoreRow(label: 'Inventory', icon: Icons.inventory_2_rounded, onTap: () => context.push(Routes.shopManageProducts)),
              const SizedBox(height: 10),
              _MoreRow(label: 'QR Center', icon: Icons.qr_code_rounded, onTap: () => context.push(Routes.shopQrCenter)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Revenue Reports', icon: Icons.bar_chart_rounded, onTap: () => context.push(Routes.shopManageAnalytics)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Notifications', icon: Icons.notifications_none_rounded, onTap: () => context.push('/notifications')),
              const SizedBox(height: 10),
              _MoreRow(label: 'Staff Settings', icon: Icons.manage_accounts_rounded, onTap: () => context.push(Routes.shopManageBarbers)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Working Hours', icon: Icons.access_time_rounded, onTap: () => context.push(Routes.shopManageProfile)),
              const SizedBox(height: 10),
              _MoreRow(label: 'Subscription', icon: Icons.workspace_premium_rounded, onTap: () => context.push('/membership')),
              const SizedBox(height: 10),
              _MoreRow(label: 'Help & Support', icon: Icons.support_agent_rounded, onTap: () => context.push('/support')),
              const SizedBox(height: 10),
              _MoreRow(label: 'Settings', icon: Icons.settings_rounded, onTap: () => context.push(Routes.shopManageSettings)),
              const SizedBox(height: 10),
              _MoreRow(
                label: 'Logout',
                icon: Icons.logout_rounded,
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(Routes.signIn);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _MoreRow({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: onTap == null ? AppTheme.textMuted : AppTheme.goldDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: onTap == null ? AppTheme.textMuted : null),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
