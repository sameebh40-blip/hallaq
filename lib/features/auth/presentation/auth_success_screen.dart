import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/luxury_loader.dart';
import '../../../core/widgets/premium_hero_card.dart';

class AuthSuccessScreen extends StatefulWidget {
  const AuthSuccessScreen({super.key});

  @override
  State<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends State<AuthSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    HallaqHaptics.success();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      context.go(Routes.splash);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return AuthScaffold(
      imageUrl: HallaqImages.blackGoldBackground(variant: '07'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth * 0.92).clamp(0, 520).toDouble();
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: w,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_c.value);
                  final float = math.sin(_c.value * math.pi * 2) * 6;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 74, 0, 26),
                    children: [
                      Transform.translate(
                        offset: Offset(0, (1 - t) * 10),
                        child: Opacity(
                          opacity: t,
                          child: PremiumHeroCard(
                            imageUrl: HallaqImages.luxuryBarberInterior(variant: '05'),
                            fallbackUrl: HallaqImages.luxuryBarberInterior(variant: '06'),
                            title: isAr ? 'تم إنشاء الحساب' : 'Account created',
                            subtitle: isAr ? 'جاهز لقصّة فخمة؟' : 'Ready for a premium cut?',
                            height: 210,
                            badge: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: const Color(0xFF0F0F0F).withValues(alpha: 0.55),
                                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.gold),
                                  const SizedBox(width: 6),
                                  Text(
                                    isAr ? 'تم' : 'Success',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Transform.translate(
                        offset: Offset(0, (1 - t) * 14),
                        child: Opacity(
                          opacity: t,
                          child: Stack(
                            children: [
                              PositionedDirectional(
                                top: 8 + float,
                                start: 6,
                                child: _GlowOrb(size: 92, opacity: 0.10),
                              ),
                              PositionedDirectional(
                                bottom: 10 - float,
                                end: 8,
                                child: _GlowOrb(size: 116, opacity: 0.14),
                              ),
                              GlassCard(
                                glow: true,
                                blur: 18,
                                borderColor: AppTheme.gold.withValues(alpha: 0.16),
                                tint: const Color(0x16121212),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: AppTheme.goldGradient,
                                        boxShadow: AppTheme.softShadow(opacity: 0.36),
                                      ),
                                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAr ? 'نحضّر لك تجربة فاخرة…' : 'Setting up your experience…',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white.withValues(alpha: 0.92),
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            isAr ? 'ثوانٍ قليلة وننقلك إلى الاستكشاف' : 'Just a second — taking you to Explore',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.white.withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const LuxuryLoader(size: 22),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowOrb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.gold.withValues(alpha: opacity),
            AppTheme.gold.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
