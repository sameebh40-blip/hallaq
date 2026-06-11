import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuxuryLoader extends StatefulWidget {
  final double size;

  const LuxuryLoader({super.key, this.size = 34});

  @override
  State<LuxuryLoader> createState() => _LuxuryLoaderState();
}

class _LuxuryLoaderState extends State<LuxuryLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final a = (t * 6.283185307179586);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _GoldArcPainter(
              angle: a,
              color: AppTheme.gold,
            ),
          ),
        );
      },
    );
  }
}

class _GoldArcPainter extends CustomPainter {
  final double angle;
  final Color color;

  const _GoldArcPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE08A), AppTheme.gold, Color(0xFF8E6B1F)],
      ).createShader(rect);

    canvas.drawArc(rect.deflate(size.width * 0.12), angle, 1.9, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldArcPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color;
  }
}

