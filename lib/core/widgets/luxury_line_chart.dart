import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuxuryLineChart extends StatelessWidget {
  final List<double> values;
  final double height;

  const LuxuryLineChart({
    super.key,
    required this.values,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LuxuryLineChartPainter(values: values),
      ),
    );
  }
}

class _LuxuryLineChartPainter extends CustomPainter {
  final List<double> values;

  const _LuxuryLineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.000001 ? 1.0 : (maxV - minV);

    final pad = 10.0;
    final w = (size.width - pad * 2).clamp(1, double.infinity);
    final h = (size.height - pad * 2).clamp(1, double.infinity);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final x = pad + w * t;
      final v = (values[i] - minV) / span;
      final y = pad + h * (1 - v);
      points.add(Offset(x, y));
    }

    final gridPaint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.65)
      ..strokeWidth = 1;

    final rows = 3;
    for (var i = 0; i <= rows; i++) {
      final y = pad + h * (i / rows);
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), gridPaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [AppTheme.goldSoft, AppTheme.gold, AppTheme.goldDeep],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final c1 = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final c2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    }

    final areaPath = Path.from(path)
      ..lineTo(points.last.dx, size.height - pad)
      ..lineTo(points.first.dx, size.height - pad)
      ..close();

    final areaPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          AppTheme.gold.withValues(alpha: 0.18),
          AppTheme.gold.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = AppTheme.gold;
    for (final p in points) {
      canvas.drawCircle(p, 3.0, dotPaint);
      canvas.drawCircle(p, 6.0, Paint()..color = AppTheme.gold.withValues(alpha: 0.10));
    }
  }

  @override
  bool shouldRepaint(covariant _LuxuryLineChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

