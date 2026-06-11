import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/premium_hero_card.dart';
import '../data/auth_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  static const _cooldownSeconds = 30;

  Timer? _timer;
  int _cooldown = _cooldownSeconds;
  bool _busy = false;

  bool get _canResend => !_busy && _cooldown <= 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 0) {
        t.cancel();
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  Future<void> _openMail() async {
    final uri = Uri(scheme: 'mailto', path: widget.email);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resendEmailVerification(email: widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final title = rtl ? 'تحقق من بريدك' : 'Check your email';
    final subtitle = rtl
        ? 'أرسلنا لك رابطاً لتأكيد البريد. بعد التأكيد، قم بتسجيل الدخول للمتابعة.'
        : 'We sent a verification link. After confirming, sign in to continue.';

    return AuthScaffold(
      showBack: true,
      imageUrl: HallaqImages.blackGoldBackground(variant: '06'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth * 0.92).clamp(0, 520).toDouble();
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: w,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 68, 0, 26),
                children: [
                  PremiumHeroCard(
                    imageUrl: HallaqImages.goldScissorsIllustration(variant: '03'),
                    fallbackUrl: HallaqImages.goldScissorsIllustration(variant: '04'),
                    title: title,
                    subtitle: subtitle,
                    height: 220,
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
                          const Icon(Icons.mail_rounded, size: 16, color: AppTheme.gold),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    glow: true,
                    blur: 20,
                    borderColor: AppTheme.gold.withValues(alpha: 0.18),
                    tint: const Color(0x16121212),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rtl ? 'الخطوات' : 'Next steps',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        const _StepLine(icon: Icons.mark_email_read_rounded, en: 'Open the email and tap Verify', ar: 'افتح البريد واضغط تأكيد'),
                        const SizedBox(height: 10),
                        const _StepLine(icon: Icons.login_rounded, en: 'Return and log in', ar: 'ارجع وسجّل الدخول'),
                        const SizedBox(height: 16),
                        LuxuryButton(
                          label: rtl ? 'فتح البريد' : 'Open Email',
                          variant: LuxuryButtonVariant.ghost,
                          onPressed: _busy ? null : _openMail,
                          icon: Icons.open_in_new_rounded,
                        ),
                        const SizedBox(height: 10),
                        LuxuryButton(
                          label: rtl
                              ? (_cooldown > 0 ? 'إعادة الإرسال خلال ${_cooldown}s' : 'إعادة إرسال رابط التأكيد')
                              : (_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend verification link'),
                          variant: LuxuryButtonVariant.secondary,
                          onPressed: _canResend ? _resend : null,
                          icon: Icons.refresh_rounded,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              rtl ? 'تم التأكيد؟' : 'Already verified?',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _busy ? null : () => context.go('/auth/sign-in'),
                              child: Text(
                                rtl ? 'تسجيل الدخول' : 'Log in',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppTheme.gold,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: GestureDetector(
                            onTap: _busy ? null : () => context.go('/auth/sign-up?email=${Uri.encodeComponent(widget.email)}'),
                            child: Text(
                              rtl ? 'تغيير البريد' : 'Change email',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final IconData icon;
  final String en;
  final String ar;

  const _StepLine({required this.icon, required this.en, required this.ar});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: AppTheme.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isAr ? ar : en,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
