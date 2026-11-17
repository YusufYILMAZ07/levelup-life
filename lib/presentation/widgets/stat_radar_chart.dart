import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/entities/stat_key.dart';

/// 5 statlık radar (örümcek) grafiği — onboarding özeti ve dashboard için.
///
/// Değerler 0-100 aralığındadır ([StatScale] radar değerleri). Grafik saf
/// `CustomPainter` ile çizilir; ek paket gerekmez ve her boyuta uyarlanır.
class StatRadarChart extends StatelessWidget {
  const StatRadarChart({
    required this.values,
    this.size = 240,
    this.accent = AppColors.primary,
    this.showLabels = true,
    this.onDark = false,
    super.key,
  });

  final Map<StatKey, double> values;
  final double size;
  final Color accent;
  final bool showLabels;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stat radar grafiği',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadarPainter(
            values: values,
            accent: accent,
            showLabels: showLabels,
            onDark: onDark,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.accent,
    required this.showLabels,
    required this.onDark,
  });

  final Map<StatKey, double> values;
  final Color accent;
  final bool showLabels;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius =
        math.min(size.width, size.height) / 2 - (showLabels ? 26 : 6);
    final List<StatKey> stats = StatKey.values;
    final int count = stats.length;
    final double step = (2 * math.pi) / count;

    Offset pointAt(int index, double distance) {
      final double angle = -math.pi / 2 + step * index;
      return center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
    }

    final Color outlineColor =
        onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.border;
    final Color axisColor =
        onDark ? Colors.white.withValues(alpha: 0.14) : AppColors.divider;
    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outlineColor;

    // Dış halka dolgusu (hafif zemin).
    final Path outerRing = _polygon(count, radius, pointAt);
    canvas.drawPath(
      outerRing,
      Paint()
        ..color = onDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.surfaceMuted,
    );
    canvas.drawPath(outerRing, gridPaint);

    // İç halkalar.
    for (final double fraction in <double>[0.33, 0.66]) {
      canvas.drawPath(_polygon(count, radius * fraction, pointAt), gridPaint);
    }

    // Eksenler.
    final Paint axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = axisColor;
    for (int i = 0; i < count; i++) {
      canvas.drawLine(center, pointAt(i, radius), axisPaint);
    }

    // Veri poligonu.
    final Path dataPath = Path();
    for (int i = 0; i < count; i++) {
      final double value =
          (values[stats[i]] ?? 0).clamp(0, 100).toDouble() / 100;
      final Offset point = pointAt(i, radius * value);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.32),
            accent.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );

    // Noktalar.
    for (int i = 0; i < count; i++) {
      final double value =
          (values[stats[i]] ?? 0).clamp(0, 100).toDouble() / 100;
      final Offset point = pointAt(i, radius * value);
      canvas.drawCircle(point, 5, Paint()..color = stats[i].color);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = onDark ? AppColors.textPrimary : AppColors.surface,
      );
    }

    if (!showLabels) return;

    // Stat kodları.
    for (int i = 0; i < count; i++) {
      final Offset anchor = pointAt(i, radius + 16);
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: stats[i].code,
          style: AppTypography.caption.copyWith(
            color: onDark ? Colors.white70 : AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  Path _polygon(int count, double radius, Offset Function(int, double) pointAt) {
    final Path path = Path();
    for (int i = 0; i < count; i++) {
      final Offset point = pointAt(i, radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.accent != accent ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.onDark != onDark;
}
