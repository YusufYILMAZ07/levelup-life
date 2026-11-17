import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/services.dart';
import '../../widgets/xp_bar.dart';

/// Dashboard'un tepe kartı: seviye, unvan ve **parlayan** ana XP barı.
class LevelHeroCard extends StatelessWidget {
  const LevelHeroCard({required this.profile, this.onEnergyTap, super.key});

  final UserProfile profile;
  final VoidCallback? onEnergyTap;

  @override
  Widget build(BuildContext context) {
    final LevelProgress level = profile.level;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppTheme.heroPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SEVİYE ${level.level} · ${level.tier.label.toUpperCase()}',
                      style: AppTypography.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.titleLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${profile.firstName} · ${profile.archetype.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      level.tier.icon,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level.level}',
                      style: AppTypography.numericLarge.copyWith(
                        color: AppColors.textOnAccent,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          XpSummaryLabels(
            current: level.xpIntoLevel,
            total: level.xpForNextLevel,
            onDark: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          XpBar(
            value: level.fraction,
            height: 18,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFFBEB), Color(0xFFFDE68A)],
            ),
            glowColor: Colors.white,
            trackColor: Colors.white.withValues(alpha: 0.22),
            trackBorderColor: Colors.white.withValues(alpha: 0.30),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${FormatX.number(level.xpRemaining)} XP sonra seviye ${level.level + 1}',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _HeroChip(
                icon: Icons.local_fire_department_rounded,
                label: '${profile.streak.currentDays} gün seri',
              ),
              _HeroChip(
                icon: profile.energyMode.icon,
                label: profile.energyMode.label,
                onTap: onEnergyTap,
              ),
              _HeroChip(
                icon: Icons.workspace_premium_rounded,
                label: profile.archetype.label,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.textOnAccent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
