import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_text_field.dart';
import '../../../core/widgets/premium_hero_card.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;

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

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword: _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.done)));
      context.go(Routes.splash);
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
      imageUrl: HallaqImages.blackGoldBackground(variant: '04'),
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
                    imageUrl: HallaqImages.goldBarberPoleIllustration(variant: '01'),
                    fallbackUrl: HallaqImages.goldBarberPoleIllustration(variant: '02'),
                    title: rtl ? 'إعادة تعيين كلمة المرور' : 'Reset Password',
                    subtitle: rtl ? 'اختر كلمة مرور جديدة وآمنة.' : 'Set a new secure password to continue.',
                    height: 210,
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
                      child: Column(
                        children: [
                          LuxuryTextField(
                            controller: _password,
                            label: l10n.newPassword,
                            obscureText: true,
                            allowObscureToggle: true,
                            enabled: !_busy,
                            validator: (v) => _validatePassword(l10n, v),
                            autofillHints: const [AutofillHints.newPassword],
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                          const SizedBox(height: 12),
                          LuxuryTextField(
                            controller: _confirmPassword,
                            label: l10n.confirmPassword,
                            obscureText: true,
                            allowObscureToggle: true,
                            textInputAction: TextInputAction.done,
                            enabled: !_busy,
                            validator: (v) => _validateConfirmPassword(l10n, v),
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _busy ? null : _submit(),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                          const SizedBox(height: 14),
                          LuxuryButton(
                            label: l10n.updatePassword,
                            onPressed: _busy ? null : _submit,
                            isLoading: _busy,
                          ),
                        ],
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
