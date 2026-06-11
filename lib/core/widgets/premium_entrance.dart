import 'package:flutter/material.dart';

class PremiumEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Offset from;

  const PremiumEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.from = const Offset(0, 0.04),
  });

  @override
  State<PremiumEntrance> createState() => _PremiumEntranceState();
}

class _PremiumEntranceState extends State<PremiumEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final CurvedAnimation _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      if (widget.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: widget.delayMs));
      }
      if (!mounted) return;
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.from, end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

