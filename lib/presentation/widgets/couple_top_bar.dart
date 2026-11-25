import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../birthday/birthday_modal.dart';
import 'partner_avatar.dart';

/// Çift sürümünün üst barı.
///
/// * Üstte iki partner segmenti (dokun → o partnerin verisi ekrana gelir).
/// * Altta her iki partnerin **canlı durumu**; dokununca durum seçici açılır.
///
/// Tek oyuncu modunda (onboarding/testler) hiçbir şey çizmez, böylece eski
/// ekranlar bozulmadan çalışır.
class CoupleTopBar extends ConsumerWidget {
  const CoupleTopBar({this.now, super.key});

  final DateTime? now;

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    String partnerId,
  ) async {
    final LiveStatus? picked = await showModalBottomSheet<LiveStatus>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (BuildContext sheetContext) => _LiveStatusSheet(
        partnerId: partnerId,
        current: ref.read(gameProvider).couple.liveStatusOf(partnerId),
      ),
    );
    if (picked == null) return;
    ref.read(gameProvider.notifier).setLiveStatus(picked, partnerId: partnerId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    if (!state.isCoupleEdition) return const SizedBox.shrink();
    final DateTime at = now ?? DateTime.now();
    final AppSettings settings = ref.watch(appSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (settings.lockToDeviceOwner)
          _LockedIdentityPill(partnerId: settings.deviceRole)
        else
          Row(
            children: <Widget>[
              for (final String id in CouplePartner.ids) ...<Widget>[
                Expanded(
                  child: _PartnerSegment(
                    partnerId: id,
                    selected: state.activePartnerId == id,
                    level: state.partnerData(id)?.levelNumber ?? 1,
                    xpToday: state.xpTodayFor(id, at),
                    onTap: () =>
                        ref.read(gameProvider.notifier).switchPartner(id),
                  ),
                ),
                if (id != CouplePartner.ids.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (final String id in CouplePartner.ids) ...<Widget>[
              Expanded(
                child: _LiveStatusPill(
                  partnerId: id,
                  status: state.couple.liveStatusOf(id),
                  onTap: () => _pickStatus(context, ref, id),
                ),
              ),
              if (id != CouplePartner.ids.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: CouplePalette.ceyda.withValues(alpha: 0.08),
            borderRadius: AppRadii.pillAll,
            child: InkWell(
              key: const Key('birthday-surprise'),
              onTap: () => showBirthdayExperience(context),
              borderRadius: AppRadii.pillAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.pillAll,
                  border: Border.all(
                    color: CouplePalette.ceyda.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🎂', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Doğum Günü Sürprizi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: CouplePalette.ceyda,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: CouplePalette.ceyda,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedIdentityPill extends StatelessWidget {
  const _LockedIdentityPill({required this.partnerId});

  final String partnerId;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    final String other = CouplePartner.other(partnerId);
    return Container(
      key: const Key('locked-identity-pill'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 1,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          PartnerAvatar(partnerId: partnerId, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${CouplePalette.nameOf(partnerId)} '
              '${CouplePalette.emojiOf(partnerId)} · '
              '${CouplePalette.nameOf(other)} ile Bağlı 🟢',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(Icons.lock_rounded, size: 14, color: accent),
        ],
      ),
    );
  }
}

class _PartnerSegment extends StatelessWidget {
  const _PartnerSegment({
    required this.partnerId,
    required this.selected,
    required this.level,
    required this.xpToday,
    required this.onTap,
  });

  final String partnerId;
  final bool selected;
  final int level;
  final int xpToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    return Semantics(
      button: true,
      selected: selected,
      label: '${CouplePalette.nameOf(partnerId)} profiline geç',
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.mdAll,
        child: InkWell(
          key: Key('partner-$partnerId'),
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: selected ? CouplePalette.gradientOf(partnerId) : null,
              color: selected ? null : AppColors.surface,
              borderRadius: AppRadii.mdAll,
              border: Border.all(
                color: selected ? accent : AppColors.border,
                width: selected ? 0 : 1,
              ),
              boxShadow: selected
                  ? AppShadows.glow(
                      accent,
                      opacity: 0.24,
                      blur: 16,
                      offset: const Offset(0, 6),
                    )
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.textOnAccent.withValues(alpha: 0.22)
                        : CouplePalette.softOf(partnerId),
                    shape: BoxShape.circle,
                  ),
                  child: PartnerAvatar(partnerId: partnerId, size: 26),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              CouplePalette.nameOf(partnerId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 14,
                                color: selected
                                    ? AppColors.textOnAccent
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Lv$level',
                            style: AppTypography.caption.copyWith(
                              color: selected
                                  ? AppColors.textOnAccent.withValues(
                                      alpha: 0.85,
                                    )
                                  : AppColors.textTertiary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+$xpToday XP bugün',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: selected
                              ? AppColors.textOnAccent.withValues(alpha: 0.9)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
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

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({
    required this.partnerId,
    required this.status,
    required this.onTap,
  });

  final String partnerId;
  final LiveStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.liveStatusColor(status);
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        key: Key('live-status-$partnerId'),
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  status.fullLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatusSheet extends StatelessWidget {
  const _LiveStatusSheet({required this.partnerId, required this.current});

  final String partnerId;
  final LiveStatus current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${CouplePalette.emojiOf(partnerId)} '
                  '${CouplePalette.nameOf(partnerId)} şu an ne yapıyor?',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Seçtiğin durum üst barda partnerine görünür.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          for (final LiveStatus status in LiveStatus.picker)
            ListTile(
              key: Key('status-${status.code}'),
              leading: Text(status.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(
                status.label,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: status == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: CouplePalette.colorOf(partnerId),
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(status),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
