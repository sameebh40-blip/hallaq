import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../shop/data/shop_repository.dart';

class ShopQrCenterScreen extends ConsumerWidget {
  const ShopQrCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(myShopProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('QR Center', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 110),
              child: HallaqCard(glass: true, child: Text('No shop assigned to this account.')),
            );
          }

          final profileLink = 'hallaq://shop/${shop.id}';
          final bookingLink = 'hallaq://book?shopId=${Uri.encodeQueryComponent(shop.id)}';
          final reviewLink = 'hallaq://review?targetType=shop&targetId=${Uri.encodeQueryComponent(shop.id)}';
          final followLink = 'hallaq://shop/${shop.id}?action=follow';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LuxuryNetworkImage(
                      imageUrl: shop.logoUrl,
                      fallbackUrl: HallaqImages.shopLogo(variant: '01'),
                      width: 46,
                      height: 46,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Generate and share QR codes for your shop.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              _QrCard(title: 'Shop Profile', description: 'Open your shop profile in the app.', value: profileLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Booking Page', description: 'Start a booking for this shop.', value: bookingLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Leave a Review', description: 'Go directly to the reviews screen.', value: reviewLink),
              const SizedBox(height: 12),
              _QrCard(title: 'Follow Shop', description: 'Open shop profile (follow action).', value: followLink),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Share.share(value),
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR link copied.')));
                    Clipboard.setData(ClipboardData(text: value));
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
