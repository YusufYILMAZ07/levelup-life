import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/choice_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/stat_radar_chart.dart';
import '../widgets/grade_selector.dart';
import '../widgets/step_title.dart';

/// Adım 4 — günlük tempo + karakter özeti (RPG kartı, radar, arketip).
class StepSummary extends StatelessWidget {
  const StepSummary({
    required this.setup,
    required this.onTempoChanged,
    super.key,
  });

  final UserSetup setup;
  final ValueChanged<DailyTempo> onTempoChanged;

  IconData _tempoIcon(DailyTempo tempo) => switch (tempo) {
    DailyTempo.relaxed => Icons.spa_rounded,
    DailyTempo.balanced => Icons.balance_rounded,
    DailyTempo.hardcore => Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final UserProfile preview = setup.toProfile();
    final Archetype archetype = setup.archetype;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        const StepTitle(
          eyebrow: 'Son adım',
          title: 'Karakterin hazır!',
          description:
              'Günlük temponu seç; karakter kartın ve ilk görevlerin buna göre hazırlanacak.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: 'Günlük tempo',
          subtitle: 'Kişisel gelişime ayırabileceğin süre',
        ),
        for (final DailyTempo tempo in DailyTempo.values) ...<Widget>[
          ChoiceCard(
            key: ValueKey<String>('tempo-${tempo.code}'),
            title: '${tempo.label} · ${tempo.minutes} dk',
            subtitle: tempo.description,
            icon: _tempoIcon(tempo),
            color: AppColors.primary,
            selected: setup.tempo == tempo,
            badge: tempo == DailyTempo.balanced ? 'Dengeli' : null,
            onTap: () => onTempoChanged(tempo),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        SoftCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          shadows: AppShadows.floating,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  InitialsAvatar(name: preview.displayName, size: 58),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preview.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          setup.trackLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InfoPill(
                    label: 'Lv ${preview.levelNumber}',
                    color: AppColors.primary,
                    icon: Icons.military_tech_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  const Medallion(
                    icon: Icons.workspace_premium_rounded,
                    gradient: AppGradients.primary,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${archetype.title} · ${archetype.label}',
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          archetype.tagline,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: StatRadarChart(values: setup.startingRadar, size: 236),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  'Başlangıç eğilimin (hedef ağırlıkları)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final MapEntry<StatKey, double> entry
                      in archetype.statBonuses.entries)
                    InfoPill(
                      label:
                          '${entry.key.code} +%${(entry.value * 100).round()}',
                      color: entry.key.color,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Günde ${setup.dailyQuestTarget} görev · '
                        '${setup.tempo.minutes} dk hedef · '
                        '${setup.goals.length} aktif hedef',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
