import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import 'add_schedule_sheet.dart';

/// **Haftalık Plan** alt sekmesi.
///
/// Gün seçici + iki partnerin yan yana zaman çizelgesi + günün ortak boş
/// vakitleri. Bir bloğa dokununca aksiyon sayfası açılır: tamamla (+25 XP),
/// kanıt fotoğrafı gönder veya plandan sil.
class WeeklyPlanTab extends ConsumerStatefulWidget {
  const WeeklyPlanTab({this.now, super.key});

  final DateTime? now;

  @override
  ConsumerState<WeeklyPlanTab> createState() => _WeeklyPlanTabState();
}

class _WeeklyPlanTabState extends ConsumerState<WeeklyPlanTab> {
  late int _weekday = (widget.now ?? DateTime.now()).weekday;

  DateTime get _at => widget.now ?? DateTime.now();

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _complete(ScheduleBlock block) {
    final ScheduleOutcome? outcome = ref
        .read(gameProvider.notifier)
        .completeScheduleBlock(block.id, day: _at);
    if (outcome == null) return;
    if (outcome.alreadyCompleted) {
      _snack('${block.title} bugün zaten tamamlandı ✅');
      return;
    }
    _snack(
      outcome.leveledUp
          ? 'Seviye atladın! ${block.title} · +${outcome.xpGained} XP'
          : '${block.title} tamamlandı · +${outcome.xpGained} XP',
    );
  }

  void _proof(ScheduleBlock block) {
    final ChatMessage? message = ref
        .read(gameProvider.notifier)
        .sendScheduleProof(partnerId: block.partnerId, blockId: block.id);
    _snack(
      message == null
          ? 'Kanıt gönderilemedi 📭'
          : 'Kanıt sohbete gönderildi 📸',
    );
  }

  void _delete(ScheduleBlock block) {
    ref.read(gameProvider.notifier).removeScheduleBlock(block.id);
    _snack('${block.title} plandan kaldırıldı 🗑');
  }

  Future<void> _openActions(ScheduleBlock block) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) =>
          _BlockActionsSheet(block: block, now: _at),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'complete':
        _complete(block);
      case 'proof':
        _proof(block);
      case 'delete':
        _delete(block);
    }
  }

  Future<void> _openAddSheet() =>
      showAddScheduleSheet(context, initialWeekday: _weekday, now: _at);

  @override
  Widget build(BuildContext context) {
    final CoupleState couple = ref.watch(coupleStateProvider);
    final List<String> windows = couple.sharedFreeWindowsForDay(_weekday);
    final FreeWindow? longest = couple.longestSharedFreeWindowForDay(_weekday);
    final bool isToday = _at.weekday == _weekday;
    final String dayLabel = ScheduleBlock.weekdayLong[_weekday - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DaySelector(
          selected: _weekday,
          today: _at.weekday,
          onSelect: (int day) => setState(() => _weekday = day),
        ),
        const SizedBox(height: AppSpacing.md),
        _FreeWindowsBanner(
          windows: windows,
          longest: longest,
          isToday: isToday,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: SectionHeader(
                title: 'Yan Yana Akış',
                subtitle: '$dayLabel · blok → tamamla / kanıt',
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _AddPlanButton(onTap: _openAddSheet),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < CouplePartner.ids.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: _PartnerColumn(
                  partnerId: CouplePartner.ids[i],
                  blocks: couple.blocksForDay(CouplePartner.ids[i], _weekday),
                  now: _at,
                  isToday: isToday,
                  onTapBlock: _openActions,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Partnerin günlük blok kolonu.
class _PartnerColumn extends StatelessWidget {
  const _PartnerColumn({
    required this.partnerId,
    required this.blocks,
    required this.now,
    required this.isToday,
    required this.onTapBlock,
  });

  final String partnerId;
  final List<ScheduleBlock> blocks;
  final DateTime now;
  final bool isToday;
  final ValueChanged<ScheduleBlock> onTapBlock;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    final int completed = blocks
        .where((ScheduleBlock block) => block.isCompletedOn(now))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                CouplePartner.badge(partnerId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$completed/${blocks.length}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 1),
        if (blocks.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Bu gün için plan yok.\n＋ Yeni Plan Ekle ile başla.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                height: 1.3,
              ),
            ),
          )
        else
          for (final ScheduleBlock block in blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ScheduleBlockTile(
                block: block,
                now: now,
                isToday: isToday,
                onTap: () => onTapBlock(block),
              ),
            ),
      ],
    );
  }
}

