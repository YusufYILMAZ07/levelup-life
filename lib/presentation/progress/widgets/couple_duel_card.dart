import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../application/game_state.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/services.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/stat_radar_chart.dart';

/// Haftalık verimlilik düellosu: iki partnerin 7 günlük skoru, bileşenleri,
/// kazananı ve haftanın bahsi.
class CoupleDuelCard extends ConsumerWidget {
  const CoupleDuelCard({this.now, super.key});

  final DateTime? now;

  Future<void> _pickStake(BuildContext context, WidgetRef ref) async {
    final DuelStake? picked = await showModalBottomSheet<DuelStake>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (BuildContext sheetContext) {
        final DuelStake current = ref.read(gameProvider).couple.stake;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Bu haftanın bahsi',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ),
              for (final DuelStake stake in DuelStake.values)
                ListTile(
                  key: Key('stake-${stake.code}'),
                  leading: Text(
                    stake.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(
                    stake.label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    stake.detail,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  trailing: stake == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(stake),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(gameProvider.notifier).setStake(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoupleDuelResult duel = ref.watch(duelProvider);
    final PartnerEfficiency yusuf = duel.yusuf;
    final PartnerEfficiency ceyda = duel.ceyda;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Haftalık Verimlilik Düellosu',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'Son ${CoupleEfficiencyEngine.windowDays} gün · '
                      'mükemmellik değil süreklilik',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              InfoPill(
                label: '%${duel.couplePercent} çift',
                color: CouplePalette.scoreColor(duel.couplePercent),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _DuelistTile(
                  efficiency: yusuf,
                  isLeader: duel.leaderId == yusuf.partnerId,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DuelistTile(
                  efficiency: ceyda,
                  isLeader: duel.leaderId == ceyda.partnerId,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            duel.hasAnyData
                ? duel.headline
                : 'İlk puanlar girildiğinde yarış başlıyor ✨',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!yusuf.hasData || !ceyda.hasData) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Veri girilmeyen partner nötr (50) skorla gösterilir; '
              'böylece düello adil kalır.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final EfficiencyFactor factor
              in EfficiencyFactor.values) ...<Widget>[
            _FactorRow(
              factor: factor,
              yusufPercent: yusuf.factorPercent(factor),
              ceydaPercent: ceyda.factorPercent(factor),
            ),
            if (factor != EfficiencyFactor.values.last)
              const SizedBox(height: AppSpacing.sm),
          ],
          const Divider(height: AppSpacing.xxl, color: AppColors.divider),
          InkWell(
            key: const Key('pick-stake'),
            onTap: () => _pickStake(context, ref),
            borderRadius: AppRadii.mdAll,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  Text(duel.stake.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'HAFTANIN BAHSİ',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          duel.stake.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Değiştir',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '💞 ${duel.synergyCount} sinerji · her sinerji çift skoruna '
            '+${CoupleEfficiencyEngine.synergyBonusPoints.round()} puan ekler',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuelistTile extends StatelessWidget {
  const _DuelistTile({required this.efficiency, required this.isLeader});

  final PartnerEfficiency efficiency;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(efficiency.partnerId);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: CouplePalette.auraOf(efficiency.partnerId, peak: 0.14),
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(
          color: isLeader ? accent.withValues(alpha: 0.5) : AppColors.border,
          width: isLeader ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                CouplePalette.emojiOf(efficiency.partnerId),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  efficiency.partnerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isLeader) const Text('👑', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '%${efficiency.percent}',
            style: AppTypography.numericLarge.copyWith(
              color: CouplePalette.scoreColor(efficiency.percent),
              fontSize: 24,
            ),
          ),
          Text(
            '${efficiency.activeDays}/7 aktif · '
            '${efficiency.ratedDays}/7 rubrik',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
          if (efficiency.strongestPillar != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${DevelopmentRubric.forStat(efficiency.strongestPillar!).emoji} '
              '${efficiency.strongestLabel}',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.factor,
    required this.yusufPercent,
    required this.ceydaPercent,
  });

  final EfficiencyFactor factor;
  final int yusufPercent;
  final int ceydaPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${factor.emoji} ${factor.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(factor.weight * 100).round()}% ağırlık',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs + 2),
        Row(
          children: <Widget>[
            Expanded(
              child: _MiniBar(
                percent: yusufPercent,
                color: CouplePalette.yusuf,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniBar(
                percent: ceydaPercent,
                color: CouplePalette.ceyda,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double fraction = (percent / 100).clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: Stack(
              children: <Widget>[
                Container(height: 6, color: AppColors.surfaceSunken),
                FractionallySizedBox(
                  widthFactor: fraction == 0 ? 0.02 : fraction,
                  child: Container(height: 6, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 26,
          child: Text(
            '$percent',
            textAlign: TextAlign.right,
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// İki partnerin karakter radarını yan yana gösterir (gelişim karşılaştırması).
class CoupleRadarCard extends ConsumerWidget {
  const CoupleRadarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    if (!state.isCoupleEdition) return const SizedBox.shrink();

    final UserProfile? yusuf = state
        .partnerData(CouplePartner.yusufId)
        ?.profile;
    final UserProfile? ceyda = state
        .partnerData(CouplePartner.ceydaId)
        ?.profile;
    if (yusuf == null || ceyda == null) return const SizedBox.shrink();

    Map<StatKey, double> radarOf(UserProfile profile) => <StatKey, double>{
      for (final StatKey stat in StatKey.values)
        stat: profile.rpgStats[stat].radarValue,
    };

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Karşılaştırmalı Radar',
            style: AppTypography.title.copyWith(
              color: AppColors.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'İki karakterin stat dağılımı · güçlü alanlar farklıysa takım tamam',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _RadarColumn(
                  partnerId: CouplePartner.yusufId,
                  values: radarOf(yusuf),
                  profile: yusuf,
                ),
              ),
              Expanded(
                child: _RadarColumn(
                  partnerId: CouplePartner.ceydaId,
                  values: radarOf(ceyda),
                  profile: ceyda,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarColumn extends StatelessWidget {
  const _RadarColumn({
    required this.partnerId,
    required this.values,
    required this.profile,
  });

  final String partnerId;
  final Map<StatKey, double> values;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    return Column(
      children: <Widget>[
        StatRadarChart(
          values: values,
          size: 148,
          accent: accent,
          showLabels: false,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${CouplePalette.emojiOf(partnerId)} ${profile.firstName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Güçlü: ${profile.rpgStats.strongest.stat.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
