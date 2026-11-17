import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';
import '../../domain/entities/entities.dart';
import '../widgets/couple_top_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_card.dart';
import 'widgets/couple_duel_card.dart';
import 'widgets/progress_range_toggle.dart';
import 'widgets/streak_calendar.dart';
import 'widgets/streak_hero_card.dart';
import 'widgets/xp_trend_chart.dart';

/// İlerleme sekmesi: günlük seri + 7/30 günlük XP grafiği + seri takvimi.
///
/// Tüm veri `UserProfile.xpLog`'dan (dolayısıyla `GameState`) gelir; ekran
/// kendi başına hiçbir şey kaydetmez. Aralık seçimi ekran durumudur, sekme
/// değişse de `IndexedStack` sayesinde korunur.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({this.now, super.key});

  /// Testlerde zamanı sabitlemek için; üretimde `DateTime.now()` kullanılır.
  final DateTime? now;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;

  void _selectRange(ProgressRange range) {
    if (range == _range) return;
    setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = ref.watch(gameProvider);
    final UserProfile? profile = state.profile;
    if (profile == null) return const SizedBox.shrink();

    final DateTime now = widget.now ?? DateTime.now();
    final DailyXpLog log = state.xpLog;
    final List<DailyXp> series = log.series(end: now, days: _range.days);
    final int rangeTotal = series.fold<int>(
      0,
      (int sum, DailyXp point) => sum + point.xp,
    );
    final int rangeActiveDays =
        series.where((DailyXp point) => point.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const Positioned(top: -150, right: -110, child: _AuraGlow()),
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
                    _buildHeader(profile, log),
                    if (state.isCoupleEdition) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      const CoupleTopBar(),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (state.isCoupleEdition) ...<Widget>[
                      const CoupleDuelCard(),
                      const SizedBox(height: AppSpacing.lg),
                      const CoupleRadarCard(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    StreakHeroCard(
                      streak: profile.streak,
                      activeToday: log.isActiveOn(now),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTrendCard(
                      log: log,
                      series: series,
                      now: now,
                      rangeTotal: rangeTotal,
                      rangeActiveDays: rangeActiveDays,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SectionHeader(
                      title: 'Seri Takvimi',
                      subtitle: 'Son 5 hafta · bugün halka ile işaretli',
                      trailing: InfoPill(
                        label: '${log.activeDays} gün',
                        color: AppColors.primary,
                        dense: true,
                      ),
                    ),
                    SoftCard(child: StreakCalendar(log: log, now: now)),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'Günlük XP geçmişi bu cihazda saklanır.',
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

  Widget _buildHeader(UserProfile profile, DailyXpLog log) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'İlerleme',
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Toplam ${FormatX.number(profile.totalXp)} XP · '
                '${log.activeDays} aktif gün',
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
        InfoPill(
          label: '${profile.streak.currentDays} gün seri',
          color: AppColors.streak,
          icon: Icons.local_fire_department_rounded,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildTrendCard({
    required DailyXpLog log,
    required List<DailyXp> series,
    required DateTime now,
    required int rangeTotal,
    required int rangeActiveDays,
  }) {
    return SoftCard(
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
                      _range.caption.toUpperCase(),
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${FormatX.number(rangeTotal)} XP',
                      style: AppTypography.numericLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '$rangeActiveDays / ${_range.days} gün aktif',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              ProgressRangeToggle(value: _range, onChanged: _selectRange),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          XpTrendChart(series: series, range: _range, now: now),
          if (log.isEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const _EmptyChartHint(),
          ],
        ],
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  const _EmptyChartHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.tips_and_updates_outlined,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Henüz XP kaydı yok. İlk görevini tamamladığında grafik canlanır.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sağ üstteki yumuşak marka ışıması.
class _AuraGlow extends StatelessWidget {
  const _AuraGlow();

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
