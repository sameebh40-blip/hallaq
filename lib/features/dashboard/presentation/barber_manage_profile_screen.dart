import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_loader.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../../core/routing/routes.dart';
import 'barber_media_controller.dart';

class BarberManageProfileScreen extends ConsumerStatefulWidget {
  final bool showBack;

  const BarberManageProfileScreen({super.key, this.showBack = true});

  @override
  ConsumerState<BarberManageProfileScreen> createState() => _BarberManageProfileScreenState();
}

class _BarberManageProfileScreenState extends ConsumerState<BarberManageProfileScreen> {
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _bio = TextEditingController();
  bool? _homeService;

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barberValue = ref.watch(myBarberProvider);
    final media = ref.watch(barberMediaControllerProvider);

    ref.listen(barberMediaControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
    });

    Future<void> pickAndUpload({required bool cover}) async {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: cover ? 1800 : 900,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (cover) {
        await ref.read(barberMediaControllerProvider.notifier).updateCover(bytes: bytes);
      } else {
        await ref.read(barberMediaControllerProvider.notifier).updateAvatar(bytes: bytes);
      }
    }

    Future<void> save() async {
      await ref.read(barberMediaControllerProvider.notifier).updateDetails(
            displayName: _name.text,
            specialty: _specialty.text,
            bio: _bio.text,
            homeService: _homeService ?? false,
          );
      if (!context.mounted) return;
      showSuccessSnackBar(context, 'Saved');
    }

    return LuxuryScaffold(
      header: widget.showBack
          ? LuxuryTopBar(
              leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
              title: Text('Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            )
          : null,
      child: AsyncValueWidget(
        value: barberValue,
        data: (barber) {
          if (barber == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: HallaqCard(glass: true, child: Text('No barber assigned to this account.')),
            );
          }

          _name.text = _name.text.isEmpty ? barber.displayName : _name.text;
          _specialty.text = _specialty.text.isEmpty ? (barber.specialty ?? '') : _specialty.text;
          _bio.text = _bio.text.isEmpty ? (barber.bio ?? '') : _bio.text;
          _homeService ??= barber.homeService;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              if (!widget.showBack)
                HallaqCard(
                  glass: true,
                  child: Row(
                    children: [
                      HallaqAvatar(imageUrl: barber.avatarUrl, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(barber.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                HallaqRating(value: barber.ratingAvg, count: barber.reviewsCount, iconSize: 16),
                                const SizedBox(width: 10),
                                Text('${barber.followersCount} followers', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (barber.badgeVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
                          ),
                          child: Text('Verified', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                ),
              if (!widget.showBack) const SizedBox(height: 12),
              if (!widget.showBack)
                Column(
                  children: [
                    HallaqTeaserCard(
                      title: 'Manage Services',
                      subtitle: 'Add, edit, and price your services',
                      icon: Icons.design_services_rounded,
                      onTap: () => context.push(Routes.barberManageServices),
                    ),
                    const SizedBox(height: 10),
                    HallaqTeaserCard(
                      title: 'Reels',
                      subtitle: 'Upload and track your reels',
                      icon: Icons.play_circle_outline_rounded,
                      onTap: () => context.push(Routes.barberManageMyReels),
                    ),
                    const SizedBox(height: 10),
                    HallaqTeaserCard(
                      title: 'Reviews',
                      subtitle: 'Reply to customers and improve rating',
                      icon: Icons.star_rate_rounded,
                      onTap: () => context.push(Routes.barberManageReviews),
                    ),
                    const SizedBox(height: 10),
                    HallaqTeaserCard(
                      title: 'Wallet',
                      subtitle: 'Revenue and transactions',
                      icon: Icons.account_balance_wallet_rounded,
                      onTap: () => context.push(Routes.barberManageEarnings),
                    ),
                    const SizedBox(height: 10),
                    HallaqTeaserCard(
                      title: 'Availability',
                      subtitle: 'Working hours and time off',
                      icon: Icons.calendar_month_rounded,
                      onTap: () => context.push(Routes.barberManageAvailability),
                    ),
                    const SizedBox(height: 10),
                    HallaqTeaserCard(
                      title: 'Settings',
                      subtitle: 'Account and preferences',
                      icon: Icons.settings_rounded,
                      onTap: () => context.push(Routes.barberManageSettings),
                    ),
                  ],
                ),
              if (!widget.showBack) const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: media.isLoading ? null : () => pickAndUpload(cover: true),
                child: LuxuryNetworkImage(
                  imageUrl: barber.coverUrl,
                  fallbackUrl: HallaqImages.barberCover(variant: '01'),
                  height: 170,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: media.isLoading ? null : () => pickAndUpload(cover: false),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: LuxuryNetworkImage(
                        imageUrl: barber.avatarUrl,
                        fallbackUrl: HallaqImages.avatar(variant: '01'),
                        width: 66,
                        height: 66,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      barber.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (media.isLoading) const LuxuryLoader(size: 20),
                ],
              ),
              const SizedBox(height: 16),
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _specialty,
                      decoration: const InputDecoration(labelText: 'Specialty'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      decoration: const InputDecoration(labelText: 'Bio'),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _homeService ?? false,
                      onChanged: (v) => setState(() => _homeService = v),
                      title: const Text('Home Service'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
                    LuxuryButton(label: 'Save', isLoading: media.isLoading, onPressed: media.isLoading ? null : save),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
