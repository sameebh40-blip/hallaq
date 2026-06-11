import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/number_formatters.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/social_proof/social_proof_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';

class BookingsInfoScreen extends ConsumerWidget {
  final String? barberId;
  final String? shopId;

  const BookingsInfoScreen({super.key, this.barberId, this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = barberId != null
        ? ref.watch(bookingsCountForBarberProvider(barberId!))
        : (shopId != null ? ref.watch(bookingsCountForShopProvider(shopId!)) : const AsyncValue.data(0));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(l10n.bookingsCount, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<int>(
        value: value,
        data: (count) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              HallaqCard(
                glass: true,
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: AppTheme.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        NumberFormatters.compactInt(count),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HallaqCard(
                glass: true,
                child: Text(
                  l10n.comingSoon,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, height: 1.45),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

