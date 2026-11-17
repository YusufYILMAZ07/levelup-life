import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/services.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/section_header.dart';

/// "+ Yeni Görev / Hedef Ekle" modalı.
Future<void> showAddQuestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => const AddQuestSheet(),
  );
}

class AddQuestSheet extends ConsumerStatefulWidget {
  const AddQuestSheet({super.key});

  @override
  ConsumerState<AddQuestSheet> createState() => _AddQuestSheetState();
}

class _AddQuestSheetState extends ConsumerState<AddQuestSheet> {
  final TextEditingController _titleController = TextEditingController();

  StatKey _stat = StatKey.intelligence;
  QuestDifficulty _difficulty = QuestDifficulty.moderate;
  double _minutes = 30;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  int get _xp => QuestGenerator.estimateXp(_minutes.round(), _difficulty);

  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    final Quest quest = QuestGenerator.custom(
      title: _titleController.text,
      stat: _stat,
      minutes: _minutes.round(),
      difficulty: _difficulty,
      now: DateTime.now(),
    );
    ref.read(gameProvider.notifier).addQuest(quest);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.xxl + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Medallion(
                  icon: Icons.add_task_rounded,
                  gradient: AppGradients.primary,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Yeni Görev / Hedef Ekle',
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Kendi hedefini yaz; statını ve süresini sen seç.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              key: const Key('add-quest-title'),
              controller: _titleController,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Örn. 20 dk İngilizce konuşma pratiği',
                prefixIcon: Icon(Icons.edit_note_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Hangi statı besliyor?',
              subtitle: 'Görev tamamlanınca bu stat XP kazanır.',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final StatKey stat in StatKey.values)
                  _StatChoice(
                    stat: stat,
                    selected: _stat == stat,
                    onTap: () => setState(() => _stat = stat),
                  ),
              ],
            ),
            // __REST__
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Süre',
              subtitle: '${_minutes.round()} dakika',
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _stat.color,
                thumbColor: _stat.color,
                overlayColor: _stat.color.withValues(alpha: 0.12),
                inactiveTrackColor: AppColors.surfaceSunken,
              ),
              child: Slider(
                value: _minutes,
                min: 10,
                max: 120,
                divisions: 22,
                label: '${_minutes.round()} dk',
                onChanged: (double value) => setState(() => _minutes = value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Zorluk'),
            Row(
              children: <Widget>[
                for (final QuestDifficulty difficulty in QuestDifficulty.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: difficulty == QuestDifficulty.epic
                            ? 0
                            : AppSpacing.sm,
                      ),
                      child: _DifficultyChoice(
                        difficulty: difficulty,
                        selected: _difficulty == difficulty,
                        color: _stat.color,
                        onTap: () => setState(() => _difficulty = difficulty),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              decoration: BoxDecoration(
                color: _stat.surfaceTint,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: _stat.borderColor),
              ),
              child: Row(
                children: <Widget>[
                  Icon(_stat.icon, color: _stat.color, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${_stat.code} görevine ${_difficulty.label.toLowerCase()} '
                      'seviye · ${_minutes.round()} dk',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InfoPill(label: '+$_xp XP', color: _stat.color, dense: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GradientButton(
              label: 'Görevi Ekle',
              icon: Icons.add_rounded,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChoice extends StatelessWidget {
  const _StatChoice({
    required this.stat,
    required this.selected,
    required this.onTap,
  });

  final StatKey stat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? stat.surfaceTint : AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? stat.color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(stat.icon, size: 15, color: stat.color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                stat.code,
                style: AppTypography.caption.copyWith(
                  color: selected ? stat.color : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyChoice extends StatelessWidget {
  const _DifficultyChoice({
    required this.difficulty,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final QuestDifficulty difficulty;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : AppColors.surface,
      borderRadius: AppRadii.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.smAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            difficulty.label,
            style: AppTypography.caption.copyWith(
              color: selected ? color : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
