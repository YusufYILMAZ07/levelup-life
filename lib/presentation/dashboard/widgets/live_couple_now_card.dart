import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../application/shell_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/partner_avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';

/// **"Şu Anda İkimiz"** — iki partnerin anlık durumunu yan yana gösteren
/// canlı kart.
///
/// * Aktif plan bloğu varsa: kategori rozeti, başlık, saat aralığı, canlı
///   ilerleme çubuğu ve tek dokunuşluk **Tamamla (+25 XP)** / **Kanıt At**.
/// * Yoksa: canlı durum + sıradaki plan (`14:00 Sporda`).
/// * Altta: günün en uzun ortak boş vakti ve haftalık plan kısayolu.
class LiveCoupleNowCard extends ConsumerWidget {
  const LiveCoupleNowCard({this.now, super.key});

  final DateTime? now;

  void _complete(BuildContext context, WidgetRef ref, ScheduleBlock block) {
    final ScheduleOutcome? outcome = ref
        .read(gameProvider.notifier)
        .completeScheduleBlock(block.id, day: now);
    if (outcome == null) return;
    final String message;
    if (outcome.alreadyCompleted) {
      message = '${block.title} bugün zaten tamamlandı ✅';
    } else if (outcome.leveledUp) {
      message = 'Seviye atladın! ${block.title} · +${outcome.xpGained} XP';
    } else {
      message = '${block.title} tamamlandı · +${outcome.xpGained} XP';
    }
    _snack(context, message);
  }

  void _sendProof(BuildContext context, WidgetRef ref, String partnerId) {
    final ChatMessage? message = ref
        .read(gameProvider.notifier)
        .sendScheduleProof(partnerId: partnerId);
    _snack(
      context,
      message == null
          ? 'Kanıt için plan bulunamadı 📭'
          : 'Kanıt sohbete gönderildi 📸',
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoupleState couple = ref.watch(coupleStateProvider);
    final DateTime at = now ?? DateTime.now();
    final FreeWindow? free = couple.longestSharedFreeWindowForDay(at.weekday);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      gradient: AppGradients.aura(CouplePalette.ceyda, peakOpacity: 0.10),
      borderColor: CouplePalette.ceyda.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Şu Anda İkimiz',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InfoPill(
                label: free == null
                    ? 'Ortak boşluk yok'
                    : 'Ortak boşluk ${free.durationLabel}',
                color: CouplePalette.ceyda,
                icon: Icons.favorite_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _PartnerNowPanel(
                    partnerId: CouplePartner.yusufId,
                    now: at,
                    active: couple.currentBlockFor(CouplePartner.yusufId, at),
                    next: couple.nextBlockFor(CouplePartner.yusufId, at),
                    liveStatus: couple.liveStatusOf(CouplePartner.yusufId),
                    onComplete: (ScheduleBlock block) =>
                        _complete(context, ref, block),
                    onProof: () =>
                        _sendProof(context, ref, CouplePartner.yusufId),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  color: AppColors.border,
                ),
                Expanded(
                  child: _PartnerNowPanel(
                    partnerId: CouplePartner.ceydaId,
                    now: at,
                    active: couple.currentBlockFor(CouplePartner.ceydaId, at),
                    next: couple.nextBlockFor(CouplePartner.ceydaId, at),
                    liveStatus: couple.liveStatusOf(CouplePartner.ceydaId),
                    onComplete: (ScheduleBlock block) =>
                        _complete(context, ref, block),
                    onProof: () =>
                        _sendProof(context, ref, CouplePartner.ceydaId),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SharedFreePill(window: free),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('open-weekly-plan'),
              onPressed: () =>
                  ref.read(shellTabProvider.notifier).goToDevelopment(),
              icon: const Icon(Icons.calendar_month_rounded, size: 15),
              label: const Text('Tüm Haftalık Planı Gör'),
              style: TextButton.styleFrom(
                foregroundColor: CouplePalette.ceyda,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                textStyle: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek partnerin canlı paneli (sol: Yusuf, sağ: Ceyda).
class _PartnerNowPanel extends StatelessWidget {
  const _PartnerNowPanel({
    required this.partnerId,
    required this.now,
    required this.active,
    required this.next,
    required this.liveStatus,
    required this.onComplete,
    required this.onProof,
  });

  final String partnerId;
  final DateTime now;
  final ScheduleBlock? active;
  final ScheduleBlock? next;
  final LiveStatus liveStatus;
  final ValueChanged<ScheduleBlock> onComplete;
  final VoidCallback onProof;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    final ScheduleBlock? block = active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            PartnerAvatar(partnerId: partnerId, size: 24),
            const SizedBox(width: AppSpacing.xs + 2),
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
            if (block != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 1,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadii.pillAll,
                ),
                child: Text(
                  'CANLI',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (block == null)
          _IdleBody(accent: accent, liveStatus: liveStatus, next: next)
        else
          _ActiveBody(
            block: block,
            now: now,
            completed: block.isCompletedOn(now),
            onComplete: () => onComplete(block),
            onProof: onProof,
          ),
      ],
    );
  }
}

/// Aktif plan bloğu varken gösterilen gövde.
class _ActiveBody extends StatelessWidget {
  const _ActiveBody({
    required this.block,
    required this.now,
    required this.completed,
    required this.onComplete,
    required this.onProof,
  });

  final ScheduleBlock block;
  final DateTime now;
  final bool completed;
  final VoidCallback onComplete;
  final VoidCallback onProof;

  String get _remainingLabel {
    final int minutes = block.remainingMinutesAt(now);
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int rest = minutes % 60;
      return rest == 0 ? '$hours sa kaldı' : '$hours sa $rest dk kaldı';
    }
    return '$minutes dk kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(block.partnerId);
    final double progress = block.progressAt(now).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          block.category.fullLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          block.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${block.timeRangeLabel} · ${block.durationLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 1),
        ClipRRect(
          borderRadius: AppRadii.pillAll,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          completed ? 'Bugün tamamlandı 🎉' : _remainingLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: completed ? AppColors.success : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 1),
        Wrap(
          spacing: AppSpacing.xs + 1,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (!completed)
              _NowAction(
                key: Key('complete-schedule-${block.id}'),
                label: '✅ Tamamla (+25 XP)',
                color: accent,
                onTap: onComplete,
              ),
            _NowAction(
              key: Key('proof-schedule-${block.id}'),
              label: '📸 Kanıt At',
              color: accent,
              filled: false,
              onTap: onProof,
            ),
          ],
        ),
      ],
    );
  }
}

