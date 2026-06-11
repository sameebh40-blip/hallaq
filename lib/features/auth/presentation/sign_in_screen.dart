import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/haptics/hallaq_haptics.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/routing/routes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_preflight.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/caps_lock_hint.dart';
import '../../../core/models/role.dart';
import '../../../core/config/env_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _rememberMe = true;
  bool _entered = false;
  bool _obscure = true;
  bool _loginHover = false;
  String? _errorText;

  static const _rememberEmailKey = 'auth.remembered_email';

  String? _validateIdentifier(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Required';
    if (v.contains('@')) {
      if (!v.contains('.')) return 'Invalid email';
      return null;
    }
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Invalid phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Required';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
    });
  }

  Future<void> _loadRememberedEmail() async {
    final store = ref.read(kvStoreProvider);
    final value = await store.read(_rememberEmailKey);
    if (!mounted) return;
    if (value != null && value.trim().isNotEmpty) {
      setState(() {
        _identifier.text = value.trim();
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

  Future<void> _signInWithFacebook() async {
    try {
      await ref.read(authRepositoryProvider).signInWithFacebook();
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message.isEmpty ? const AppException('Coming soon') : e);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
    }
  }

  Future<void> _submit() async {
    if (kDebugMode) {
      final env = ref.read(envLoadResultProvider);
      debugPrint(
        '[SignIn] submit tapped isConfigured=${ref.read(authRepositoryProvider).isConfigured} envSource=${env.source} urlLen=${env.urlLength} keyLen=${env.anonKeyLength}',
      );
    }
    if (!ref.read(authRepositoryProvider).isConfigured) {
      final env = ref.read(envLoadResultProvider);
      final msg = !env.hasUrl
          ? 'Preflight failed: SUPABASE_URL missing'
          : !env.hasAnonKey
              ? 'Preflight failed: SUPABASE_ANON_KEY missing'
              : 'Preflight failed: Supabase config invalid';
      showErrorSnackBar(
        context,
        AppException(
          msg,
          cause: 'source=${env.source} urlPresent=${env.hasUrl} keyPresent=${env.hasAnonKey} urlLength=${env.urlLength} keyLength=${env.anonKeyLength}',
        ),
      );
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final env = ref.read(envLoadResultProvider);
      final client = ref.read(supabaseClientProvider);
      final preflight = await SupabasePreflight.run(env: env, client: client);
      preflight.debugPrintReport(env: env);
      if (!preflight.supabaseInitialized) {
        throw const AppException('Preflight failed: Supabase not initialized');
      }
      if (!preflight.internet.ok) {
        throw AppException(
          'Preflight failed: Internet check',
          cause: preflight.internet.error,
        );
      }
      final identifier = _identifier.text.trim();
      await ref.read(authRepositoryProvider).signInWithEmailOrPhone(
            identifier: identifier,
            password: _password.text,
          );
      await ref.read(profileRepositoryProvider).ensureMyProfile();
      final gate = await ref.read(profileRepositoryProvider).getMyGateInfoFresh();
      final role = gate.role;
      final dest = switch (role) {
        AppUserRole.unknown => Routes.completeProfile,
        AppUserRole.customer => '/home',
        AppUserRole.barber => Routes.barberDashboardHome,
        AppUserRole.shopOwner => Routes.shopDashboardHome,
        AppUserRole.admin => Routes.adminHome,
      };
      final store = ref.read(kvStoreProvider);
      if (_rememberMe) {
        await store.write(_rememberEmailKey, identifier);
      } else {
        await store.delete(_rememberEmailKey);
      }
      HallaqHaptics.success();
      if (!mounted) return;
      context.go(dest);
    } on AppException catch (e, st) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[SignIn] AppException: ${e.message}');
        debugPrint('[SignIn] cause: ${e.cause}');
        debugPrint('$st');
      }
      HallaqHaptics.error();
      setState(() => _errorText = e.message.trim().isEmpty ? 'Try again.' : e.message.trim());
    } catch (e, st) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[SignIn] Unhandled error: $e');
        debugPrint('$st');
      }
      HallaqHaptics.error();
      setState(() => _errorText = userFacingMessage(context, e).trim().isEmpty ? 'Try again.' : userFacingMessage(context, e).trim());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.onyx, AppTheme.onyx2],
                ),
              ),
              child: CustomPaint(painter: _GoldWavesPainter()),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth * 0.90).clamp(0, 420).toDouble();
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: w,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      offset: _entered ? Offset.zero : const Offset(0, 0.02),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        opacity: _entered ? 1 : 0,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 22, 0, 28),
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 560),
                              curve: Curves.easeOutCubic,
                              opacity: _entered ? 1 : 0,
                              child: Center(
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 22,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: SvgPicture.asset('assets/brand/hallaq_logo_calendar.svg'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Text(
                                'HALLAQ',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: AppTheme.text,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 8,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 18, height: 1, color: AppTheme.gold.withValues(alpha: 0.60)),
                                  const SizedBox(width: 10),
                                  Text(
                                    'BOOK. STYLE. SHINE.',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.gold,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(width: 18, height: 1, color: AppTheme.gold.withValues(alpha: 0.60)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppTheme.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Login to your account to continue',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FieldLabel(label: 'Email or Phone'),
                                    const SizedBox(height: 8),
                                    _OutlinedField(
                                      controller: _identifier,
                                      focusNode: _identifierFocus,
                                      enabled: !_busy,
                                      hintText: 'Enter your email or phone number',
                                      prefix: const Icon(Icons.person_outline_rounded),
                                      validator: _validateIdentifier,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 14),
                                    _FieldLabel(label: 'Password'),
                                    const SizedBox(height: 8),
                                    _OutlinedField(
                                      controller: _password,
                                      focusNode: _passwordFocus,
                                      enabled: !_busy,
                                      hintText: 'Enter your password',
                                      prefix: const Icon(Icons.lock_outline_rounded),
                                      validator: _validatePassword,
                                      keyboardType: TextInputType.visiblePassword,
                                      autofillHints: const [AutofillHints.password],
                                      obscureText: _obscure,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _busy ? null : _submit(),
                                      suffix: IconButton(
                                        onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Align(alignment: AlignmentDirectional.centerStart, child: CapsLockHint()),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final compact = constraints.maxWidth < 360;
                                        final remember = Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _RememberMe(
                                              value: _rememberMe,
                                              enabled: !_busy,
                                              onChanged: (v) {
                                                HallaqHaptics.selection();
                                                setState(() => _rememberMe = v);
                                              },
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                'Remember me',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: AppTheme.text,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        );

                                        final forgot = TextButton(
                                          onPressed: _busy ? null : () => context.go('/auth/forgot-password'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.gold,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(10, 10),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Forgot password?',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: AppTheme.gold,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        );

                                        if (compact) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              remember,
                                              const SizedBox(height: 8),
                                              Align(alignment: Alignment.centerRight, child: forgot),
                                            ],
                                          );
                                        }

                                        return Row(
                                          children: [
                                            Expanded(child: remember),
                                            const SizedBox(width: 10),
                                            forgot,
                                          ],
                                        );
                                      },
                                    ),
                                    if (_errorText != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.28)),
                                        ),
                                        child: Text(
                                          _errorText!,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: AppTheme.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    MouseRegion(
                                      onEnter: (_) => setState(() => _loginHover = true),
                                      onExit: (_) => setState(() => _loginHover = false),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        curve: Curves.easeOut,
                                        transform: Matrix4.translationValues(0, _loginHover && !_busy ? -1.5 : 0, 0),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.goldGradient,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.gold.withValues(alpha: _loginHover && !_busy ? 0.35 : 0.22),
                                              blurRadius: 26,
                                              offset: const Offset(0, 14),
                                            ),
                                          ],
                                        ),
                                        child: InkWell(
                                          onTap: _busy ? null : _submit,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                          child: SizedBox(
                                            height: 54,
                                            child: Center(
                                              child: _busy
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                    )
                                                  : Text(
                                                      'Login',
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _SocialDivider(),
                                    const SizedBox(height: 14),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final compact = constraints.maxWidth < 360;
                                        if (!compact) {
                                          return _SocialButtons(
                                            enabled: !_busy && ref.read(authRepositoryProvider).isConfigured,
                                            onGoogle: _signInWithGoogle,
                                            onApple: _signInWithApple,
                                            onFacebook: _signInWithFacebook,
                                          );
                                        }
                                        return Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            SizedBox(
                                              width: (constraints.maxWidth - 12) / 2,
                                              child: _SocialButton(
                                                enabled: !_busy && ref.read(authRepositoryProvider).isConfigured,
                                                label: 'Google',
                                                asset: 'assets/brand/icon_google.svg',
                                                onTap: _signInWithGoogle,
                                              ),
                                            ),
                                            SizedBox(
                                              width: (constraints.maxWidth - 12) / 2,
                                              child: _SocialButton(
                                                enabled: !_busy && ref.read(authRepositoryProvider).isConfigured,
                                                label: 'Apple',
                                                asset: 'assets/brand/icon_apple.svg',
                                                onTap: _signInWithApple,
                                              ),
                                            ),
                                            SizedBox(
                                              width: constraints.maxWidth,
                                              child: _SocialButton(
                                                enabled: !_busy && ref.read(authRepositoryProvider).isConfigured,
                                                label: 'Facebook',
                                                asset: 'assets/brand/icon_facebook.svg',
                                                onTap: _signInWithFacebook,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final compact = constraints.maxWidth < 360;
                                        final itemW = compact ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 20) / 3;
                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            SizedBox(width: itemW, child: const _FeatureCard(icon: Icons.shield_outlined, label: 'Secure & Safe')),
                                            SizedBox(width: itemW, child: const _FeatureCard(icon: Icons.verified_outlined, label: 'Trusted by Thousands')),
                                            SizedBox(width: itemW, child: const _FeatureCard(icon: Icons.headset_mic_outlined, label: '24/7 Support')),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account?",
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: AppTheme.textMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _busy ? null : () => context.go('/auth/sign-up'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.gold,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(10, 10),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Sign up',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: AppTheme.gold,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.gold),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _OutlinedField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hintText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _OutlinedField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.prefix,
    required this.validator,
    required this.keyboardType,
    required this.autofillHints,
    required this.textInputAction,
    required this.onSubmitted,
    this.suffix,
    this.obscureText = false,
  });

  @override
  State<_OutlinedField> createState() => _OutlinedFieldState();
}

class _OutlinedFieldState extends State<_OutlinedField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _OutlinedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppTheme.onyx3,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: focused ? AppTheme.gold.withValues(alpha: 0.75) : AppTheme.border,
          width: 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : AppTheme.softShadow(opacity: 0.06),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        obscureText: widget.obscureText,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.text,
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          prefixIcon: widget.prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                  child: IconTheme(
                    data: IconThemeData(color: focused ? AppTheme.gold : AppTheme.textMuted),
                    child: widget.prefix!,
                  ),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.suffix,
        ),
      ),
    );
  }
}

