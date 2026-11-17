import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/choice_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import '../widgets/step_title.dart';

/// Adım 3 — çoklu hedef seçimi.
///
/// Seçimler anında arketip önerisini günceller; kullanıcı hangi sınıfa doğru
/// evrildiğini burada görür (şeffaflık = güven).
class StepGoals extends StatelessWidget {
  const StepGoals({
    required this.setup,
    required this.onToggle,
    super.key,
  });

  final UserSetup setup;
  final ValueChanged<GoalType> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        const StepTitle(
          eyebrow: 'Hedefler',
          title: 'Neyi geliştirmek istiyorsun?',
          description:
              'Birden fazla seçebilirsin. Görevlerin tamamen bu hedeflere göre üretilecek.',
          icon: Icons.flag_rounded,
        ),
        const SizedBox(height: AppSpacing.xxl),
        SectionHeader(
          title: 'Gelişim hedeflerin',
          subtitle: '${setup.goals.length} hedef seçildi',
          trailing: InfoPill(
            label: setup.hasGoals ? 'Hazır' : 'En az 1',
            color: setup.hasGoals ? AppColors.success : AppColors.textTertiary,
            icon: setup.hasGoals
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            dense: true,
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = AppSpacing.md;
            final double tileWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final GoalType goal in GoalType.values)
                  SizedBox(
                    width: tileWidth,
                    child: GoalTile(
                      key: ValueKey<String>('goal-${goal.code}'),
                      title: goal.label,
                      subtitle: goal.tagline,
                      icon: goal.icon,
                      color: goal.color,
                      selected: setup.goals.contains(goal),
                      onTap: () => onToggle(goal),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
        SoftCard(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderColor: AppColors.primary.withValues(alpha: 0.18),
          child: Row(
            children: <Widget>[
              Medallion(
                icon: setup.archetype == Archetype.polymath
                    ? Icons.auto_awesome_rounded
                    : Icons.workspace_premium_rounded,
                gradient: AppGradients.primary,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Önerilen sınıf: ${setup.archetype.title}',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      setup.archetype.tagline,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
