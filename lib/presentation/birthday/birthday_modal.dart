import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';
import '../../domain/entities/entities.dart';
import '../widgets/section_header.dart';

/// Doğum günü deneyimini açar.
///
/// Tarih [BirthdayConfig.ceyda] ile eşleştiğinde Bugün sekmesindeki banner
/// otomatik kutlama moduna geçer; banner her zaman dokunulabilir olduğu için
/// sürpriz istenen gün yaşanabilir.
Future<void> showBirthdayExperience(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (BuildContext dialogContext) => const BirthdayModal(),
  );
}

/// Ceyda'nın doğum günü kutlaması: mektup, yılın özeti ve aşk notu üretici.
class BirthdayModal extends ConsumerWidget {
  const BirthdayModal({this.now, super.key});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final DateTime at = now ?? DateTime.now();
    final PartnerData ceyda =
        state.partnerData(CouplePartner.ceydaId) ?? const PartnerData();
    final CoupleState couple = state.couple;
    final int goalCount = couple.bucketGoals
        .where((BucketGoal goal) => goal.isDone)
        .length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.lgAll,
            boxShadow: AppShadows.floating,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.lgAll,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _BirthdayHero(ceyda: ceyda, now: at),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Sevgili Ceyda,',
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _BirthdayLetter(message: couple.birthdayMessage),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'YILIN ÖZETİ',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '⚡',
                                value: FormatX.number(ceyda.totalXp),
                                label: 'toplam XP',
                              ),
                            ),
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '🔥',
                                value:
                                    '${ceyda.profile?.streak.currentDays ?? 0}',
                                label: 'gün seri',
                              ),
                            ),
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '💬',
                                value: '${couple.messages.length}',
                                label: 'mesaj',
                              ),
                            ),
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '📸',
                                value: '${couple.photoMessages.length}',
                                label: 'anı',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '🎯',
                                value: '${ceyda.completedCount}',
                                label: 'görev',
                              ),
                            ),
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '✨',
                                value: '$goalCount',
                                label: 'ortak hedef',
                              ),
                            ),
                            Expanded(
                              child: _BirthdayStat(
                                emoji: '💞',
                                value: '${couple.synergyCountOn(at)}',
                                label: 'sinerji',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _NoteSurprise(),
                        const SizedBox(height: AppSpacing.lg),
                        _BirthdayBucketList(goals: couple.bucketGoals),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          key: const Key('birthday-close'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: CouplePalette.ceyda,
                            minimumSize: const Size.fromHeight(50),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.mdAll,
                            ),
                          ),
                          child: const Text('Seni seviyorum 💖'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthdayLetter extends ConsumerWidget {
  const _BirthdayLetter({required this.message});

  final String message;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(text: message);
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mektubu kişiselleştir'),
          content: TextField(
            key: const Key('birthday-letter-input'),
            controller: controller,
            autofocus: true,
            maxLines: 5,
            maxLength: 320,
            decoration: const InputDecoration(
              hintText: 'Ceyda\'ya söylemek istediklerin…',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              key: const Key('birthday-letter-save'),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null) return;
    ref.read(gameProvider.notifier).setBirthdayMessage(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('birthday-letter'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CouplePalette.ceyda.withValues(alpha: 0.07),
        borderRadius: AppRadii.mdAll,
        border: Border.all(
          color: CouplePalette.ceyda.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            key: const Key('birthday-letter-edit'),
            onPressed: () => _edit(context, ref),
            style: TextButton.styleFrom(
              foregroundColor: CouplePalette.ceyda,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: Text(
              'Mektubu düzenle',
              style: AppTypography.caption.copyWith(
                color: CouplePalette.ceyda,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayBucketList extends ConsumerWidget {
  const _BirthdayBucketList({required this.goals});

  final List<BucketGoal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int done = goals.where((BucketGoal goal) => goal.isDone).length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CouplePalette.yusuf.withValues(alpha: 0.05),
        borderRadius: AppRadii.mdAll,
        border: Border.all(
          color: CouplePalette.yusuf.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Birlikte Yapılacaklar · $done/${goals.length}',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              InfoPill(
                label: '+50 XP çift',
                color: CouplePalette.yusuf,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Tamamlanan her hedef ikinize de +50 XP kazandırır.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final BucketGoal goal in goals)
            InkWell(
              key: Key('birthday-bucket-${goal.id}'),
              borderRadius: AppRadii.smAll,
              onTap: () {
                final bool completed = ref
                    .read(gameProvider.notifier)
                    .toggleBucketGoal(goal.id);
                if (completed && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('🎯 Hedef tamam! İkinize de +50 XP'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Icon(
                      goal.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: goal.isDone
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(goal.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: AppTypography.caption.copyWith(
                          color: goal.isDone
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: goal.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BirthdayHero extends StatelessWidget {
  const _BirthdayHero({required this.ceyda, required this.now});

  final PartnerData ceyda;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool today = BirthdayConfig.ceyda.isToday(now);
    final int daysLeft = BirthdayConfig.ceyda.daysUntil(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(gradient: AppGradients.legendary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🎂', style: TextStyle(fontSize: 34)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      today ? 'İyi ki doğdun Ceyda!' : 'Ceyda için sürpriz',
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textOnAccent,
                        fontSize: 22,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      today
                          ? '${BirthdayConfig.ceyda.dateLabel} · bugün senin günün'
                          : '${BirthdayConfig.ceyda.dateLabel} · $daysLeft gün kaldı',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnAccent.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 1,
            ),
            decoration: BoxDecoration(
              color: AppColors.textOnAccent.withValues(alpha: 0.22),
              borderRadius: AppRadii.pillAll,
            ),
            child: Text(
              '🌸 ${ceyda.displayName} · Lv${ceyda.levelNumber}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textOnAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayStat extends StatelessWidget {
  const _BirthdayStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric.copyWith(
            color: AppColors.textPrimary,
            fontSize: 17,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _NoteSurprise extends ConsumerWidget {
  const _NoteSurprise();

  Future<void> _writeCustom(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Kendi notunu yaz'),
          content: TextField(
            key: const Key('birthday-custom-note-input'),
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 160,
            decoration: const InputDecoration(
              hintText: 'Neden sen? Aklına geleni yaz…',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              key: const Key('birthday-custom-note-save'),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    ref.read(gameProvider.notifier).addLoveNote(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Notun kaydedildi ✨ Yeni not: +20 XP'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String note = ref.watch(loveNoteProvider);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CouplePalette.ceyda.withValues(alpha: 0.07),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: CouplePalette.ceyda.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: CouplePalette.ceyda,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'GÜNÜN AŞK NOTU · NEDEN SEN?',
                  style: AppTypography.label.copyWith(
                    color: CouplePalette.ceyda,
                    fontSize: 10,
                  ),
                ),
              ),
              IconButton(
                key: const Key('birthday-note-next'),
                tooltip: 'Yeni not çek',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    ref.read(gameProvider.notifier).cycleLoveNote(),
                icon: const Icon(
                  Icons.casino_rounded,
                  size: 18,
                  color: CouplePalette.ceyda,
                ),
              ),
            ],
          ),
          Text(
            '“$note”',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Her gönderilen not ikinize de +20 XP kazandırır.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton.icon(
                key: const Key('birthday-custom-note'),
                onPressed: () => _writeCustom(context, ref),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Kendim yazayım'),
                style: TextButton.styleFrom(
                  foregroundColor: CouplePalette.ceyda,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              TextButton.icon(
                key: const Key('birthday-note-send'),
                onPressed: () {
                  ref.read(gameProvider.notifier).sendLoveNote();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Aşk notu sohbete düştü 💌 · +20 XP'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                },
                icon: const Icon(Icons.send_rounded, size: 15),
                label: const Text('Sohbete gönder'),
                style: TextButton.styleFrom(
                  foregroundColor: CouplePalette.ceyda,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
