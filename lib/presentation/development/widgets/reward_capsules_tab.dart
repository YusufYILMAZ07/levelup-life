import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import 'add_capsule_sheet.dart';
import 'mood_capsules_section.dart';

/// **Kapsüller & Ödüller** alt sekmesi.
///
/// Çiftin birleşik puanı (`combinedPoints`) yükseldikçe kapsüller açılır.
/// Kilit durumu **saklanmaz**, her çizimde puandan türetilir; yalnızca
/// "açıldı" bilgisi kalıcıdır.
class RewardCapsulesTab extends ConsumerWidget {
  const RewardCapsulesTab({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    RewardCapsule capsule,
  ) async {
    final bool opened = ref
        .read(gameProvider.notifier)
        .openRewardCapsule(capsule.id);
    if (!opened) return;
    HapticFeedback.mediumImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapsül',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (BuildContext dialogContext, _, _) =>
          _CapsuleRevealDialog(capsule: capsule),
      transitionBuilder:
          (
            BuildContext transitionContext,
            Animation<double> animation,
            _,
            Widget child,
          ) {
            final Animation<double> eased = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: eased, child: child),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoupleState couple = ref.watch(coupleStateProvider);
    final List<RewardCapsule> capsules = couple.capsulesByThreshold;
    final RewardCapsule? next = couple.nextUnlockedCapsule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CapsuleSummary(
          points: couple.combinedPoints,
          unlocked: couple.unlockedCapsuleCount,
          total: capsules.length,
          next: next,
          onAdd: () => showAddCapsuleSheet(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Kapsül Rafı',
          subtitle: 'Puan dolunca dokun ve ödülünü aç',
          trailing: InfoPill(
            label: '${couple.unlockedCapsuleCount}/${capsules.length}',
            color: AppColors.primary,
            dense: true,
          ),
        ),
        for (final RewardCapsule capsule in capsules)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 1),
            child: _CapsuleCard(
              capsule: capsule,
              points: couple.combinedPoints,
              onOpen: capsule.isUnlockedFor(couple.combinedPoints)
                  ? () => _open(context, ref, capsule)
                  : null,
            ),
          ),
        if (capsules.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Henüz kapsül yok · "Kapsül Ekle" ile ilk ödülünüzü koyun 🎁',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        const MoodCapsulesSection(),
      ],
    );
  }
}

/// Üstteki puan özeti + sıradaki kapsül ilerlemesi.
class _CapsuleSummary extends StatelessWidget {
  const _CapsuleSummary({
    required this.points,
    required this.unlocked,
    required this.total,
    required this.next,
    required this.onAdd,
  });

  final int points;
  final int unlocked;
  final int total;
  final RewardCapsule? next;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final RewardCapsule? target = next;
    final double progress = target?.progressFor(points) ?? 1;
    final int remaining = target?.remainingFor(points) ?? 0;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: AppGradients.aura(AppColors.xp, peakOpacity: 0.16),
      borderColor: AppColors.xp.withValues(alpha: 0.28),
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
                      'Birleşik Gelişim Puanı',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Üst etiket zaten "Birleşik Gelişim Puanı"; satır içi
                    // "puan" tekrarı dar ekranda taşmaya yol açıyordu.
                    Text(
                      '$points',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numericLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.primary,
                borderRadius: AppRadii.pillAll,
                child: InkWell(
                  key: const Key('add-capsule-button'),
                  onTap: onAdd,
                  borderRadius: AppRadii.pillAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Kapsül Ekle',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.xp.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xp),
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            target == null
                ? 'Tüm kapsüller açıldı · yeni bir ödül ekleyin 🎉'
                : '${target.emoji} ${target.title} · $remaining puan kaldı',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$unlocked/$total kapsülün kilidi açık',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek kapsül kartı — kilitli / hazır / açıldı durumlarını çizer.
class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({
    required this.capsule,
    required this.points,
    this.onOpen,
  });

  final RewardCapsule capsule;
  final int points;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = capsule.isUnlockedFor(points);
    final bool opened = capsule.isOpened;
    final double progress = capsule.progressFor(points);
    final int remaining = capsule.remainingFor(points);
    final String status = opened
        ? 'Açıldı · ödülün tadını çıkarın'
        : unlocked
        ? 'Hazır! Dokun ve aç'
        : '$remaining puan kaldı';

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      gradient: opened || !unlocked
          ? null
          : AppGradients.aura(AppColors.success, peakOpacity: 0.14),
      borderColor: opened
          ? AppColors.border
          : unlocked
          ? AppColors.success.withValues(alpha: 0.35)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: opened
                      ? AppColors.success.withValues(alpha: 0.10)
                      : unlocked
                      ? AppColors.xp.withValues(alpha: 0.14)
                      : AppColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  opened ? '✅' : capsule.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            capsule.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (capsule.isCustom) ...<Widget>[
                          const SizedBox(width: 4),
                          InfoPill(
                            label: 'bizim',
                            color: AppColors.primary,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${capsule.thresholdLabel} · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: opened
                            ? AppColors.success
                            : unlocked
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (unlocked && !opened) ...<Widget>[
                const SizedBox(width: AppSpacing.xs + 1),
                Material(
                  color: AppColors.success,
                  borderRadius: AppRadii.pillAll,
                  child: InkWell(
                    key: Key('open-capsule-${capsule.id}'),
                    onTap: onOpen,
                    borderRadius: AppRadii.pillAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: AppSpacing.xs + 1,
                      ),
                      child: Text(
                        'Aç 🎁',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (opened)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                capsule.rewardMessage.isEmpty
                    ? capsule.description
                    : capsule.rewardMessage,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            )
          else ...<Widget>[
            Text(
              capsule.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${points.clamp(0, capsule.requiredPoints)} / '
                    '${capsule.requiredPoints} Puan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '%${(progress * 100).round()}',
                  style: AppTypography.caption.copyWith(
                    color: unlocked
                        ? AppColors.success
                        : AppColors.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: AppRadii.pillAll,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  unlocked ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kapsül açılınca çıkan ödül kutlama modalı.
class _CapsuleRevealDialog extends StatelessWidget {
  const _CapsuleRevealDialog({required this.capsule});

  final RewardCapsule capsule;

  @override
  Widget build(BuildContext context) {
    final String message = capsule.rewardMessage.isEmpty
        ? capsule.description
        : capsule.rewardMessage;

    return Center(
      // Küçük ekran + büyük yazı ölçeğinde içerik taşmasın: kart kaydırılır.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.xp.withValues(alpha: 0.30)),
              boxShadow: AppShadows.floating,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.elasticOut,
                  builder: (BuildContext _, double scale, Widget? child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Text(
                    capsule.emoji,
                    style: const TextStyle(fontSize: 46),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Kapsül Açıldı! 🎉',
                  textAlign: TextAlign.center,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  capsule.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.xp.withValues(alpha: 0.08),
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('capsule-reveal-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm + 2,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.pillAll,
                      ),
                    ),
                    child: Text(
                      'Harika! 💖',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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
