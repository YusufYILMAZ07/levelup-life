import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';

/// İlerleme sekmesinin tepe kartı: güncel seri, rekor ve dondurma hakkı.
///
/// Turuncu gradient seri rengini taşır; [activeToday] false ise alt satır
/// kullanıcıyı bugünün görevine davet eder.
class StreakHeroCard extends StatelessWidget {
  const StreakHeroCard({
    required this.streak,
    required this.activeToday,
    super.key,
  });

  final Streak streak;
  final bool activeToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppTheme.heroPanel(gradient: AppGradients.streak),
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
                      'GÜNLÜK SERİ',
                      style: AppTypography.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${streak.currentDays} gün',
                      style: AppTypography.numericHero.copyWith(
                        color: AppColors.textOnAccent,
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      activeToday
                          ? 'Bugünü tamamladın, seri güvende.'
                          : 'Bugün bir görev tamamla, seri +1.',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const _FlameBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroMetric(
                  icon: Icons.emoji_events_rounded,
                  value: '${streak.longestDays}',
                  label: 'Rekor gün',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.bolt_rounded,
                  value: '${streak.totalActiveDays}',
                  label: 'Aktif gün',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.ac_unit_rounded,
                  value: '${streak.freezeTokens}',
                  label: 'Dondurma',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlameBadge extends StatelessWidget {
  const _FlameBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: const Icon(
        Icons.local_fire_department_rounded,
        color: AppColors.textOnAccent,
        size: 30,
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadii.smAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numeric.copyWith(
              color: AppColors.textOnAccent,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}
