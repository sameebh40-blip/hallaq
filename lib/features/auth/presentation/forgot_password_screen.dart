import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_text_field.dart';
import '../../../core/widgets/premium_hero_card.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  String? _validateEmail(AppLocalizations l10n, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.requiredField;
    if (!v.contains('@') || !v.contains('.')) return l10n.invalidEmail;
    return null;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email: _email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return AuthScaffold(
      showBack: true,
      imageUrl: HallaqImages.blackGoldBackground(variant: '03'),
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
                    imageUrl: HallaqImages.goldScissorsIllustration(variant: '01'),
                    fallbackUrl: HallaqImages.goldScissorsIllustration(variant: '02'),
                    title: rtl ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                    subtitle: rtl ? 'سنرسل رابط إعادة التعيين إلى بريدك.' : 'We’ll email you a secure reset link.',
                    height: 210,
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    glow: true,
                    blur: 20,
                    borderColor: AppTheme.gold.withValues(alpha: 0.18),
                    tint: const Color(0x16121212),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _sent
                          ? _Success(
                              title: rtl ? 'تم الإرسال' : 'Check your inbox',
                              subtitle: rtl ? 'أرسلنا رابط إعادة التعيين إلى بريدك.' : 'We sent a reset link to your email.',
                            )
                          : Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                key: const ValueKey('form'),
                                children: [
                                  LuxuryTextField(
                                    controller: _email,
                                    label: l10n.email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.done,
                                    enabled: !_busy,
                                    validator: (v) => _validateEmail(l10n, v),
                                    autofillHints: const [AutofillHints.email],
                                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                                  ),
                                  const SizedBox(height: 14),
                                  LuxuryButton(
                                    label: rtl ? 'إرسال رابط إعادة التعيين' : 'Send Reset Link',
                                    onPressed: _busy ? null : _submit,
                                    isLoading: _busy,
                                  ),
                                ],
                              ),
                            ),
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

class _Success extends StatefulWidget {
  final String title;
  final String subtitle;

  const _Success({required this.title, required this.subtitle});

  @override
  State<_Success> createState() => _SuccessState();
}

class _SuccessState extends State<_Success> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return Column(
      key: const ValueKey('success'),
      children: [
        ScaleTransition(
          scale: curved,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFFD4AF37), size: 40),
          ),
        ),
        const SizedBox(height: 14),
        FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: Column(
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
