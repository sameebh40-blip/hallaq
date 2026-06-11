import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class SocialAuthRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  const SocialAuthRow({
    super.key,
    required this.enabled,
    this.onGoogle,
    this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.10), height: 1)),
            const SizedBox(width: 10),
            Text(
              l10n.orContinueWith,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.10), height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: l10n.google,
                icon: Icons.g_mobiledata_rounded,
                enabled: enabled && onGoogle != null,
                showSoon: !enabled,
                onTap: onGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: l10n.apple,
                icon: Icons.apple,
                enabled: enabled && onApple != null,
                showSoon: !enabled,
                onTap: onApple,
              ),
            ),
          ],
        ),
        if (!enabled) ...[
          const SizedBox(height: 10),
          Text(
            isAr ? 'قريباً: تسجيل سريع وآمن' : 'Coming soon: fast, secure sign-in',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool showSoon;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.showSoon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.62,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0F0F0F).withValues(alpha: 0.62),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: enabled ? 0.08 : 0.04),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              if (showSoon)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppTheme.gold.withValues(alpha: 0.14),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      'Soon',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

