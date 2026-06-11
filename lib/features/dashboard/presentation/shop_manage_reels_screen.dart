import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/reel.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/routing/routes.dart';
import '../../shop/data/shop_repository.dart';

final _myShopReelsProvider = FutureProvider<List<Reel>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Reel>[];
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('reels').select().eq('shop_id', shop.id).isFilter('deleted_at', null).order('created_at', ascending: false).limit(60);
  return (data as List).map((e) => Reel.fromJson(Map<String, dynamic>.from(e))).toList();
});

class ShopManageReelsScreen extends ConsumerWidget {
  const ShopManageReelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_myShopReelsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Reels', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(icon: Icons.add_rounded, onPressed: () => context.push(Routes.shopUploadReel)),
      ),
      child: AsyncValueWidget<List<Reel>>(
        value: value,
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No reels yet.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: items.map((r) => _ReelRow(reel: r)).toList(),
          );
        },
      ),
    );
  }
}

class _ReelRow extends StatelessWidget {
  final Reel reel;

  const _ReelRow({required this.reel});

  @override
  Widget build(BuildContext context) {
    final thumbPath = (reel.thumbnailPath ?? '').trim();
    final thumbUrl = (reel.thumbnailUrl ?? '').trim();
    final mediaPath = (reel.mediaPath ?? '').trim();
    final mediaUrl = reel.mediaUrl.trim();
    final thumb = thumbPath.isNotEmpty
        ? thumbPath
        : thumbUrl.isNotEmpty
            ? thumbUrl
            : reel.mediaType == 'image'
                ? (mediaPath.isNotEmpty ? mediaPath : mediaUrl)
                : '';
    final status = reel.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 74,
                height: 74,
                child: LuxuryNetworkImage(
                  imageUrl: thumb,
                  fallbackUrl: '',
                  bucket: 'reels',
                  borderRadius: BorderRadius.zero,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((reel.caption ?? '').trim().isEmpty ? 'Reel' : (reel.caption ?? '').trim(),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
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
