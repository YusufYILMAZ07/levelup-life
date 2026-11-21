import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';

/// Görev tamamlanmadan önce doğrulama modalını açar.
///
/// Kullanıcı doğrulamayı geçerse `true`, vazgeçerse `false` döner. Doğrulama
/// tipi ne olursa olsun (manuel onay dahil) tek bir onay adımı gösterilir;
/// böylece yanlışlıkla görev kapatma engellenir.
Future<bool> showQuestVerificationDialog(
  BuildContext context,
  Quest quest,
) async {
  final QuestVerification verification = quest.verification;
  if (verification is ManualVerification && !verification.requiresNote) {
    return true;
  }

  final bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return switch (verification) {
        TimerVerification v => _TimerDialog(quest: quest, timer: v),
        ReflectionVerification v => _ReflectionDialog(quest: quest, rule: v),
        StepGoalVerification v => _StepGoalDialog(quest: quest, rule: v),
        ChecklistVerification v => _ChecklistDialog(quest: quest, rule: v),
        ManualVerification v => _NoteDialog(quest: quest, rule: v),
      };
    },
  );
  return result ?? false;
}

class _QuestDialog extends StatelessWidget {
  const _QuestDialog({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.confirmLabel,
    required this.onConfirm,
    this.confirmEnabled = true,
    this.onStart,
    this.startLabel,
    this.extraAction,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool confirmEnabled;
  final VoidCallback? onStart;
  final String? startLabel;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: AppRadii.smAll,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
              const SizedBox(height: AppSpacing.lg),
              if (extraAction != null) ...<Widget>[
                extraAction!,
                const SizedBox(height: AppSpacing.xs),
              ],
              Row(
                children: <Widget>[
                  if (onStart != null) ...<Widget>[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('verification-start'),
                        onPressed: onStart,
                        child: Text(startLabel ?? 'Başlat'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: TextButton(
                      key: const Key('verification-cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('verification-confirm'),
                      onPressed: confirmEnabled ? onConfirm : null,
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.quest, required this.rule});

  final Quest quest;
  final ManualVerification rule;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QuestDialog(
      emoji: '📝',
      title: widget.quest.effectiveTitle,
      subtitle: 'Kısa bir not ile manuel onay',
      confirmLabel: 'Tamamladım',
      confirmEnabled: _note.text.trim().length >= 10,
      onConfirm: () => Navigator.of(context).pop(true),
      child: TextField(
        key: const Key('verification-note-input'),
        controller: _note,
        autofocus: true,
        maxLines: 3,
        maxLength: 180,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Ne yaptın? Kısaca not düş…',
        ),
      ),
    );
  }
}

class _ReflectionDialog extends StatefulWidget {
  const _ReflectionDialog({required this.quest, required this.rule});

  final Quest quest;
  final ReflectionVerification rule;

  @override
  State<_ReflectionDialog> createState() => _ReflectionDialogState();
}

class _ReflectionDialogState extends State<_ReflectionDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int length = _text.text.trim().length;
    final int min = widget.rule.minCharacters;
    final bool ready = length >= min;
    return _QuestDialog(
      emoji: '🪞',
      title: 'Mikro Yansıma',
      subtitle: widget.quest.effectiveTitle,
      confirmLabel: 'Tamamla',
      confirmEnabled: ready,
      onConfirm: () => Navigator.of(context).pop(true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: AppRadii.mdAll,
            ),
            child: Text(
              '“${widget.rule.prompt}”',
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('verification-reflection-input'),
            controller: _text,
            autofocus: true,
            maxLines: 4,
            maxLength: min * 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Aklında kalanı birkaç cümleyle yaz…',
            ),
          ),
          Row(
            children: <Widget>[
              Icon(
                ready ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 14,
                color: ready ? AppColors.success : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$length / $min karakter',
                style: AppTypography.caption.copyWith(
                  color: ready ? AppColors.success : AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepGoalDialog extends StatefulWidget {
  const _StepGoalDialog({required this.quest, required this.rule});

  final Quest quest;
  final StepGoalVerification rule;

  @override
  State<_StepGoalDialog> createState() => _StepGoalDialogState();
}

class _StepGoalDialogState extends State<_StepGoalDialog> {
  late double _steps = widget.rule.targetSteps.toDouble();

  @override
  Widget build(BuildContext context) {
    final bool ready = _steps >= widget.rule.targetSteps;
    return _QuestDialog(
      emoji: '👟',
      title: 'Adım Hedefi',
      subtitle: widget.quest.effectiveTitle,
      confirmLabel: 'Tamamla',
      confirmEnabled: ready,
      onConfirm: () => Navigator.of(context).pop(true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _steps.round().toString(),
                style: AppTypography.numericLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${widget.rule.targetSteps} adım',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('verification-step-slider'),
            value: _steps,
            min: 0,
            max: widget.rule.targetSteps.toDouble(),
            divisions: 20,
            onChanged: (double value) => setState(() => _steps = value),
          ),
          Text(
            ready
                ? 'Hedefe ulaştın, harika!'
                : 'Hedefe ${(widget.rule.targetSteps - _steps).round()} adım kaldı.',
            style: AppTypography.caption.copyWith(
              color: ready ? AppColors.success : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistDialog extends StatefulWidget {
  const _ChecklistDialog({required this.quest, required this.rule});

  final Quest quest;
  final ChecklistVerification rule;

  @override
  State<_ChecklistDialog> createState() => _ChecklistDialogState();
}

class _ChecklistDialogState extends State<_ChecklistDialog> {
  late final Set<int> _checked = <int>{};

  @override
  Widget build(BuildContext context) {
    final bool ready = _checked.length == widget.rule.items.length;
    return _QuestDialog(
      emoji: '✅',
      title: 'Kontrol Listesi',
      subtitle: '${_checked.length}/${widget.rule.items.length} madde',
      confirmLabel: 'Tamamla',
      confirmEnabled: ready,
      onConfirm: () => Navigator.of(context).pop(true),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < widget.rule.items.length; i++)
            CheckboxListTile(
              key: Key('verification-check-$i'),
              value: _checked.contains(i),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                widget.rule.items[i],
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onChanged: (bool? value) => setState(() {
                if (value ?? false) {
                  _checked.add(i);
                } else {
                  _checked.remove(i);
                }
              }),
            ),
        ],
      ),
    );
  }
}

class _TimerDialog extends StatefulWidget {
  const _TimerDialog({required this.quest, required this.timer});

  final Quest quest;
  final TimerVerification timer;

  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> {
  late int _remaining = widget.timer.minutes * 60;
  Timer? _ticker;
  bool _running = false;

  int get _total => widget.timer.minutes * 60;

  bool get _done => _remaining <= 0;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_done) return;
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      setState(() {
        _remaining = (_remaining - 1).clamp(0, _total);
        if (_remaining == 0) {
          _running = false;
          timer.cancel();
        }
      });
    });
  }

  void _fastDemo() {
    _ticker?.cancel();
    setState(() {
      _remaining = 5;
      _running = false;
    });
    _toggle();
  }

  String get _label {
    final int minutes = _remaining ~/ 60;
    final int seconds = _remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _total == 0 ? 1 : 1 - (_remaining / _total);
    return _QuestDialog(
      emoji: '⏱️',
      title: 'Odak Sayacı',
      subtitle: '${widget.timer.minutes} dk · ${widget.quest.effectiveTitle}',
      confirmLabel: 'Oturumu bitir',
      confirmEnabled: _done,
      onConfirm: () => Navigator.of(context).pop(true),
      onStart: _done ? null : _toggle,
      startLabel: _running
          ? 'Duraklat'
          : (_remaining == _total ? 'Başlat' : 'Devam et'),
      extraAction: _done
          ? null
          : TextButton.icon(
              key: const Key('verification-timer-demo'),
              onPressed: _fastDemo,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.bolt_rounded, size: 15),
              label: const Text('Demo: sayacı 5 saniyeye indir'),
            ),
      child: Column(
        children: <Widget>[
          Center(
            child: SizedBox(
              width: 136,
              height: 136,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 136,
                    height: 136,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _done ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _label,
                        key: const Key('verification-timer-label'),
                        style: AppTypography.numericLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                        ),
                      ),
                      Text(
                        _done ? 'Hazır!' : (_running ? 'Odakta' : 'Bekliyor'),
                        style: AppTypography.caption.copyWith(
                          color: _done
                              ? AppColors.success
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sayaç yalnızca bu ekran açıkken ilerler; kapatırsan oturum '
            'sıfırlanır.',
            textAlign: TextAlign.center,
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
