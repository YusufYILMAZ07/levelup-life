import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';

/// "Yeni Plan" alt sayfasını açar.
///
/// `initialWeekday` seçili günü önceden doldurur; `now` testlerde zamanı
/// sabitlemek için kullanılır (blok id'leri bu andan üretilir).
Future<void> showAddScheduleSheet(
  BuildContext context, {
  required int initialWeekday,
  DateTime? now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) =>
        _AddScheduleSheet(initialWeekday: initialWeekday, now: now),
  );
}

class _AddScheduleSheet extends ConsumerStatefulWidget {
  const _AddScheduleSheet({required this.initialWeekday, this.now});

  final int initialWeekday;
  final DateTime? now;

  @override
  ConsumerState<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends ConsumerState<_AddScheduleSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  late int _weekday = widget.initialWeekday.clamp(1, 7);
  String _target = CouplePartner.yusufId;
  ScheduleCategory _category = ScheduleCategory.study;
  int _start = 9 * 60;
  int _end = 10 * 60;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty && _end > _start;

  Future<void> _pickTime({required bool isStart}) async {
    final int current = isStart ? _start : _end;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (BuildContext pickerContext, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          pickerContext,
        ).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    final int minutes = (picked.hour * 60 + picked.minute).clamp(0, 24 * 60);
    setState(() {
      if (isStart) {
        _start = minutes.clamp(0, 24 * 60 - 1);
        if (_end <= _start) _end = (_start + 60).clamp(1, 24 * 60);
      } else {
        _end = minutes.clamp(1, 24 * 60);
        if (_end <= _start) _start = (_end - 60).clamp(0, 24 * 60 - 1);
      }
    });
  }

  void _save() {
    if (!_valid) return;
    final DateTime at = widget.now ?? DateTime.now();
    final String title = _title.text.trim();
    final String note = _note.text.trim();

    ScheduleBlock make(String partnerId, DateTime stamp) =>
        ScheduleBlock.create(
          partnerId: partnerId,
          weekday: _weekday,
          startMinutes: _start,
          endMinutes: _end,
          title: title,
          category: _category,
          locationOrNote: note,
          now: stamp,
        );

    final List<ScheduleBlock> blocks = <ScheduleBlock>[
      make(_target == 'both' ? CouplePartner.yusufId : _target, at),
      if (_target == 'both')
        make(CouplePartner.ceydaId, at.add(const Duration(microseconds: 1))),
    ];

    final int added = ref.read(gameProvider.notifier).addScheduleBlocks(blocks);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Plan eklenemedi 😕'
                : '$title eklendi · ${ScheduleBlock.weekdayLong[_weekday - 1]} '
                      '${ScheduleBlock.clock(_start)}',
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
                      'Yeni Plan',
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
              const _FieldLabel('Kim için?'),
              const SizedBox(height: AppSpacing.xs + 1),
              Row(
                children: <Widget>[
                  for (final String id in CouplePartner.ids) ...<Widget>[
                    Expanded(
                      child: _ChoiceChip(
                        key: Key('schedule-target-$id'),
                        label: CouplePartner.badge(id),
                        selected: _target == id,
                        color: CouplePalette.colorOf(id),
                        onTap: () => setState(() => _target = id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 1),
                  ],
                  Expanded(
                    child: _ChoiceChip(
                      key: const Key('schedule-target-both'),
                      label: 'İkimiz 💑',
                      selected: _target == 'both',
                      color: AppColors.primary,
                      onTap: () => setState(() => _target = 'both'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _FieldLabel('Gün'),
              const SizedBox(height: AppSpacing.xs + 1),
              Wrap(
                spacing: AppSpacing.xs + 1,
                runSpacing: AppSpacing.xs + 1,
                children: <Widget>[
                  for (int day = 1; day <= 7; day++)
                    SizedBox(
                      width: 44,
                      child: _ChoiceChip(
                        key: Key('schedule-form-day-$day'),
                        label: ScheduleBlock.weekdayShort[day - 1],
                        selected: _weekday == day,
                        color: AppColors.primary,
                        dense: true,
                        onTap: () => setState(() => _weekday = day),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              const _FieldLabel('Ne yapacaksın?'),
              const SizedBox(height: AppSpacing.xs + 1),
              TextField(
                key: const Key('schedule-title-field'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _inputDecoration('Örn. Veri Yapıları dersi'),
              ),
              const SizedBox(height: AppSpacing.md),
              const _FieldLabel('Kategori'),
              const SizedBox(height: AppSpacing.xs + 1),
              Wrap(
                spacing: AppSpacing.xs + 1,
                runSpacing: AppSpacing.xs + 1,
                children: <Widget>[
                  for (final ScheduleCategory category
                      in ScheduleCategory.picker)
                    _ChoiceChip(
                      key: Key('schedule-category-${category.code}'),
                      label: category.fullLabel,
                      selected: _category == category,
                      color: category.stat.color,
                      dense: true,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _FieldLabel('Saat'),
              const SizedBox(height: AppSpacing.xs + 1),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeButton(
                      key: const Key('schedule-start-time'),
                      label: 'Başlangıç',
                      value: ScheduleBlock.clock(_start),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TimeButton(
                      key: const Key('schedule-end-time'),
                      label: 'Bitiş',
                      value: ScheduleBlock.clock(_end),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(_end - _start).clamp(0, 24 * 60)} dk · '
                'bitiş başlangıçtan sonra olmalı',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _FieldLabel('Not / Yer (opsiyonel)'),
              const SizedBox(height: AppSpacing.xs + 1),
              TextField(
                key: const Key('schedule-note-field'),
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _inputDecoration('Mühendislik Fak. · B-204'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('schedule-save-button'),
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
                    'Plana Ekle',
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

  InputDecoration _inputDecoration(String hint) => InputDecoration(
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.dense = false,
    super.key,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.surfaceMuted,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.sm : AppSpacing.sm + 2,
            vertical: dense ? 6 : AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 1,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.numeric.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
