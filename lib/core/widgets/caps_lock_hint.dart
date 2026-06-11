import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class CapsLockHint extends StatefulWidget {
  const CapsLockHint({super.key});

  @override
  State<CapsLockHint> createState() => _CapsLockHintState();
}

class _CapsLockHintState extends State<CapsLockHint> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _sync();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _sync();
    return false;
  }

  void _sync() {
    final next = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.capsLock);
    if (next == _on) return;
    if (!mounted) return;
    setState(() => _on = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) return const SizedBox.shrink();
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.gold.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.keyboard_capslock_rounded, size: 18, color: AppTheme.gold),
          const SizedBox(width: 8),
          Text(
            isAr ? 'Caps Lock مُفعّل' : 'Caps Lock is on',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
