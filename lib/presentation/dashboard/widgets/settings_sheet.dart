import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../application/game_state.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../birthday/birthday_modal.dart';
import '../../onboarding/widgets/grade_selector.dart';
import '../../widgets/section_header.dart';

/// Profil / ayarlar bottom sheet'i.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Yeniden başlamak istiyor musun?'),
        content: const Text(
          'Tüm XP, seri ve görevler silinir; tanışma sihirbazı yeniden açılır. '
          'Bu işlem geri alınamaz.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Evet, sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(gameProvider.notifier).resetJourney();
  }

  Future<void> _confirmRestartCouple(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Çift sürümü yeniden başlasın mı?'),
        content: const Text(
          'Sohbet, rubrik puanları ve bucket list hazır içerikle yenilenir. '
          'Günlük ilerleme sıfırlanır.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yeniden başlat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(gameProvider.notifier).restartCoupleJourney();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final UserProfile? profile = state.profile;
    final UserSetup? setup = state.setup;
    if (profile == null || setup == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                InitialsAvatar(name: profile.displayName, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.displayName,
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${setup.trackLabel} · ${profile.titleLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                InfoPill(
                  label: 'Lv ${profile.levelNumber}',
                  color: AppColors.primary,
                  icon: Icons.military_tech_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            // __REST__
            const SectionHeader(
              title: 'Enerji modu',
              subtitle: 'Bugünkü kapasitene göre görevler uyarlanır.',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final EnergyMode mode in EnergyMode.values)
                  _EnergyOption(
                    mode: mode,
                    selected: profile.energyMode == mode,
                    onTap: () =>
                        ref.read(gameProvider.notifier).setEnergyMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.track_changes_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${setup.goals.length} hedef · '
                      'günde ${setup.dailyQuestTarget} görev · '
                      '${setup.tempo.minutes} dk tempo',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (state.isCoupleEdition) ...<Widget>[
              ListTile(
                key: const Key('settings-birthday'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.streak.withValues(alpha: 0.12),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: const Icon(
                    Icons.cake_rounded,
                    color: AppColors.streak,
                    size: 21,
                  ),
                ),
                title: Text(
                  'Doğum günü sürprizi',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Mektup, yılın özeti ve aşk notu üretici.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  showBirthdayExperience(context);
                },
              ),
              ListTile(
                key: const Key('settings-restart-couple'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Çift sürümünü yeniden başlat',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Hazır içerik ve tohum verisiyle temiz başlangıç.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: () => _confirmRestartCouple(context, ref),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: AppRadii.smAll,
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: AppColors.danger,
                  size: 21,
                ),
              ),
              title: Text(
                'Hedeflerimi sıfırla',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Tanışma ekranına dön, her şeyi yeniden tanımla.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
              onTap: () => _confirmReset(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyOption extends StatelessWidget {
  const _EnergyOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final EnergyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = mode.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 1,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(mode.icon, size: 15, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                mode.label,
                style: AppTypography.caption.copyWith(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
