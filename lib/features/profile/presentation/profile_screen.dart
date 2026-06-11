import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/errors/user_facing_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/gold_shimmer.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../bookings/models/my_booking_card.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_membership_repository.dart';
import '../data/profile_repository.dart';
import '../data/profile_stats_repository.dart';
import '../data/recent_bookings_provider.dart';
import 'profile_media_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uri = GoRouterState.of(context).uri;
    final isPreview = uri.queryParameters['preview'] == '1';
    final profile = ref.watch(myProfileProvider);
    final stats = ref.watch(myProfileStatsProvider);
    final membership = ref.watch(myCustomerMembershipProvider);
    final unread = ref.watch(myUnreadNotificationsCountProvider);
    final media = ref.watch(profileMediaControllerProvider);
    final recentBookings = ref.watch(myRecentBookingsProvider);

    ref.listen(profileMediaControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
    });

    Future<bool> confirmUpload(Uint8List bytes, {required bool cover}) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: cover ? (16 / 9) : 1,
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Upload')),
            ],
          );
        },
      );
      return confirmed ?? false;
    }

    Future<void> pickAndUpload({required bool cover}) async {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: cover ? 1800 : 900,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ok = await confirmUpload(bytes, cover: cover);
      if (!ok) return;
      if (cover) {
        await ref.read(profileMediaControllerProvider.notifier).updateCover(bytes: bytes);
      } else {
        await ref.read(profileMediaControllerProvider.notifier).updateAvatar(bytes: bytes);
      }
    }

    Future<void> showPhotoActions({required bool cover}) async {
      final action = await showModalBottomSheet<_PhotoAction>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _PremiumCard(
                radius: 24,
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cover ? l10n.changeCover : l10n.changePhoto,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ActionRow(
                      icon: Icons.photo_library_outlined,
                      label: l10n.gallery,
                      onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.removePhoto,
                      danger: true,
                      onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (action == null) return;
      switch (action) {
        case _PhotoAction.gallery:
          await pickAndUpload(cover: cover);
          break;
        case _PhotoAction.remove:
          if (cover) {
            await ref.read(profileMediaControllerProvider.notifier).clearCover();
          } else {
            await ref.read(profileMediaControllerProvider.notifier).clearAvatar();
          }
          break;
      }
    }

    return ColoredBox(
      color: AppTheme.onyx,
      child: AsyncValueWidget<UserProfile?>(
        value: profile,
        onRetry: isPreview
            ? null
            : () {
                ref.invalidate(myProfileProvider);
                ref.invalidate(myProfileStatsProvider);
                ref.invalidate(myCustomerMembershipProvider);
                ref.invalidate(myUnreadNotificationsCountProvider);
                ref.invalidate(myRecentBookingsProvider);
              },
        loading: const _ProfileSkeleton(),
        data: (p) {
          if (p == null) {
            return ResponsiveCenter(
              maxWidth: 390,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).padding.bottom + 120),
                children: [
                  _PremiumCard(
                    radius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.guestBrowsingTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(l10n.guestBrowsingSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () => context.go('/auth'),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                              child: Text(l10n.signIn, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final name = (p.fullName ?? '').trim().isEmpty ? l10n.member : p.fullName!.trim();
          final tier = (membership.valueOrNull?.tier ?? p.membershipTier ?? 'Silver').trim();
          final locationText = ((p.location ?? '').trim().isNotEmpty ? (p.location ?? '') : (p.area ?? '')).trim();
          final verified = p.verified;

          String fmtInt(int? v) => v == null ? '—' : NumberFormat.decimalPattern().format(v);
          String fmtRating(double? v) => v == null ? '—' : v == 0 ? '—' : v.toStringAsFixed(1);

          final statsValue = stats.valueOrNull;
          final unreadCount = unread.valueOrNull ?? 0;
          final isUploading = media.isLoading;
          final statsLoading = stats.isLoading;
          final membershipLoading = membership.isLoading;

          return ResponsiveCenter(
            maxWidth: 390,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RefreshIndicator(
              color: AppTheme.gold,
              onRefresh: () async {
                if (isPreview) return;
                ref.invalidate(myProfileProvider);
                ref.invalidate(myProfileStatsProvider);
                ref.invalidate(myCustomerMembershipProvider);
                ref.invalidate(myUnreadNotificationsCountProvider);
                ref.invalidate(myRecentBookingsProvider);
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 10, 0, MediaQuery.of(context).padding.bottom + 120),
                children: [
                  _HeaderCard(
                    profile: p,
                    name: name,
                    tier: tier,
                    locationText: locationText,
                    verified: verified,
                    unreadCount: unreadCount,
                    uploading: isUploading,
                    onTapCover: () => isPreview ? showSuccessSnackBar(context, 'Preview mode') : showPhotoActions(cover: true),
                    onTapAvatar: () => isPreview ? showSuccessSnackBar(context, 'Preview mode') : showPhotoActions(cover: false),
                    onTapNotifications: () => context.go('/notifications'),
                    onTapSettings: () => context.push('/settings'),
                  ),
                  const SizedBox(height: 14),
                  statsLoading
                      ? const _StatsCardSkeleton()
                      : _StatsCard(
                          totalBookings: fmtInt(statsValue?.totalBookings),
                          avgRating: fmtRating(statsValue?.averageRating),
                          favoriteBarbers: fmtInt(statsValue?.favoriteBarbers),
                          loyaltyPoints: fmtInt(statsValue?.loyaltyPoints),
                        ),
                  const SizedBox(height: 14),
                  membershipLoading
                      ? const _MembershipCardSkeleton()
                      : _MembershipCard(
                          tier: tier,
                          points: statsValue?.loyaltyPoints ?? membership.valueOrNull?.points ?? 0,
                          onViewBenefits: () => context.push('/membership'),
                        ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My Shortcuts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/edit-profile'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            'Edit',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ShortcutsRow(
                    onBookings: () => context.go(isPreview ? '/bookings?preview=1' : '/bookings'),
                    onMembership: () => context.push(isPreview ? '/membership?preview=1' : '/membership'),
                    onReviews: () => context.push(isPreview ? '/my-reviews?preview=1' : '/my-reviews'),
                    onSaved: () => context.push(isPreview ? '/saved?preview=1' : '/saved'),
                    onAddresses: () => context.push(isPreview ? '/addresses?preview=1' : '/addresses'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Bookings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.go(isPreview ? '/bookings?preview=1' : '/bookings'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            l10n.viewAll,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  recentBookings.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return _EmptyStateCard(
                          title: 'No bookings yet',
                          subtitle: 'Explore top barbers and book your next visit.',
                          actionLabel: l10n.explore,
                          onAction: () => context.go(isPreview ? '/discover?preview=1' : '/discover'),
                        );
                      }
                      return _RecentBookingCard(item: items.first);
                    },
                    loading: () => const _RecentBookingCardSkeleton(),
                    error: (_, __) => _ErrorStateCard(
                      title: 'Bookings temporarily unavailable',
                      onRetry: () => ref.invalidate(myRecentBookingsProvider),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _PremiumCard(
                    radius: 24,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionRow(icon: Icons.calendar_month_rounded, label: 'Bookings', onTap: () => context.go(isPreview ? '/bookings?preview=1' : '/bookings')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.star_outline_rounded, label: 'My Reviews', onTap: () => context.push(isPreview ? '/my-reviews?preview=1' : '/my-reviews')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.favorite_border_rounded, label: 'Favorites', onTap: () => context.push(isPreview ? '/favorites?preview=1' : '/favorites')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.location_on_outlined, label: 'Addresses', onTap: () => context.push(isPreview ? '/addresses?preview=1' : '/addresses')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.diamond_outlined, label: 'Loyalty', onTap: () => context.push(isPreview ? '/points?preview=1' : '/points')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.go(isPreview ? '/notifications?preview=1' : '/notifications')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.support_agent_rounded, label: 'Support', onTap: () => context.push(isPreview ? '/support?preview=1' : '/support')),
                        const SizedBox(height: 10),
                        _ActionRow(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push(isPreview ? '/settings?preview=1' : '/settings')),
                        const SizedBox(height: 10),
                        _ActionRow(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          danger: true,
                          onTap: () async {
                            if (isPreview) {
                              showSuccessSnackBar(context, 'Preview mode');
                              return;
                            }
                            await ref.read(authRepositoryProvider).signOut();
                            if (!context.mounted) return;
                            context.go('/auth');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _PhotoAction { gallery, remove }

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 390,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 10, 0, MediaQuery.of(context).padding.bottom + 120),
        children: [
          _PremiumCard(
            radius: 24,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: const GoldShimmer(width: double.infinity, height: 210, borderRadius: BorderRadius.zero),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 56, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GoldShimmer(width: 170, height: 18, borderRadius: BorderRadius.all(Radius.circular(10))),
                      const SizedBox(height: 10),
                      const GoldShimmer(width: 120, height: 12, borderRadius: BorderRadius.all(Radius.circular(10))),
                      const SizedBox(height: 10),
                      const GoldShimmer(width: 160, height: 12, borderRadius: BorderRadius.all(Radius.circular(10))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _StatsCardSkeleton(),
          const SizedBox(height: 14),
          const _MembershipCardSkeleton(),
          const SizedBox(height: 18),
          const GoldShimmer(width: 150, height: 16, borderRadius: BorderRadius.all(Radius.circular(10))),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: GoldShimmer(width: double.infinity, height: 74, borderRadius: BorderRadius.all(Radius.circular(18)))),
              const SizedBox(width: 8),
              const Expanded(child: GoldShimmer(width: double.infinity, height: 74, borderRadius: BorderRadius.all(Radius.circular(18)))),
              const SizedBox(width: 8),
              const Expanded(child: GoldShimmer(width: double.infinity, height: 74, borderRadius: BorderRadius.all(Radius.circular(18)))),
              const SizedBox(width: 8),
              const Expanded(child: GoldShimmer(width: double.infinity, height: 74, borderRadius: BorderRadius.all(Radius.circular(18)))),
              const SizedBox(width: 8),
              const Expanded(child: GoldShimmer(width: double.infinity, height: 74, borderRadius: BorderRadius.all(Radius.circular(18)))),
            ],
          ),
          const SizedBox(height: 18),
          const GoldShimmer(width: 160, height: 16, borderRadius: BorderRadius.all(Radius.circular(10))),
          const SizedBox(height: 10),
          const _RecentBookingCardSkeleton(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserProfile profile;
  final String name;
  final String tier;
  final String locationText;
  final bool verified;
  final int unreadCount;
  final bool uploading;
  final VoidCallback onTapCover;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapSettings;

  const _HeaderCard({
    required this.profile,
    required this.name,
    required this.tier,
    required this.locationText,
    required this.verified,
    required this.unreadCount,
    required this.uploading,
    required this.onTapCover,
    required this.onTapAvatar,
    required this.onTapNotifications,
    required this.onTapSettings,
  });

  @override
  Widget build(BuildContext context) {
    const coverHeight = 210.0;
    const avatarSize = 96.0;

    return _PremiumCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapCover,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      LuxuryNetworkImage(
                        key: ValueKey('cover:${(profile.coverUrl ?? '').trim()}'),
                        imageUrl: profile.coverUrl,
                        fallbackUrl: HallaqImages.luxuryBarberInterior(),
                        fallbackKey: 'default_profile_cover',
                        width: double.infinity,
                        height: coverHeight,
                        borderRadius: BorderRadius.zero,
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.10),
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            _TopIcon(
                              icon: Icons.notifications_none_rounded,
                              badge: unreadCount,
                              onTap: onTapNotifications,
                            ),
                            const SizedBox(width: 10),
                            _TopIcon(icon: Icons.settings_outlined, onTap: onTapSettings),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 56, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.verified_rounded, size: 18, color: AppTheme.gold),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (verified) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 16, color: AppTheme.gold.withValues(alpha: 0.95)),
                          const SizedBox(width: 6),
                          Text(
                            'Verified',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined, size: 16, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(
                          '$tier Member',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 18,
            top: coverHeight - (avatarSize / 2),
            child: _Avatar(
              url: profile.avatarUrl,
              uploading: uploading,
              onTap: onTapAvatar,
              size: avatarSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final VoidCallback onTap;

  const _TopIcon({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
                ),
                child: Text(
                  badge! > 99 ? '99+' : badge!.toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final bool uploading;
  final VoidCallback onTap;
  final double size;

  const _Avatar({
    required this.url,
    required this.uploading,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Hero(
        tag: 'profile_avatar',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface,
            boxShadow: AppTheme.softShadow(opacity: 0.14),
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              ClipOval(
                child: LuxuryNetworkImage(
                  key: ValueKey('avatar:${(url ?? '').trim()}'),
                  imageUrl: url,
                  fallbackUrl: HallaqImages.customerAvatar(),
                  fallbackKey: 'default_profile_avatar',
                  width: size,
                  height: size,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.black),
                ),
              ),
              if (uploading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String totalBookings;
  final String avgRating;
  final String favoriteBarbers;
  final String loyaltyPoints;

  const _StatsCard({
    required this.totalBookings,
    required this.avgRating,
    required this.favoriteBarbers,
    required this.loyaltyPoints,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(icon: Icons.calendar_month_outlined, value: totalBookings, label: 'Total Bookings'),
      _StatItem(icon: Icons.star_border_rounded, value: avgRating, label: 'Avg Rating'),
      _StatItem(icon: Icons.favorite_border_rounded, value: favoriteBarbers, label: 'Favorite Barbers'),
      _StatItem(icon: Icons.diamond_outlined, value: loyaltyPoints, label: 'Loyalty Points'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        if (!compact) {
          return _PremiumCard(
            radius: 24,
            child: Row(
              children: [
                Expanded(child: items[0]),
                const _VSeparator(),
                Expanded(child: items[1]),
                const _VSeparator(),
                Expanded(child: items[2]),
                const _VSeparator(),
                Expanded(child: items[3]),
              ],
            ),
          );
        }

        final itemWidth = (constraints.maxWidth - 12) / 2;
        return _PremiumCard(
          radius: 24,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(growable: false),
          ),
        );
      },
    );
  }
}

class _StatsCardSkeleton extends StatelessWidget {
  const _StatsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    const items = [
      _StatItemSkeleton(),
      _StatItemSkeleton(),
      _StatItemSkeleton(),
      _StatItemSkeleton(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        if (!compact) {
          return _PremiumCard(
            radius: 24,
            child: Row(
              children: const [
                Expanded(child: _StatItemSkeleton()),
                _VSeparator(),
                Expanded(child: _StatItemSkeleton()),
                _VSeparator(),
                Expanded(child: _StatItemSkeleton()),
                _VSeparator(),
                Expanded(child: _StatItemSkeleton()),
              ],
            ),
          );
        }

        final itemWidth = (constraints.maxWidth - 12) / 2;
        return _PremiumCard(
          radius: 24,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(growable: false),
          ),
        );
      },
    );
  }
}

class _StatItemSkeleton extends StatelessWidget {
  const _StatItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoldShimmer(width: 18, height: 18, borderRadius: BorderRadius.all(Radius.circular(6))),
          const SizedBox(height: 10),
          const GoldShimmer(width: 28, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(height: 8),
          const GoldShimmer(width: 62, height: 10, borderRadius: BorderRadius.all(Radius.circular(8))),
        ],
      ),
    );
  }
}

class _VSeparator extends StatelessWidget {
  const _VSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: AppTheme.border);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final String tier;
  final int points;
  final VoidCallback onViewBenefits;

  const _MembershipCard({required this.tier, required this.points, required this.onViewBenefits});

  @override
  Widget build(BuildContext context) {
    const tiers = {'Silver': 0, 'Gold': 300, 'Platinum': 700};
    final nextTier = switch (tier) {
      'Silver' => 'Gold',
      'Gold' => 'Platinum',
      _ => 'Platinum',
    };
    final nextReq = tiers[nextTier] ?? 700;
    final remaining = (nextReq - points).clamp(0, 999999);
    final progress = nextReq == 0 ? 1.0 : (points / nextReq).clamp(0, 1).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF121212),
            boxShadow: AppTheme.softShadow(opacity: 0.14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _MembershipCopy(tier: tier, points: points, remaining: remaining, nextTier: nextTier)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: onViewBenefits,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text('View Benefits', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _MembershipCopy(tier: tier, points: points, remaining: remaining, nextTier: nextTier)),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 38,
                        child: FilledButton(
                          onPressed: onViewBenefits,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text('View Benefits', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.20))),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.goldGradient)),
                        ),
                      ],
                    ),
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

class _MembershipCopy extends StatelessWidget {
  final String tier;
  final int points;
  final int remaining;
  final String nextTier;

  const _MembershipCopy({
    required this.tier,
    required this.points,
    required this.remaining,
    required this.nextTier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$tier Member',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'You have ${NumberFormat.decimalPattern().format(points)} points',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          remaining == 0 ? 'You reached $nextTier' : '$remaining points away from $nextTier',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MembershipCardSkeleton extends StatelessWidget {
  const _MembershipCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF121212),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GoldShimmer(width: 42, height: 42, borderRadius: BorderRadius.all(Radius.circular(999))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoldShimmer(width: 110, height: 14, borderRadius: BorderRadius.all(Radius.circular(10))),
                      SizedBox(height: 8),
                      GoldShimmer(width: 160, height: 12, borderRadius: BorderRadius.all(Radius.circular(10))),
                      SizedBox(height: 8),
                      GoldShimmer(width: 140, height: 10, borderRadius: BorderRadius.all(Radius.circular(10))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const GoldShimmer(width: 110, height: 38, borderRadius: BorderRadius.all(Radius.circular(999))),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(height: 6, child: GoldShimmer(width: double.infinity, height: 6, borderRadius: BorderRadius.all(Radius.circular(999)))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutsRow extends StatelessWidget {
  final VoidCallback onBookings;
  final VoidCallback onMembership;
  final VoidCallback onReviews;
  final VoidCallback onSaved;
  final VoidCallback onAddresses;

  const _ShortcutsRow({
    required this.onBookings,
    required this.onMembership,
    required this.onReviews,
    required this.onSaved,
    required this.onAddresses,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShortcutCard(icon: Icons.calendar_month_outlined, label: 'My Bookings', onTap: onBookings),
      _ShortcutCard(icon: Icons.workspace_premium_outlined, label: 'Membership', onTap: onMembership),
      _ShortcutCard(icon: Icons.star_border_rounded, label: 'My Reviews', onTap: onReviews),
      _ShortcutCard(icon: Icons.bookmark_border_rounded, label: 'Saved', onTap: onSaved),
      _ShortcutCard(icon: Icons.location_on_outlined, label: 'Addresses', onTap: onAddresses),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 440 ? 5 : 3;
        final spacing = 8.0;
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(growable: false),
        );
      },
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 18,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 84,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.text, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentBookingCard extends StatelessWidget {
  final MyBookingCard item;

  const _RecentBookingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final date = DateFormat('EEE, d MMM yyyy', locale.toLanguageTag()).format(item.startAt.toLocal());
    final time = DateFormat('h:mm a', locale.toLanguageTag()).format(item.startAt.toLocal());
    final statusText = switch (item.status.name) {
      'confirmed' => 'Confirmed',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Pending',
    };
    final statusColor = switch (item.status.name) {
      'confirmed' => AppTheme.success,
      'completed' => AppTheme.text,
      'cancelled' => AppTheme.error,
      _ => const Color(0xFFFFC300),
    };
    final service = ((Localizations.localeOf(context).languageCode == 'ar') ? item.serviceNameAr : item.serviceNameEn) ?? '';
    return _PremiumCard(
      radius: 24,
      onTap: () => context.go('/bookings'),
      child: Row(
        children: [
          ClipOval(
            child: LuxuryNetworkImage(
              imageUrl: item.barberAvatarUrl,
              fallbackUrl: HallaqImages.barberAvatar(),
              width: 52,
              height: 52,
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
                        service.isNotEmpty ? service : (item.barberName ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((item.barberName ?? '').trim().isNotEmpty) item.barberName!.trim(),
                    if ((item.shopName ?? '').trim().isNotEmpty) item.shopName!.trim(),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '$date  •  $time',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _RecentBookingCardSkeleton extends StatelessWidget {
  const _RecentBookingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 24,
      child: Row(
        children: [
          const GoldShimmer(width: 52, height: 52, borderRadius: BorderRadius.all(Radius.circular(999))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GoldShimmer(width: 140, height: 14, borderRadius: BorderRadius.all(Radius.circular(10))),
                const SizedBox(height: 8),
                const GoldShimmer(width: 210, height: 12, borderRadius: BorderRadius.all(Radius.circular(10))),
                const SizedBox(height: 8),
                const GoldShimmer(width: 170, height: 12, borderRadius: BorderRadius.all(Radius.circular(10))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const GoldShimmer(width: 18, height: 18, borderRadius: BorderRadius.all(Radius.circular(6))),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, height: 1.3)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                child: Text(actionLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorStateCard extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const _ErrorStateCard({required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.text,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text('Retry', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      child: child,
    );

    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.error : AppTheme.text;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.surface,
          border: Border.all(color: danger ? AppTheme.error.withValues(alpha: 0.22) : AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
            ),
            Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: AppTheme.textMuted.withValues(alpha: 0.9)),
          ],
        ),
      ),
    );
  }
}
