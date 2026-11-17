import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/section_header.dart';
import '../../widgets/xp_bar.dart';

/// Tek bir statın dashboard satırı: ikon, kuşak, XP ve gradient bar.
class StatProgressTile extends StatelessWidget {
  const StatProgressTile({required this.progress, super.key});

  final StatProgress progress;

  @override
  Widget build(BuildContext context) {
    final StatKey stat = progress.stat;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: stat.borderColor),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: <Widget>[
          Medallion(
            icon: stat.icon,
            gradient: stat.gradient,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${stat.label} · ${stat.arena}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InfoPill(
                      label: progress.rank.label,
                      color: stat.color,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                XpBar(
                  value: progress.rankProgress,
                  height: 12,
                  gradient: stat.barGradient,
                  glowColor: stat.color,
                  showShimmer: false,
                ),
                const SizedBox(height: AppSpacing.xs + 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${FormatX.number(progress.xp)} XP',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'radar ${progress.radarValue.round()} / 100',
                      style: AppTypography.caption.copyWith(
                        color: stat.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
