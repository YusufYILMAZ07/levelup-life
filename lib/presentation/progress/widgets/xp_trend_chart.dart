import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';
import 'progress_range_toggle.dart';

/// Günlük XP sütun grafiği.
///
/// Saf widget'tır: veriyi [series]'ten alır, hiçbir zaman kendi başına
/// `DateTime.now()` çağırmaz ([now] yalnızca testlerde enjekte edilir).
/// Bugünün sütunu koyu marka gradient'iyle vurgulanır.
class XpTrendChart extends StatelessWidget {
  const XpTrendChart({
    required this.series,
    required this.range,
    this.now,
    super.key,
  });

  final List<DailyXp> series;
  final ProgressRange range;
  final DateTime? now;

  /// Pazartesi → Pazar üç harfli kısa gün adları.
  static const List<String> _weekdays = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  String _labelFor(DailyXp point, int index) {
    if (range == ProgressRange.week) {
      return _weekdays[DateX.weekdayIndex(point.day)];
    }
    // 30 günde eksen seyreltilir: her 5 günde bir + son gün.
    return index % 5 == 0 || index == series.length - 1
        ? '${point.day.day}'
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final int maxXp = series.fold<int>(
      0,
      (int best, DailyXp point) => math.max(best, point.xp),
    );
    final int totalXp = series.fold<int>(
      0,
      (int sum, DailyXp point) => sum + point.xp,
    );
    final int averageXp = series.isEmpty
        ? 0
        : (totalXp / series.length).round();
    final DateTime today = DateX.today(now);
    final bool compact = series.length > 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'En yüksek gün ${FormatX.number(maxXp)} XP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Ortalama ${FormatX.number(averageXp)} XP',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 164,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < series.length; i++)
                Expanded(
                  child: _XpBarColumn(
                    point: series[i],
                    ratio: maxXp <= 0 ? 0 : series[i].xp / maxXp,
                    isToday: DateX.isSameDay(series[i].day, today),
                    label: _labelFor(series[i], i),
                    compact: compact,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _XpBarColumn extends StatelessWidget {
  const _XpBarColumn({
    required this.point,
    required this.ratio,
    required this.isToday,
    required this.label,
    required this.compact,
  });

  final DailyXp point;

  /// 0.0 → 1.0: günün XP'si / aralığın en yüksek günü.
  final double ratio;
  final bool isToday;
  final String label;

  /// 30 günlük görünümde çubuklar incelir, etiketler küçülür.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Aktif günler en az %10 yükseklik alır: "1 XP" de görünür kalır.
    final double fraction = point.isActive
        ? (0.10 + 0.90 * ratio.clamp(0.0, 1.0))
        : 0.03;

    return Semantics(
      label: '${FormatX.shortDate(point.day)}: ${point.xp} XP',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: !point.isActive
                          ? null
                          : (isToday
                                ? AppGradients.levelBar
                                : AppGradients.xpBar),
                      color: point.isActive ? null : AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(compact ? 3 : 6),
                      boxShadow: point.isActive
                          ? AppShadows.glow(
                              AppColors.primary,
                              opacity: 0.16,
                              blur: 10,
                              offset: const Offset(0, 4),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 14,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.clip,
                style: AppTypography.caption.copyWith(
                  fontSize: compact ? 9 : 11,
                  color: isToday ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
