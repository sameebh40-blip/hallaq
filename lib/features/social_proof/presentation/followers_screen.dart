import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/social_proof/social_proof_repository.dart';

class FollowersScreen extends ConsumerWidget {
  final String targetType;
  final String targetId;

  const FollowersScreen({super.key, required this.targetType, required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(followersListProvider((targetType: targetType, targetId: targetId)));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.followers, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<List<PublicProfile>>(
        value: value,
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: HallaqEmptyState(
                title: l10n.followers,
                description: l10n.comingSoon,
                showMascot: true,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final p = items[index];
              return HallaqCard(
                glass: true,
                child: Row(
                  children: [
                    HallaqAvatar(
                      imageUrl: p.avatarUrl,
                      size: 52,
                      variant: ((index % 6) + 1).toString().padLeft(2, '0'),
                      fallbackUrl: HallaqImages.customerAvatar(variant: ((index % 6) + 1).toString().padLeft(2, '0')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName ?? 'Customer', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(p.area ?? l10n.bahrain, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_user_rounded, color: AppTheme.gold),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
