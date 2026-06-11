import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/brand/brand_assets_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';

class BarberQrCenterScreen extends ConsumerWidget {
  const BarberQrCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(myBarberProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('QR Code', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: barberValue,
        data: (barber) {
          if (barber == null) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 110),
              child: HallaqCard(glass: true, child: Text('No barber assigned to this account.')),
            );
          }

          final avatarFallback = ref.watch(brandAssetUrlProvider('default_barber_avatar'))?.trim() ?? '';
          final avatar = (barber.avatarUrl ?? '').trim();

          final profileLink = 'hallaq://barber/${barber.id}';
          final bookingLink = 'hallaq://book?barberId=${Uri.encodeQueryComponent(barber.id)}';
          final reviewLink = 'hallaq://review?targetType=barber&targetId=${Uri.encodeQueryComponent(barber.id)}';
          final followLink = 'hallaq://barber/${barber.id}?action=follow';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LuxuryNetworkImage(
                      imageUrl: avatar,
                      fallbackUrl: avatarFallback,
                      bucket: 'barber-images',
                      width: 46,
                      height: 46,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      barber.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Generate and share QR codes for your barber profile.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              _QrCard(title: 'Barber Profile', description: 'Open your barber profile in the app.', value: profileLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Booking Page', description: 'Start a booking for this barber.', value: bookingLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Leave a Review', description: 'Go directly to the reviews screen.', value: reviewLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Follow Barber', description: 'Open barber profile (follow action).', value: followLink),
            ],
          );
        },
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const _QrCard({required this.title, required this.description, required this.value});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
              ),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Share.share(value), child: const Text('Share'))),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR link copied.')));
                  },
                  child: const Text('Copy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

