import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand/brand_assets_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/barber.dart';
import '../../../core/routing/routes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class StyleBarbersPayload {
  final String nameEn;
  final String nameAr;
  final List<Barber> barbers;

  const StyleBarbersPayload({required this.nameEn, required this.nameAr, required this.barbers});
}

final styleBarbersProvider = FutureProvider.family<StyleBarbersPayload, String>((ref, styleId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final styleRow = await client.from('style_library').select('name_en, name_ar').eq('id', styleId).maybeSingle();
    final nameEn = styleRow == null ? '' : ((styleRow as Map)['name_en'] as String?) ?? '';
    final nameAr = styleRow == null ? '' : ((styleRow as Map)['name_ar'] as String?) ?? '';

    final links = await client.from('style_barbers').select('barber_id').eq('style_id', styleId).order('created_at', ascending: false).limit(200);
    final ids = (links as List).map((e) => (e as Map)['barber_id'] as String?).whereType<String>().toSet().toList(growable: false);
    if (ids.isEmpty) return StyleBarbersPayload(nameEn: nameEn, nameAr: nameAr, barbers: const []);

    final rows = await client
        .from('barbers')
        .select(
          'id, profile_id, slug, display_name, avatar_url, avatar_path, cover_url, cover_path, bio, specialty, shop_id, area, address, lat, lng, rating_avg, rating_count, followers_count, reviews_count, is_independent, home_service, available_now, waiting_time_min, queue_length, badge_verified, badge_elite, badge_trending, badge_top_rated, badge_certified, status, created_at',
        )
        .inFilter('id', ids)
        .eq('is_active', true)
        .eq('status', 'approved')
        .limit(200);

    final list = (rows as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
    return StyleBarbersPayload(nameEn: nameEn, nameAr: nameAr, barbers: list);
  } catch (e) {
    throw AppException('Failed to load style', cause: e);
  }
});

class StyleBarbersScreen extends ConsumerWidget {
  final String styleId;

  const StyleBarbersScreen({super.key, required this.styleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final errorImage = ref.watch(brandAssetUrlProvider('default_error_state'))?.trim();
    final emptyImage = ref.watch(brandAssetUrlProvider('default_empty_state'))?.trim();
    final value = ref.watch(styleBarbersProvider(styleId));
    final isAr = l10n.locale.languageCode == 'ar';

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        title: Text('Style', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<StyleBarbersPayload>(
        value: value,
        errorImageUrl: errorImage,
        onRetry: () => ref.invalidate(styleBarbersProvider(styleId)),
        data: (payload) {
          final styleName = (isAr ? payload.nameAr : payload.nameEn).trim().isNotEmpty
              ? (isAr ? payload.nameAr : payload.nameEn).trim()
              : payload.nameEn.trim().isNotEmpty
                  ? payload.nameEn.trim()
                  : 'Style';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              Text(
                styleName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Barbers offering this style',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (payload.barbers.isEmpty)
                HallaqEmptyState(
                  title: 'No barbers found',
                  description: 'Try another style or change area.',
                  imageUrl: emptyImage,
                  showMascot: true,
                )
              else
                ...payload.barbers.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HallaqCard(
                        glass: true,
                        onTap: () => context.push('${Routes.barberProfile}/${b.id}'),
                        child: Row(
                          children: [
                            HallaqAvatar(imageUrl: b.avatarUrl ?? b.avatarPath, size: 54, bucket: 'barber-images'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      HallaqRating(value: b.ratingAvg, count: b.ratingCount, iconSize: 14),
                                      const SizedBox(width: 10),
                                      if ((b.area ?? '').trim().isNotEmpty)
                                        Text(
                                          b.area!.trim(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
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
                    )),
            ],
          );
        },
      ),
    );
  }
}
