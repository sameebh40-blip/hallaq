import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_controller.dart';

class LanguageSwitcher extends ConsumerWidget {
  final bool compact;

  const LanguageSwitcher({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider) ?? Localizations.localeOf(context);
    final isAr = locale.languageCode == 'ar';

    return Container(
      height: compact ? 32 : 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            selected: !isAr,
            label: 'English',
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('en')),
          ),
          _Chip(
            selected: isAr,
            label: 'العربية',
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('ar')),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _Chip({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? const Color(0xFFD4AF37).withValues(alpha: 0.92) : Colors.transparent,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.black : Colors.white.withValues(alpha: 0.90),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.15,
              ),
        ),
      ),
    );
  }
}

