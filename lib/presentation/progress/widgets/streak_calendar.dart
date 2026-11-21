import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';

/// Son [weeks] haftanın günlük aktivite ısı haritası.
///
/// Koyuluk, günün XP'sinin aralığın en yüksek gününe oranıdır; bugün ayrıca
/// halka ile işaretlenir. Gelecekteki günler boş bırakılır.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    required this.log,
    this.weeks = 5,
    this.now,
    super.key,
  });

  final DailyXpLog log;
  final int weeks;
  final DateTime? now;

  static const List<String> _weekdays = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateX.today(now);
    final DateTime weekStart = DateX.shiftDays(
      today,
      -DateX.weekdayIndex(today),
    );
    final DateTime gridStart = DateX.shiftDays(weekStart, -(weeks - 1) * 7);
    final int maxXp = log.byDay.values.fold<int>(
      0,
      (int best, int xp) => math.max(best, xp),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String label in _weekdays)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (int week = 0; week < weeks; week++) ...<Widget>[
          if (week > 0) const SizedBox(height: AppSpacing.xs + 2),
          Row(
            children: <Widget>[
              for (int day = 0; day < 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _buildCell(
                        day: DateX.shiftDays(gridStart, week * 7 + day),
                        today: today,
                        maxXp: maxXp,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const <Widget>[
            _LegendSwatch(label: 'Aktif gün', color: AppColors.primary),
            _LegendSwatch(
              label: 'Boş gün',
              color: AppColors.surfaceSunken,
              bordered: true,
            ),
            _LegendSwatch(label: 'Bugün', color: AppColors.surface, ring: true),
          ],
        ),
      ],
    );
  }

  Widget _buildCell({
    required DateTime day,
    required DateTime today,
    required int maxXp,
  }) {
    return _DayCell(
      key: ValueKey<String>('streak-cell-${DateX.isoDay(day)}'),
      day: day,
      xp: log.xpOn(day),
      maxXp: maxXp,
      isToday: DateX.isSameDay(day, today),
      isFuture: day.isAfter(today),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.xp,
    required this.maxXp,
    required this.isToday,
    required this.isFuture,
    super.key,
  });

  final DateTime day;
  final int xp;
  final int maxXp;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppRadii.sm - 2);
    if (isFuture) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: radius,
        ),
      );
    }

    final bool active = xp > 0;
    final double strength = maxXp <= 0 ? 0 : (xp / maxXp).clamp(0.0, 1.0);
    final Color fill = active
        ? Color.lerp(
            AppColors.primary.withValues(alpha: 0.32),
            AppColors.primary,
            strength,
          )!
        : AppColors.surfaceSunken;

    return Semantics(
      label: '${FormatX.shortDate(day)}: ${active ? '$xp XP' : 'görev yok'}',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: isToday
              ? Border.all(color: AppColors.primaryDeep, width: 1.8)
              : (active ? null : Border.all(color: AppColors.border)),
          boxShadow: active
              ? AppShadows.glow(
                  AppColors.primary,
                  opacity: 0.16,
                  blur: 8,
                  offset: const Offset(0, 3),
                )
              : null,
        ),
        child: Text(
          '${day.day}',
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: active ? AppColors.textOnAccent : AppColors.textTertiary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({
    required this.label,
    required this.color,
    this.bordered = false,
    this.ring = false,
  });

  final String label;
  final Color color;
  final bool bordered;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: ring
                ? Border.all(color: AppColors.primaryDeep, width: 1.8)
                : (bordered ? Border.all(color: AppColors.border) : null),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 1),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
