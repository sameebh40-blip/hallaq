import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/glass_card.dart';

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return AuthScaffold(
      imageUrl: HallaqImages.blackGoldBackground(variant: '07'),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 74, 16, 26),
            children: [
              GlassCard(
                glow: true,
                blur: 18,
                borderColor: AppTheme.gold.withValues(alpha: 0.16),
                tint: const Color(0x16121212),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'تم إيقاف الحساب' : 'Account suspended',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isAr
                          ? 'تم تسجيل خروجك لأن حسابك موقوف. تواصل مع الدعم لإعادة التفعيل.'
                          : 'You have been signed out because your account is suspended. Contact support to reactivate.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => context.go('/auth'),
                            child: Text(isAr ? 'العودة' : 'Back', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
