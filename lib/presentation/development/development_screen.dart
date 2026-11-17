import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/services.dart';
import '../widgets/couple_top_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_card.dart';

/// Gelişim sekmesi: günlük 1-2-3 rubriği, hızlı bonus eylemler ve ortak
/// bucket list.
///
/// Rubrik puanı **aktif partner** için yazılır; üst bardan partner değiştirince
/// aynı ekrandan diğerinin puanlarını girebilirsin. İki taraf da aynı alanda
/// 2+ puan alırsa sinerji bonusu (+25 XP her ikinize) tetiklenir.
class DevelopmentScreen extends ConsumerWidget {
  const DevelopmentScreen({this.now, super.key});

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  void _rate(BuildContext context, WidgetRef ref, StatKey pillar, int score) {
    final RubricOutcome outcome = ref
        .read(gameProvider.notifier)
        .ratePillar(pillar: pillar, score: score);
    final String message = outcome.hasSynergy
        ? 'Sinerji! İkiniz de ${DevelopmentRubric.forStat(pillar).title} '
              'alanında 2+ puan aldınız · +${outcome.synergyXp} XP'
        : outcome.xpGained > 0
        ? '+${outcome.xpGained} XP · ${pillar.label} güçlendi'
        : 'Puan güncellendi · bugünkü toplam ${outcome.totalToday}/15';
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
    if (profile == null) return const SizedBox.shrink();

    final DateTime at = now ?? DateTime.now();
    final CoupleState couple = state.couple;
    final String activeId = state.activePartnerId;
    final String name = CouplePalette.nameOf(activeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Gelişim',
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Günlük 1-2-3 rubriği · mükemmellik değil ritim',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                CoupleTopBar(now: at),
                const SizedBox(height: AppSpacing.lg),
                _TodayScoreCard(
                  name: name,
                  partnerId: activeId,
                  total: couple.rubricTotalOn(activeId, at),
                  rubricXp: couple.rubricXpOn(activeId, at),
                  bonusPoints: couple.bonusPointsOn(activeId, at),
                  improvement: couple.improvementPointsOf(activeId),
                ),
                const SizedBox(height: AppSpacing.md),
                _SynergyBanner(couple: couple, now: at),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(
                  title: 'Günlük Gelişim Rubriği',
                  subtitle: '$name için · 1 → 10 XP · 2 → 25 XP · 3 → 45 XP',
                ),
                for (final PillarDefinition pillar in DevelopmentRubric.pillars)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                    child: _PillarCard(
                      pillar: pillar,
                      score: couple.rubricScore(activeId, pillar.stat, at),
                      onScore: (int score) =>
                          _rate(context, ref, pillar.stat, score),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Hızlı Bonus Eylemler',
                  subtitle: 'Tek dokunuş · anında XP',
                ),
                _QuickActionGrid(
                  onAction: (QuickAction action) {
                    final XpAward? award = ref
                        .read(gameProvider.notifier)
                        .quickAction(action);
                    if (award == null) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            '${action.emoji} +${award.xpGained} XP · '
                            '${action.stat.label} güçlendi',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Ortak Bucket List',
                  subtitle:
                      '${couple.bucketGoals.where((BucketGoal goal) => goal.isDone).length}'
                      '/${couple.bucketGoals.length} tamamlandı · '
                      '+${CoupleState.bucketBonusXp} XP her ikinize',
                ),
                _BucketListCard(
                  goals: couple.bucketGoals,
                  onToggle: (String id) {
                    final bool completed = ref
                        .read(gameProvider.notifier)
                        .toggleBucketGoal(id);
                    if (!completed) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Co-Op tamamlandı! İkiniz de '
                            '+${CoupleState.bucketBonusXp} XP kazandınız 💖',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const _LoveNoteCard(),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'Puanlar $name için kaydediliyor · '
                    'partner değiştirmek için üst barı kullan',
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
    );
  }
}

class _TodayScoreCard extends StatelessWidget {
  const _TodayScoreCard({
    required this.name,
    required this.partnerId,
    required this.total,
    required this.rubricXp,
    required this.bonusPoints,
    required this.improvement,
  });

  final String name;
  final String partnerId;
  final int total;
  final int rubricXp;
  final int bonusPoints;
  final int improvement;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    final double fraction =
        (total / (DevelopmentRubric.maxScore * DevelopmentRubric.pillarCount))
            .clamp(0.0, 1.0);

    return SoftCard(
      gradient: CouplePalette.auraOf(partnerId, peak: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${CouplePalette.emojiOf(partnerId)} $name · bugün',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InfoPill(label: '$total/15 puan', color: accent, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: Stack(
              children: <Widget>[
                Container(height: 8, color: AppColors.surfaceSunken),
                FractionallySizedBox(
                  widthFactor: fraction == 0 ? 0.02 : fraction,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: CouplePalette.gradientOf(partnerId),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _ScoreMetric(
                  label: 'Rubrik XP',
                  value: '+$rubricXp',
                  color: accent,
                ),
              ),
              Expanded(
                child: _ScoreMetric(
                  label: 'Bonus',
                  value: '+$bonusPoints',
                  color: AppColors.statWillpower,
                ),
              ),
              Expanded(
                child: _ScoreMetric(
                  label: 'Toplam puan',
                  value: '$improvement',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreMetric extends StatelessWidget {
  const _ScoreMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric.copyWith(color: color, fontSize: 16),
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
    );
  }
}

class _SynergyBanner extends StatelessWidget {
  const _SynergyBanner({required this.couple, required this.now});

  final CoupleState couple;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final List<PillarDefinition> matched = DevelopmentRubric.pillars
        .where((PillarDefinition pillar) => couple.hasSynergy(pillar.stat, now))
        .toList(growable: false);

    return SoftCard(
      color: AppColors.surface,
      gradient: AppGradients.aura(AppColors.streak, peakOpacity: 0.14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Medallion(
            icon: Icons.auto_awesome_rounded,
            gradient: AppGradients.streak,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Çift Sinerji',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  matched.isEmpty
                      ? 'Aynı gün aynı alanda ikiniz de 2+ puan alın → '
                            'her ikinize +${CoupleEfficiencyEngine.synergyXp} XP.'
                      : 'Bugün yakalanan alanlar: '
                            '${matched.map((PillarDefinition pillar) => '${pillar.emoji} ${pillar.title}').join(', ')}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InfoPill(
            label: '${matched.length}/5',
            color: AppColors.streak,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillar,
    required this.score,
    required this.onScore,
  });

  final PillarDefinition pillar;
  final int score;
  final ValueChanged<int> onScore;

  @override
  Widget build(BuildContext context) {
    final Color accent = pillar.stat.color;
    return SoftCard(
      borderColor: score > 0 ? accent.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Medallion(
                icon: pillar.stat.icon,
                gradient: pillar.stat.gradient,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          pillar.emoji,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            pillar.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      pillar.hint,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InfoPill(
                label: '$score/${DevelopmentRubric.maxScore}',
                color: score > 0 ? accent : AppColors.textTertiary,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (
                int value = 1;
                value <= DevelopmentRubric.maxScore;
                value++
              ) ...<Widget>[
                Expanded(
                  child: _ScoreButton(
                    key: Key('rubric-${pillar.stat.code}-$value'),
                    score: value,
                    selected: score == value,
                    accent: accent,
                    onTap: () => onScore(value),
                  ),
                ),
                if (value != DevelopmentRubric.maxScore)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          if (score > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '✓ ${pillar.criteriaFor(score)}',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.score,
    required this.selected,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final int score;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : AppColors.surfaceMuted,
      borderRadius: AppRadii.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.smAll,
            border: Border.all(color: selected ? accent : AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              Text(
                '$score',
                style: AppTypography.numeric.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              Text(
                '+${DevelopmentRubric.xpFor(score)} XP',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: selected
                      ? AppColors.textOnAccent.withValues(alpha: 0.9)
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.onAction});

  final ValueChanged<QuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      for (final QuickAction action in QuickAction.values)
        _QuickActionTile(
          key: Key('quick-${action.code}'),
          action: action,
          onTap: () => onAction(action),
        ),
    ];

    return Column(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (i + 2 < tiles.length) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.action,
    required this.onTap,
    super.key,
  });

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = action.stat.color;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
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
              Row(
                children: <Widget>[
                  Text(action.emoji, style: const TextStyle(fontSize: 18)),
                  const Spacer(),
                  InfoPill(
                    label: '+${action.points} XP',
                    color: accent,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketListCard extends StatelessWidget {
  const _BucketListCard({required this.goals, required this.onToggle});

  final List<BucketGoal> goals;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return SoftCard(
        child: Text(
          'Henüz ortak hedef yok.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return SoftCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < goals.length; i++) ...<Widget>[
            InkWell(
              key: Key('bucket-${goals[i].id}'),
              onTap: () => onToggle(goals[i].id),
              borderRadius: AppRadii.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Icon(
                      goals[i].isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: goals[i].isDone
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(goals[i].emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            goals[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: goals[i].isDone
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              decoration: goals[i].isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (goals[i].detail.isNotEmpty)
                            Text(
                              goals[i].detail,
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
                  ],
                ),
              ),
            ),
            if (i != goals.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _LoveNoteCard extends ConsumerWidget {
  const _LoveNoteCard();

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Aşk notu ekle'),
        content: TextField(
          key: const Key('love-note-input'),
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ceyda\'ya söylemek istediğin bir şey…',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.isEmpty) return;
    ref.read(gameProvider.notifier).addLoveNote(note);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String note = ref.watch(loveNoteProvider);
    return SoftCard(
      gradient: AppGradients.aura(CouplePalette.ceyda, peakOpacity: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Medallion(
                icon: Icons.favorite_rounded,
                gradient: AppGradients.legendary,
                size: 38,
                iconSize: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Aşk Notu Üretici',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Doğum günü için hazır cümleler',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('love-note-next'),
                tooltip: 'Sonraki not',
                onPressed: () =>
                    ref.read(gameProvider.notifier).cycleLoveNote(),
                icon: const Icon(
                  Icons.casino_rounded,
                  color: CouplePalette.ceyda,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.mdAll,
              border: Border.all(
                color: CouplePalette.ceyda.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              '“$note”',
              key: const Key('love-note-text'),
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('love-note-send'),
                  onPressed: () {
                    final ChatMessage? message = ref
                        .read(gameProvider.notifier)
                        .sendLoveNote();
                    if (message == null) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Aşk notu sohbete gönderildi 💌'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Sohbete gönder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CouplePalette.ceyda,
                    side: BorderSide(
                      color: CouplePalette.ceyda.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                key: const Key('love-note-add'),
                onPressed: () => _addNote(context, ref),
                child: const Text('Not ekle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