class _RememberMe extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _RememberMe({required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bg = value ? AppTheme.gold : Colors.white;
    final border = value ? Colors.transparent : AppTheme.border;
    final checkColor = value ? Colors.white : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: enabled ? bg : bg.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
          boxShadow: value ? AppTheme.goldGlow(opacity: 0.16, blur: 16, y: 8) : [],
        ),
        child: Center(
          child: Icon(Icons.check_rounded, size: 16, color: checkColor),
        ),
      ),
    );
  }
}

class _SocialDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.border, height: 1)),
        const SizedBox(width: 10),
        Text(
          'or continue with',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppTheme.border, height: 1)),
      ],
    );
  }
}

class _SocialButtons extends StatelessWidget {
  final bool enabled;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onFacebook;

  const _SocialButtons({
    required this.enabled,
    required this.onGoogle,
    required this.onApple,
    required this.onFacebook,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            enabled: enabled,
            label: 'Google',
            asset: 'assets/brand/icon_google.svg',
            onTap: onGoogle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            enabled: enabled,
            label: 'Apple',
            asset: 'assets/brand/icon_apple.svg',
            onTap: onApple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            enabled: enabled,
            label: 'Facebook',
            asset: 'assets/brand/icon_facebook.svg',
            onTap: onFacebook,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  final bool enabled;
  final String label;
  final String asset;
  final VoidCallback onTap;

  const _SocialButton({required this.enabled, required this.label, required this.asset, required this.onTap});

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hover = false;
  late final Future<String?> _svgText = _loadSvg();

  Future<String?> _loadSvg() async {
    try {
      return await rootBundle.loadString(widget.asset);
    } catch (_) {
      return null;
    }
  }

  IconData _fallbackIcon() {
    final lower = widget.label.toLowerCase();
    if (lower.contains('google')) return Icons.g_mobiledata_rounded;
    if (lower.contains('apple')) return Icons.apple;
    if (lower.contains('facebook')) return Icons.facebook;
    return Icons.login_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover && enabled ? -1.0 : 0, 0),
          decoration: BoxDecoration(
            color: AppTheme.onyx3,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow(opacity: _hover && enabled ? 0.10 : 0.07),
          ),
          child: InkWell(
            onTap: enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: SizedBox(
              height: 54,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<String?>(
                      future: _svgText,
                      builder: (context, snapshot) {
                        final svg = snapshot.data;
                        if (svg == null || svg.trim().isEmpty) {
                          return Icon(_fallbackIcon(), size: 22, color: AppTheme.text);
                        }
                        return SvgPicture.string(svg, width: 22, height: 22);
                      },
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.onyx3,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.06),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.gold, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _GoldWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.gold.withValues(alpha: 0.20);

    final right = Path()
      ..moveTo(size.width * 0.45, size.height * 0.08)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.00, size.width * 1.08, size.height * 0.12);
    final right2 = Path()
      ..moveTo(size.width * 0.44, size.height * 0.11)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.02, size.width * 1.10, size.height * 0.16);
    final right3 = Path()
      ..moveTo(size.width * 0.42, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.74, size.height * 0.06, size.width * 1.10, size.height * 0.20);

    final left = Path()
      ..moveTo(size.width * -0.10, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.02, size.width * 0.56, size.height * 0.10);
    final left2 = Path()
      ..moveTo(size.width * -0.12, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.06, size.width * 0.56, size.height * 0.14);

    canvas.drawPath(right, paint);
    canvas.drawPath(right2, paint..color = AppTheme.gold.withValues(alpha: 0.16));
    canvas.drawPath(right3, paint..color = AppTheme.gold.withValues(alpha: 0.12));
    canvas.drawPath(left, paint..color = AppTheme.gold.withValues(alpha: 0.14));
    canvas.drawPath(left2, paint..color = AppTheme.gold.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
