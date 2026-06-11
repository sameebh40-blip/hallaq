import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final score = _score(password);
    final label = switch (score) {
      0 => isAr ? 'ضعيف' : 'Weak',
      1 => isAr ? 'متوسط' : 'Fair',
      2 => isAr ? 'جيد' : 'Good',
      _ => isAr ? 'قوي' : 'Strong',
    };
    final color = switch (score) {
      0 => const Color(0xFFFF453A),
      1 => const Color(0xFFFF9F0A),
      2 => const Color(0xFF34C759),
      _ => AppTheme.gold,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isAr ? 'قوة كلمة المرور' : 'Password strength',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            final filled = i <= score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 6,
                margin: EdgeInsetsDirectional.only(end: i == 3 ? 0 : 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: filled ? color.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.10),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  int _score(String p) {
    final v = p.trim();
    if (v.isEmpty) return 0;
    var s = 0;
    if (v.length >= 8) s += 1;
    if (v.length >= 12) s += 1;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) s += 1;
    if (RegExp(r'[0-9]').hasMatch(v) || RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s += 1;
    return s.clamp(0, 3);
  }
}

