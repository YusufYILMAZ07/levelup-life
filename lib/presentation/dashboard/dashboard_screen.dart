import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';
import '../../domain/entities/entities.dart';
import '../widgets/couple_top_bar.dart';
import '../widgets/quest_card.dart';
import '../widgets/quest_verification_dialog.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_card.dart';
import '../widgets/stat_radar_chart.dart';
import 'widgets/add_quest_sheet.dart';
import 'widgets/birthday_banner.dart';
import 'widgets/level_hero_card.dart';
import 'widgets/live_couple_now_card.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/stat_progress_tile.dart';

/// Ana sayfa (Dashboard).
///
/// Tüm içerik onboarding cevaplarından türetilir: profil, radar, statlar ve
/// görev listesi. Sağ üstteki ayarlar butonu profil sheet'ini açar; oradan
/// enerji modu değiştirilebilir veya hedefler sıfırlanıp onboarding'e dönülür.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _completeQuest(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
  ) async {
    final bool verified = await showQuestVerificationDialog(context, quest);
    if (!verified || !context.mounted) return;
    final XpAward? award = ref
        .read(gameProvider.notifier)
        .completeQuest(quest.id);
    if (award == null || !context.mounted) return;
    final String message = award.leveledUp
        ? 'Seviye atladın! Lv ${award.after.level} · +${award.xpGained} XP'
        : '+${award.xpGained} XP · ${quest.stat.code} güçlendi';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final UserProfile? profile = state.profile;
    final UserSetup? setup = state.setup;
    if (profile == null || setup == null) return const SizedBox.shrink();

    final Map<StatKey, double> radar = <StatKey, double>{
      for (final StatKey stat in StatKey.values)
        stat: profile.rpgStats[stat].radarValue,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const Positioned(top: -150, right: -110, child: _AuraBlob()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConstants.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                    AppSpacing.huge,
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${FormatX.greeting(DateTime.now())}, '
                                '${profile.firstName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headline.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${setup.role.label} · ${setup.trackLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CircleButton(
                          key: const Key('settings-button'),
                          icon: Icons.tune_rounded,
                          tooltip: 'Profil ve ayarlar',
                          onTap: () => showSettingsSheet(context),
                        ),
                      ],
                    ),
                    if (state.isCoupleEdition) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      const CoupleTopBar(),
                      const SizedBox(height: AppSpacing.md),
                      const LiveCoupleNowCard(),
                      const SizedBox(height: AppSpacing.sm),
                      const BirthdayBanner(),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    LevelHeroCard(
                      profile: profile,
                      onEnergyTap: () => showSettingsSheet(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.task_alt_rounded,
                            label: 'Bugün',
                            value:
                                '${state.completedCount}/${state.quests.length}',
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Seri',
                            value: '${profile.streak.currentDays} gün',
                            color: AppColors.streak,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.bolt_rounded,
                            label: 'Toplam XP',
                            value: FormatX.number(profile.totalXp),
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatsDisclosure(profile: profile, radar: radar),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Bugünün Görevleri',
                      subtitle:
                          '${state.openQuests.length} açık · '
                          '${state.completedCount} tamamlandı',
                      trailing: IconButton(
                        key: const Key('refresh-quests-button'),
                        tooltip: 'Görevleri yenile',
                        onPressed: () =>
                            ref.read(gameProvider.notifier).refreshQuests(),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    if (state.quests.isEmpty)
                      SoftCard(
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.inbox_rounded,
                              size: 32,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Bugün için görev yok. Yeni bir görev ekle.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final Quest quest in state.quests) ...<Widget>[
                        QuestCard(
                          key: ValueKey<String>('quest-${quest.id}'),
                          quest: quest,
                          xpReward: ref
                              .read(gameProvider.notifier)
                              .xpForQuest(profile, quest),
                          bonusPercent:
                              (profile.archetype.bonusFor(quest.stat) * 100)
                                  .round(),
                          onComplete: () => _completeQuest(context, ref, quest),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    const SizedBox(height: AppSpacing.sm),
                    _AddQuestButton(onTap: () => showAddQuestSheet(context)),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'Görevler ${setup.goals.length} hedefine göre üretildi · '
                        '${setup.tempo.label} tempo',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 21, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numeric.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddQuestButton extends StatelessWidget {
  const _AddQuestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        key: const Key('add-quest-button'),
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Yeni Görev / Hedef Ekle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karakter statları özeti — varsayılan olarak **kapalı**.
///
/// Dokununca radar ve beş gelişim alanı açılır; dashboard'ın üst kısmı sade
/// kalır, detay isteyen tek dokunuşla derinliğe iner.
class _StatsDisclosure extends StatefulWidget {
  const _StatsDisclosure({required this.profile, required this.radar});

  final UserProfile profile;
  final Map<StatKey, double> radar;

  @override
  State<_StatsDisclosure> createState() => _StatsDisclosureState();
}

class _StatsDisclosureState extends State<_StatsDisclosure> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final UserProfile profile = widget.profile;
    final int average = profile.rpgStats.averageRadarValue.round();

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('dashboard-stats-toggle'),
              onTap: _toggle,
              borderRadius: AppRadii.mdAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: AppRadii.mdAll,
                      ),
                      child: const Text('📊', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Karakter Statları',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _open
                                ? 'Radar ve 5 gelişim alanı açık'
                                : 'Radar · 5 alan · '
                                      '${FormatX.number(profile.totalXp)} XP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InfoPill(
                      label: 'Ort. $average',
                      color: AppColors.primary,
                      dense: true,
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: AppMotion.fast,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            child: _open
                ? _expanded(profile, average)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _expanded(UserProfile profile, int average) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(height: AppSpacing.lg, color: AppColors.border),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'En güçlü stat: '
                      '${profile.rpgStats.strongest.stat.label}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    InfoPill(
                      label: 'Ortalama $average / 100',
                      color: AppColors.primary,
                      dense: true,
                    ),
                  ],
                ),
              ),
              StatRadarChart(values: widget.radar, size: 148),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final StatKey stat in StatKey.values) ...<Widget>[
            StatProgressTile(progress: profile.rpgStats[stat]),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
        ],
      ),
    );
  }
}