/// Aktif plan yokken: canlı durum + sıradaki plan.
class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.accent,
    required this.liveStatus,
    required this.next,
  });

  final Color accent;
  final LiveStatus liveStatus;
  final ScheduleBlock? next;

  @override
  Widget build(BuildContext context) {
    final ScheduleBlock? upcoming = next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InfoPill(
          label: liveStatus.fullLabel,
          color: accent,
          icon: Icons.circle,
          iconSize: 6,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.xs + 1),
        Text(
          upcoming == null
              ? 'Bugün için plan kalmadı 🌙'
              : 'Sıradaki: ${upcoming.startLabel} · '
                    '${upcoming.category.emoji} ${upcoming.category.shortLabel}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Günün en uzun ortak boş vaktini gösteren ince şerit.
class _SharedFreePill extends StatelessWidget {
  const _SharedFreePill({required this.window});

  final FreeWindow? window;

  @override
  Widget build(BuildContext context) {
    final FreeWindow? free = window;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: CouplePalette.ceyda.withValues(alpha: 0.07),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: CouplePalette.ceyda.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          const Text('✨', style: TextStyle(fontSize: 12)),
          const SizedBox(width: AppSpacing.xs + 1),
          Expanded(
            child: Text(
              'Bugün Ortak Boş Vaktimiz',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: CouplePalette.ceyda,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            free == null ? 'yok' : '${free.label} · ${free.durationLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Canlı karttaki küçük, tek dokunuşluk aksiyon hapı.
class _NowAction extends StatelessWidget {
  const _NowAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = true,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: filled ? Colors.white : color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
