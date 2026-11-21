import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';
import '../../domain/entities/entities.dart';
import 'section_header.dart';

/// Kişiselleştirilmiş görev kartı — rengi görevin statından gelir.
///
/// [xpReward] arketip bonusu dahil hesaplanmış ödüldür; tamamlanmış görev
/// soluklaşır ve "Tamamlandı" rozeti gösterir.
class QuestCard extends StatelessWidget {
  const QuestCard({
    required this.quest,
    required this.xpReward,
    required this.onComplete,
    this.bonusPercent = 0,
    super.key,
  });

  final Quest quest;
  final int xpReward;
  final VoidCallback onComplete;
  final int bonusPercent;

  @override
  Widget build(BuildContext context) {
    final Color color = quest.stat.color;
    final bool done = quest.isCompleted;

    return Opacity(
      opacity: done ? 0.78 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppTheme.statSurface(color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Medallion(
                  icon: quest.stat.icon,
                  gradient: quest.stat.gradient,
                  size: 46,
                  iconSize: 23,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          InfoPill(
                            label: quest.stat.code,
                            color: color,
                            dense: true,
                          ),
                          if (quest.isMicro)
                            const InfoPill(
                              label: 'Mikro mod',
                              color: AppColors.warning,
                              icon: Icons.battery_saver_rounded,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        quest.effectiveTitle,
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        quest.effectiveSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                InfoPill(
                  label: FormatX.duration(quest.effectiveMinutes),
                  icon: Icons.schedule_rounded,
                  color: AppColors.textSecondary,
                ),
                InfoPill(
                  label: quest.difficulty.label,
                  icon: Icons.speed_rounded,
                  color: color,
                ),
                InfoPill(
                  label: quest.category.label,
                  icon: Icons.sell_outlined,
                  color: AppColors.textTertiary,
                ),
                InfoPill(
                  label: quest.verification.summary,
                  icon: Icons.verified_user_outlined,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        done ? 'Kazanıldı' : 'Ödül',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: AppSpacing.xs,
                        children: <Widget>[
                          Text(
                            '+${FormatX.number(xpReward)} XP',
                            style: AppTypography.numericLarge.copyWith(
                              color: color,
                              fontSize: 22,
                            ),
                          ),
                          if (bonusPercent > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '%$bonusPercent bonus',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (done)
                  const InfoPill(
                    label: 'Tamamlandı',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  )
                else
                  _CompleteButton(color: color, onPressed: onComplete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color.lerp(color, Colors.white, 0.18)!, color],
          ),
          borderRadius: radius,
          boxShadow: AppShadows.glow(
            color,
            opacity: 0.30,
            blur: 14,
            offset: const Offset(0, 6),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Tamamla',
                  style: AppTypography.subtitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
