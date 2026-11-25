import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../birthday/birthday_modal.dart';
import '../settings/settings_screen.dart';
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

  Future<void> _openIdentityQuickSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IdentityQuickSheet(
        owner: ref.read(appSettingsProvider).deviceRole,
        onOpenSettings: () {
          Navigator.of(context).pop();
          showSettingsSheet(context);
        },
      ),
    );
  }

  void _showLockedStatusNotice(BuildContext context, String owner) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Bu telefon ${CouplePalette.nameOf(owner)} adına kilitli. '
            'Partnerinin durumunu değiştirmek için önce cihaz kilidini kapat.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
          _LockedIdentityPill(
            partnerId: settings.deviceRole,
            onTap: () => _openIdentityQuickSheet(context, ref),
          )
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
                  onTap: () {
                    if (settings.lockToDeviceOwner &&
                        id != settings.deviceRole) {
                      _showLockedStatusNotice(context, settings.deviceRole);
                      return;
                    }
                    _pickStatus(context, ref, id);
                  },
                ),
              ),
              if (id != CouplePartner.ids.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _TopBarAction(
              actionKey: const Key('birthday-surprise'),
              emoji: '🎂',
              label: 'Doğum Günü',
              color: CouplePalette.ceyda,
              onTap: () => showBirthdayExperience(context),
            ),
            const SizedBox(width: AppSpacing.sm),
            _TopBarAction(
              actionKey: const Key('topbar-settings'),
              icon: Icons.settings_rounded,
              label: 'Ayarlar',
              color: AppColors.primary,
              onTap: () => showSettingsSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.actionKey,
    required this.label,
    required this.color,
    required this.onTap,
    this.emoji,
    this.icon,
  });

  final Key actionKey;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: color.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          child: InkWell(
            key: actionKey,
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: emoji != null
                  ? Text(emoji!, style: const TextStyle(fontSize: 16))
                  : Icon(
                      icon ?? Icons.settings_rounded,
                      size: 18,
                      color: color,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedIdentityPill extends StatelessWidget {
  const _LockedIdentityPill({required this.partnerId, required this.onTap});

  final String partnerId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    final String other = CouplePartner.other(partnerId);
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        key: const Key('locked-identity-pill'),
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 1,
          ),
          decoration: BoxDecoration(
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
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kilitli kimlik pill'inden açılan hızlı profil değiştirici.
class _IdentityQuickSheet extends ConsumerWidget {
  const _IdentityQuickSheet({
    required this.owner,
    required this.onOpenSettings,
  });

  final String owner;
  final VoidCallback onOpenSettings;

  void _switchTo(BuildContext context, WidgetRef ref, String id) {
    ref.read(appSettingsProvider.notifier).configureDeviceOwner(id);
    ref.read(gameProvider.notifier).switchPartner(id);
    ref.read(gameProvider.notifier).enforceDeviceOwner();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final String current = settings.deviceRole;
    final bool locked = settings.lockToDeviceOwner;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Profil & Cihaz Kimliği',
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Bu telefonun kimin adına çalıştığını seç.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('identity-sheet-close'),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  for (final String id in CouplePartner.ids) ...<Widget>[
                    Expanded(
                      child: _IdentityChoice(
                        key: Key('identity-sheet-$id'),
                        partnerId: id,
                        selected: current == id,
                        onTap: () => _switchTo(context, ref, id),
                      ),
                    ),
                    if (id != CouplePartner.ids.last)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile.adaptive(
                  key: const Key('identity-sheet-lock'),
                  value: locked,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  title: Text(
                    'Bu telefona kilitle',
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    locked
                        ? '${CouplePalette.nameOf(owner)} dışındaki profiller '
                              'kilitli.'
                        : 'Kilidi açıkken iki profil arasında geçiş yapılır.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  onChanged: (bool value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .setLockToDeviceOwner(value);
                    if (value) {
                      ref.read(gameProvider.notifier).enforceDeviceOwner();
                      ref.read(gameProvider.notifier).switchPartner(owner);
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('identity-sheet-settings'),
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Tüm ayarları aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityChoice extends StatelessWidget {
  const _IdentityChoice({
    required this.partnerId,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String partnerId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    return Material(
      color: selected ? accent.withValues(alpha: 0.10) : AppColors.surface,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              PartnerAvatar(partnerId: partnerId, size: 40, showRing: selected),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                '${CouplePalette.nameOf(partnerId)} '
                '${CouplePalette.emojiOf(partnerId)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subtitle.copyWith(
                  color: selected ? accent : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                selected ? 'Bu telefon' : 'Bu profile geç',
                maxLines: 1,
                style: AppTypography.caption.copyWith(
                  color: selected ? accent : AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
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