/// Haftanın yedi günü için kompakt seçici.
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final int selected;
  final int today;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int day = 1; day <= 7; day++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: day == 7 ? 0 : AppSpacing.xs),
              child: _DayChip(
                day: day,
                selected: day == selected,
                isToday: day == today,
                onTap: () => onSelect(day),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color? color = selected ? AppColors.primary : null;
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        key: Key('schedule-day-$day'),
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color:
                  color ??
                  (isToday
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.border),
            ),
          ),
          child: Column(
            children: <Widget>[
              Text(
                ScheduleBlock.weekdayShort[day - 1],
                maxLines: 1,
                style: AppTypography.caption.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isToday
                      ? (selected ? Colors.white : AppColors.primary)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Günün ortak boş vakitlerini gösteren kutu.
class _FreeWindowsBanner extends StatelessWidget {
  const _FreeWindowsBanner({
    required this.windows,
    required this.longest,
    required this.isToday,
  });

  final List<String> windows;
  final FreeWindow? longest;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final bool hasWindows = windows.isNotEmpty;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      gradient: hasWindows
          ? AppGradients.aura(CouplePalette.ceyda, peakOpacity: 0.13)
          : null,
      borderColor: hasWindows
          ? CouplePalette.ceyda.withValues(alpha: 0.20)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('✨', style: TextStyle(fontSize: 13)),
              const SizedBox(width: AppSpacing.xs + 1),
              Expanded(
                child: Text(
                  isToday ? 'Bugün Ortak Boş Vaktimiz' : 'Ortak Boş Vakitler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    color: CouplePalette.ceyda,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InfoPill(
                label: hasWindows ? '${windows.length} pencere' : 'yok',
                color: CouplePalette.ceyda,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          if (!hasWindows)
            Text(
              'Ortak boşluk yok · bir bloğu kısaltarak veya taşıyarak '
              'ikinize yer açın.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs + 1,
              runSpacing: AppSpacing.xs + 1,
              children: <Widget>[
                for (final String window in windows)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: CouplePalette.ceyda.withValues(
                        alpha: window == longest?.label ? 0.16 : 0.08,
                      ),
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      window == longest?.label ? '★ $window' : window,
                      style: AppTypography.caption.copyWith(
                        color: CouplePalette.ceyda,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tek bir plan bloğunun yan yana akıştaki kompakt kartı.
class _ScheduleBlockTile extends StatelessWidget {
  const _ScheduleBlockTile({
    required this.block,
    required this.now,
    required this.isToday,
    required this.onTap,
  });

  final ScheduleBlock block;
  final DateTime now;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = isToday && block.isActiveAt(now);
    final bool completed = block.isCompletedOn(now);
    final Color accent = CouplePalette.colorOf(block.partnerId);
    final Color border = active
        ? accent.withValues(alpha: 0.55)
        : completed
        ? AppColors.success.withValues(alpha: 0.40)
        : AppColors.border;

    return Material(
      color: accent.withValues(alpha: active ? 0.10 : 0.04),
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        key: Key('schedule-block-${block.id}'),
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 2,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: border, width: active ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      block.startLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numeric.copyWith(
                        color: accent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.14),
                        borderRadius: AppRadii.pillAll,
                      ),
                      child: Text(
                        'ŞU AN AKTİF 🔥',
                        maxLines: 1,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (completed)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.success,
                    )
                  else
                    Text(
                      block.endLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                block.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                block.category.fullLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                ),
              ),
              if (active) ...<Widget>[
                const SizedBox(height: AppSpacing.xs + 1),
                ClipRRect(
                  borderRadius: AppRadii.pillAll,
                  child: LinearProgressIndicator(
                    value: block.progressAt(now),
                    minHeight: 3,
                    backgroundColor: accent.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir plan bloğuna dokununca açılan aksiyon sayfası.
class _BlockActionsSheet extends StatelessWidget {
  const _BlockActionsSheet({required this.block, required this.now});

  final ScheduleBlock block;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool completed = block.isCompletedOn(now);
    final Color accent = CouplePalette.colorOf(block.partnerId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                  Text(
                    block.category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          block.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${block.weekdayLabel} · ${block.timeRangeLabel} · '
                          '${block.durationLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (block.locationOrNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs + 1),
                Text(
                  '📍 ${block.locationOrNote}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SheetAction(
                key: const Key('schedule-action-complete'),
                icon: completed
                    ? Icons.undo_rounded
                    : Icons.check_circle_rounded,
                label: completed
                    ? 'Tamamlamayı geri al'
                    : 'Tamamla (+${SchedulePlanner.completionXp} XP)',
                color: completed ? AppColors.textSecondary : AppColors.success,
                onTap: () => Navigator.of(context).pop('complete'),
              ),
              _SheetAction(
                key: const Key('schedule-action-proof'),
                icon: Icons.photo_camera_rounded,
                label: 'Kanıt fotoğrafı gönder',
                color: accent,
                onTap: () => Navigator.of(context).pop('proof'),
              ),
              _SheetAction(
                key: const Key('schedule-action-delete'),
                icon: Icons.delete_outline_rounded,
                label: 'Plandan sil',
                color: AppColors.danger,
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "＋ Yeni Plan Ekle" butonu.
class _AddPlanButton extends StatelessWidget {
  const _AddPlanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        key: const Key('add-schedule-button'),
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                'Yeni Plan Ekle',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
