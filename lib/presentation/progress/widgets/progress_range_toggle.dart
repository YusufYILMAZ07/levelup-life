import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// İlerleme grafiğinin zaman aralığı.
enum ProgressRange {
  week(days: 7, label: '7 gün', caption: 'Son 7 gün'),
  month(days: 30, label: '30 gün', caption: 'Son 30 gün');

  const ProgressRange({
    required this.days,
    required this.label,
    required this.caption,
  });

  /// Grafikte gösterilecek gün sayısı.
  final int days;

  /// Segment üzerindeki kısa etiket.
  final String label;

  /// Kart başlığındaki açıklama.
  final String caption;
}

/// 7 gün ↔ 30 gün geçişi yapan kompakt segment kontrolü.
class ProgressRangeToggle extends StatelessWidget {
  const ProgressRangeToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ProgressRange value;
  final ValueChanged<ProgressRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ProgressRange range in ProgressRange.values)
            _RangeSegment(
              range: range,
              selected: range == value,
              onTap: () => onChanged(range),
            ),
        ],
      ),
    );
  }
}

class _RangeSegment extends StatelessWidget {
  const _RangeSegment({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final ProgressRange range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        key: Key('progress-range-${range.name}'),
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: AppRadii.pillAll,
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Text(
            range.label,
            style: AppTypography.caption.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
