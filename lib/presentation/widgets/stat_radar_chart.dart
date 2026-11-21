import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/entities/stat_key.dart';

/// 5 statlık radar (örümcek) grafiği — onboarding özeti, dashboard ve
/// Yusuf ↔ Ceyda karşılaştırması için.
///
/// Değerler 0-100 aralığındadır ([StatScale] radar değerleri). Grafik saf
/// `CustomPainter` ile çizilir; ek paket gerekmez ve her boyuta uyarlanır.
///
/// [secondaryValues] verilirse ikinci partnerin poligonu aynı ızgaranın
/// üzerine çizilir (Yusuf indigo, Ceyda gül kırmızısı). Etiketler
/// ([primaryLabel] / [secondaryLabel]) verildiğinde grafiğin altında küçük
/// bir açıklama (legend) satırı belirir.
class StatRadarChart extends StatelessWidget {
  const StatRadarChart({
    required this.values,
    this.secondaryValues,
    this.size = 240,
    this.accent = AppColors.primary,
    this.secondaryAccent = CouplePalette.ceyda,
    this.primaryLabel,
    this.secondaryLabel,
    this.showLabels = true,
    this.onDark = false,
    super.key,
  });

  final Map<StatKey, double> values;

  /// İkinci partnerin aynı günkü radar değerleri (opsiyonel).
  final Map<StatKey, double>? secondaryValues;

  final double size;
  final Color accent;
  final Color secondaryAccent;

  /// Legend satırındaki isimler (ör. `Yusuf`, `Ceyda`).
  final String? primaryLabel;
  final String? secondaryLabel;

  final bool showLabels;
  final bool onDark;

  bool get _hasLegend =>
      primaryLabel != null || secondaryLabel != null || secondaryValues != null;

  @override
  Widget build(BuildContext context) {
    final Widget chart = Semantics(
      label: secondaryValues == null
          ? 'Stat radar grafiği'
          : 'Karşılaştırmalı stat radar grafiği',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadarPainter(
            values: values,
            secondaryValues: secondaryValues,
            accent: accent,
            secondaryAccent: secondaryAccent,
            showLabels: showLabels,
            onDark: onDark,
          ),
        ),
      ),
    );

    if (!_hasLegend) return RepaintBoundary(child: chart);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            chart,
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                if (primaryLabel != null)
                  _RadarLegendItem(
                    label: primaryLabel!,
                    color: accent,
                    onDark: onDark,
                  ),
                if (secondaryValues != null && secondaryLabel != null)
                  _RadarLegendItem(
                    label: secondaryLabel!,
                    color: secondaryAccent,
                    onDark: onDark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarLegendItem extends StatelessWidget {
  const _RadarLegendItem({
    required this.label,
    required this.color,
    required this.onDark,
  });

  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs + 1),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: onDark ? Colors.white70 : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.accent,
    required this.secondaryAccent,
    required this.showLabels,
    required this.onDark,
    this.secondaryValues,
  });

  final Map<StatKey, double> values;
  final Map<StatKey, double>? secondaryValues;
  final Color accent;
  final Color secondaryAccent;
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

    final Color outlineColor = onDark
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.border;
    final Color axisColor = onDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.divider;
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

    // İkinci partnerin poligonu (varsa) önce çizilir; böylece aktif
    // partnerin çizgisi üstte kalır ve okunabilirlik korunur.
    if (secondaryValues != null) {
      _paintDataPolygon(
        canvas: canvas,
        stats: stats,
        pointAt: pointAt,
        radius: radius,
        data: secondaryValues!,
        color: secondaryAccent,
        fillAlpha: 0.08,
        strokeWidth: 1.6,
      );
    }

    // Veri poligonu.
    _paintDataPolygon(
      canvas: canvas,
      stats: stats,
      pointAt: pointAt,
      radius: radius,
      data: values,
      color: accent,
      fillAlpha: 0.30,
      strokeWidth: 2,
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

  void _paintDataPolygon({
    required Canvas canvas,
    required List<StatKey> stats,
    required Offset Function(int, double) pointAt,
    required double radius,
    required Map<StatKey, double> data,
    required Color color,
    required double fillAlpha,
    required double strokeWidth,
  }) {
    final Path path = Path();
    for (int i = 0; i < stats.length; i++) {
      final double value = (data[stats[i]] ?? 0).clamp(0, 100).toDouble() / 100;
      final Offset point = pointAt(i, radius * value);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: fillAlpha),
            color.withValues(alpha: fillAlpha * 0.25),
          ],
        ).createShader(Rect.fromLTWH(-radius, -radius, radius * 2, radius * 2)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  Path _polygon(
    int count,
    double radius,
    Offset Function(int, double) pointAt,
  ) {
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
      oldDelegate.secondaryValues != secondaryValues ||
      oldDelegate.accent != accent ||
      oldDelegate.secondaryAccent != secondaryAccent ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.onDark != onDark;
}
