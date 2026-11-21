import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'section_header.dart';

/// Tek seçimli, ikonlu ve seçildiğinde renklenen kart (rol, tempo, yoğunluk).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.color = AppColors.primary,
    this.gradient,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final Gradient? gradient;
  final bool selected;
  final VoidCallback onTap;

  /// Sağ üstte küçük bir etiket (ör. "Önerilen").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? AppShadows.selected(color) : AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Medallion(
                      icon: icon!,
                      gradient:
                          gradient ??
                          LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color.lerp(color, Colors.white, 0.22)!,
                              color,
                            ],
                          ),
                      size: 42,
                      iconSize: 21,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (badge != null)
                              InfoPill(
                                label: badge!,
                                color: AppColors.primary,
                                dense: true,
                              ),
                          ],
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SelectionDot(selected: selected, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Çok seçimli hedef kartı (2 kolon grid).
class GoalTile extends StatelessWidget {
  const GoalTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.07) : AppColors.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? AppShadows.selected(color) : AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Medallion(
                        icon: icon,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color.lerp(color, Colors.white, 0.22)!,
                            color,
                          ],
                        ),
                        size: 38,
                        iconSize: 19,
                      ),
                      _SelectionDot(selected: selected, color: color),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : AppColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
