import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/caps_lock_hint.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_text_field.dart';
import '../../../core/widgets/password_strength_meter.dart';
import '../../../core/widgets/premium_hero_card.dart';
import '../../../core/widgets/social_auth_row.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../data/customer_repository.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  bool _agree = false;
  bool _entered = false;

  String? _validateRequired(AppLocalizations l10n, String? value) {
    if ((value ?? '').trim().isEmpty) return l10n.requiredField;
    return null;
  }

  String? _validateEmail(AppLocalizations l10n, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.requiredField;
    if (!v.contains('@') || !v.contains('.')) return l10n.invalidEmail;
    return null;
  }

  String? _validatePhone(AppLocalizations l10n, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.requiredField;
    final digits = v.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 8) return isRtl(context) ? 'رقم هاتف غير صالح' : 'Enter a valid phone number';
    return null;
  }

  bool isRtl(BuildContext context) => Directionality.of(context) == TextDirection.rtl;

  String? _validatePassword(AppLocalizations l10n, String? value) {
    final v = value ?? '';
    if (v.isEmpty) return l10n.requiredField;
    if (v.length < 8) return l10n.passwordTooShort;
    return null;
  }

  String? _validateConfirmPassword(AppLocalizations l10n, String? value) {
    final v = value ?? '';
    if (v.isEmpty) return l10n.requiredField;
    if (v != _password.text) return l10n.passwordsDontMatch;
    return null;
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message.isEmpty ? const AppException('Coming soon') : e);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message.isEmpty ? const AppException('Coming soon') : e);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final email = GoRouterState.of(context).uri.queryParameters['email'];
    if (email != null && email.trim().isNotEmpty && _email.text.trim().isEmpty) {
      _email.text = email.trim();
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).acceptTermsMessage)));
      return;
    }

    final locale = ref.read(localeControllerProvider) ?? Localizations.localeOf(context);
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      final res = await ref.read(authRepositoryProvider).signUpWithEmail(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
          );
      if (res.session == null) {
        if (!mounted) return;
        context.go('/auth/verify-email?email=${Uri.encodeComponent(email)}');
        return;
      }

      await ref.read(profileRepositoryProvider).ensureMyProfile();
      await ref.read(profileRepositoryProvider).upsertMyProfile(
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
          );

      await ref.read(customerRepositoryProvider).upsertMyCustomer(
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
            email: email,
            language: locale.languageCode,
          );

      HallaqHaptics.success();
      if (!mounted) return;
      context.go('/auth/success');
    } on AppException catch (e) {
      if (!mounted) return;
      HallaqHaptics.error();
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rtl = isRtl(context);

    return AuthScaffold(
      showBack: true,
      imageUrl: HallaqImages.blackGoldBackground(variant: '01'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth * 0.92).clamp(0, 520).toDouble();
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: w,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                offset: _entered ? Offset.zero : const Offset(0, 0.05),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  opacity: _entered ? 1 : 0,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 68, 0, 26),
                    children: [
                      PremiumHeroCard(
                        imageUrl: HallaqImages.premiumGrooming(variant: '01'),
                        fallbackUrl: HallaqImages.premiumGrooming(variant: '02'),
                        title: rtl ? 'إنشاء حساب' : 'Create Account',
                        subtitle: rtl ? 'ابدأ رحلتك واحجز أفضل الحلاقين في البحرين' : 'Join Bahrain’s premium barber discovery & booking app.',
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        glow: true,
                        blur: 20,
                        borderColor: AppTheme.gold.withValues(alpha: 0.18),
                        tint: const Color(0x16121212),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Form(
                          key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: AutofillGroup(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _StepPill(label: rtl ? 'إنشاء' : 'Create', icon: Icons.person_add_alt_rounded, active: true),
                                    const SizedBox(width: 10),
                                    _StepPill(label: rtl ? 'استكشف' : 'Discover', icon: Icons.search_rounded, active: false),
                                    const SizedBox(width: 10),
                                    _StepPill(label: rtl ? 'احجز' : 'Book', icon: Icons.event_available_rounded, active: false),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                LuxuryTextField(
                                  controller: _fullName,
                                  label: l10n.fullName,
                                  enabled: !_busy,
                                  validator: (v) => _validateRequired(l10n, v),
                                  autofillHints: const [AutofillHints.name],
                                  prefixIcon: const Icon(Icons.person_outline_rounded),
                                ),
                                const SizedBox(height: 12),
                                LuxuryTextField(
                                  controller: _phone,
                                  label: rtl ? 'رقم الهاتف' : 'Phone Number',
                                  keyboardType: TextInputType.phone,
                                  enabled: !_busy,
                                  validator: (v) => _validatePhone(l10n, v),
                                  autofillHints: const [AutofillHints.telephoneNumber],
                                  prefixIcon: const Icon(Icons.call_outlined),
                                ),
                                const SizedBox(height: 12),
                                LuxuryTextField(
                                  controller: _email,
                                  label: l10n.email,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_busy,
                                  validator: (v) => _validateEmail(l10n, v),
                                  autofillHints: const [AutofillHints.email],
                                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                                ),
                                const SizedBox(height: 12),
                                LuxuryTextField(
                                  controller: _password,
                                  label: l10n.password,
                                  obscureText: true,
                                  allowObscureToggle: true,
                                  keyboardType: TextInputType.visiblePassword,
                                  enabled: !_busy,
                                  validator: (v) => _validatePassword(l10n, v),
                                  autofillHints: const [AutofillHints.newPassword],
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                ),
                                const SizedBox(height: 10),
                                ValueListenableBuilder(
                                  valueListenable: _password,
                                  builder: (context, value, _) => PasswordStrengthMeter(password: value.text),
                                ),
                                const SizedBox(height: 10),
                                const Align(alignment: AlignmentDirectional.centerStart, child: CapsLockHint()),
                                const SizedBox(height: 12),
                                LuxuryTextField(
                                  controller: _confirmPassword,
                                  label: l10n.confirmPassword,
                                  obscureText: true,
                                  allowObscureToggle: true,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.done,
                                  enabled: !_busy,
                                  validator: (v) => _validateConfirmPassword(l10n, v),
                                  autofillHints: const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _busy
                                          ? null
                                          : () {
                                              HallaqHaptics.selection();
                                              setState(() => _agree = !_agree);
                                            },
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          gradient: _agree ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFD4AF37), Color(0xFF8E6B1F)]) : null,
                                          color: _agree ? null : const Color(0xFF0F0F0F).withValues(alpha: 0.72),
                                          border: Border.all(color: _agree ? Colors.transparent : Colors.white.withValues(alpha: 0.18)),
                                        ),
                                        child: _agree ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        rtl ? 'أوافق على الشروط والأحكام' : 'I agree to Terms & Conditions',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.82),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                LuxuryButton(
                                  label: rtl ? 'إنشاء حساب' : 'Create Account',
                                  onPressed: _busy ? null : _submit,
                                  isLoading: _busy,
                                ),
                                const SizedBox(height: 14),
                                SocialAuthRow(
                                  enabled: !_busy && ref.read(authRepositoryProvider).isConfigured,
                                  onGoogle: _signInWithGoogle,
                                  onApple: _signInWithApple,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            rtl ? 'لديك حساب؟' : 'Already have an account?',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _busy ? null : () => context.go('/auth/sign-in'),
                            child: Text(
                              rtl ? 'تسجيل الدخول' : 'Login',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  const _StepPill({required this.label, required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active ? const Color(0xFF0F0F0F).withValues(alpha: 0.72) : const Color(0xFF0B0B0B).withValues(alpha: 0.55),
          border: Border.all(color: active ? AppTheme.gold.withValues(alpha: 0.55) : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? AppTheme.gold : AppTheme.textMuted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
