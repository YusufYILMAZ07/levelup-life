import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Onboarding adımlarının ortak başlığı: üst etiket + başlık + açıklama.
class StepTitle extends StatelessWidget {
  const StepTitle({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.icon,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              eyebrow.toUpperCase(),
              style: AppTypography.label.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimary,
            fontSize: 26,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          description,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Hızlı seçim çipleri (bölüm / sektör / sınav alanı önerileri).
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.color = AppColors.primary,
    super.key,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String option in options)
          _SuggestionChip(
            label: option,
            selected: option == selected,
            color: color,
            onTap: () => onSelect(option),
          ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: selected ? color : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
