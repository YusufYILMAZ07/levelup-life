import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';

/// "Yeni Kapsül" alt sayfasını açar.
Future<void> showAddCapsuleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => const _AddCapsuleSheet(),
  );
}

class _AddCapsuleSheet extends ConsumerStatefulWidget {
  const _AddCapsuleSheet();

  @override
  ConsumerState<_AddCapsuleSheet> createState() => _AddCapsuleSheetState();
}

class _AddCapsuleSheetState extends ConsumerState<_AddCapsuleSheet> {
  static const List<String> _emojiChoices = <String>[
    '🎁',
    '☕',
    '🍿',
    '🎬',
    '💆',
    '🏖️',
    '🍰',
    '🎮',
  ];

  static const List<int> _pointChoices = <int>[250, 500, 750, 1000, 1500];

  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _reward = TextEditingController();

  String _emoji = '🎁';
  int _points = 500;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reward.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty && _points > 0;

  void _save() {
    if (!_valid) return;
    final RewardCapsule? capsule = ref
        .read(gameProvider.notifier)
        .addRewardCapsule(
          title: _title.text,
          requiredPoints: _points,
          emoji: _emoji,
          description: _description.text,
          rewardMessage: _reward.text,
        );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            capsule == null
                ? 'Kapsül eklenemedi 😕'
                : '${capsule.emoji} ${capsule.title} rafa eklendi',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadii.pillAll,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Yeni Ödül Kapsülü',
                      style: AppTypography.title.copyWith(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SheetLabel('Simge'),
              const SizedBox(height: AppSpacing.xs + 1),
              Wrap(
                spacing: AppSpacing.xs + 1,
                runSpacing: AppSpacing.xs + 1,
                children: <Widget>[
                  for (final String emoji in _emojiChoices)
                    GestureDetector(
                      key: Key('capsule-emoji-$emoji'),
                      onTap: () => setState(() => _emoji = emoji),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _emoji == emoji
                              ? AppColors.xp.withValues(alpha: 0.16)
                              : AppColors.surfaceMuted,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(
                            color: _emoji == emoji
                                ? AppColors.xp
                                : AppColors.border,
                            width: _emoji == emoji ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SheetLabel('Ödül adı'),
              const SizedBox(height: AppSpacing.xs + 1),
              TextField(
                key: const Key('capsule-title-field'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _decoration('Örn. Hafta sonu kahvaltı kaçamağı'),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SheetLabel('Kaç puanda açılsın?'),
              const SizedBox(height: AppSpacing.xs + 1),
              Wrap(
                spacing: AppSpacing.xs + 1,
                runSpacing: AppSpacing.xs + 1,
                children: <Widget>[
                  for (final int points in _pointChoices)
                    GestureDetector(
                      key: Key('capsule-points-$points'),
                      onTap: () => setState(() => _points = points),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: _points == points
                              ? AppColors.primary
                              : AppColors.surfaceMuted,
                          borderRadius: AppRadii.pillAll,
                          border: Border.all(
                            color: _points == points
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '$points',
                          style: AppTypography.numeric.copyWith(
                            color: _points == points
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SheetLabel('Kilitliyken görünen açıklama'),
              const SizedBox(height: AppSpacing.xs + 1),
              TextField(
                key: const Key('capsule-desc-field'),
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _decoration('Bu kapsül bizi neye götürecek?'),
              ),

              const SizedBox(height: AppSpacing.md),
              const _SheetLabel('Açılınca gösterilecek mesaj'),
              const SizedBox(height: AppSpacing.xs + 1),
              TextField(
                key: const Key('capsule-reward-field'),
                controller: _reward,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _decoration('Tebrikler, bu hafta...'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('capsule-save-button'),
                  onPressed: _valid ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.pillAll,
                    ),
                  ),
                  child: Text(
                    'Rafa Ekle',
                    style: AppTypography.bodySmall.copyWith(
                      color: _valid ? Colors.white : AppColors.textTertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
    filled: true,
    fillColor: AppColors.surfaceMuted,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm + 2,
    ),
    border: const OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}
