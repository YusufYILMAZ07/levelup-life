import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../widgets/partner_avatar.dart';
import '../widgets/section_header.dart';
import 'settings_page_scaffold.dart';
import 'settings_sections.dart';

/// "Profil & Cihaz Kimliği" tam ekran sayfası.
///
/// İki telefonlu kurulumda bu sayfa hangi telefonun kimin adına çalıştığını
/// gösterir; profil değiştirme, cihaz kilidi ve fotoğraflar tek yerde toplanır.
class ProfileIdentityPage extends ConsumerWidget {
  const ProfileIdentityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final GameState state = ref.watch(gameProvider);
    final UserProfile? profile = state.profile;
    final String owner = settings.deviceRole;

    return SettingsPageScaffold(
      pageKey: const Key('profile-identity-page'),
      backKey: const Key('identity-back'),
      title: 'Profil & Cihaz Kimliği',
      subtitle: 'Bu telefonun kimin adına çalıştığını yönet.',
      children: <Widget>[
        if (profile != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: CouplePalette.auraOf(owner, peak: 0.18),
              borderRadius: AppRadii.card,
              border: Border.all(
                color: CouplePalette.colorOf(owner).withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: <Widget>[
                PartnerAvatar(partnerId: owner, size: 52, showRing: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        state.setup?.trackLabel ?? 'Kişisel yolculuk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                InfoPill(
                  label: 'Lv ${profile.levelNumber}',
                  color: CouplePalette.colorOf(owner),
                  icon: Icons.military_tech_rounded,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        const _QuickIdentitySwitch(),
        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        const DeviceIdentitySection(),
        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        const ProfilePhotoSection(),
      ],
    );
  }
}

/// Yusuf ⇄ Ceyda hızlı geçişi — cihaz sahibini tek dokunuşla değiştirir.
class _QuickIdentitySwitch extends ConsumerWidget {
  const _QuickIdentitySwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Hızlı profil geçişi',
          subtitle:
              'Yanlış isimle mesaj veya puan girilmesin diye aktif '
              'profili buradan değiştir.',
        ),
        Row(
          children: <Widget>[
            for (final String id in CouplePartner.ids) ...<Widget>[
              Expanded(
                child: _QuickIdentityTile(
                  key: Key('identity-quick-$id'),
                  partnerId: id,
                  selected: settings.deviceRole == id,
                  locked: settings.lockToDeviceOwner,
                  onTap: () {
                    if (settings.lockToDeviceOwner &&
                        settings.deviceRole != id) {
                      _showLockedNotice(context, settings.deviceRole);
                      return;
                    }
                    ref.read(appSettingsProvider.notifier).setDeviceRole(id);
                    ref.read(gameProvider.notifier).switchPartner(id);
                  },
                ),
              ),
              if (id != CouplePartner.ids.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }

  void _showLockedNotice(BuildContext context, String owner) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Cihaz kilidi açık. Önce aşağıdan kilidi kapat, sonra '
            '${CouplePalette.nameOf(CouplePartner.other(owner))} profiline geç.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

class _QuickIdentityTile extends StatelessWidget {
  const _QuickIdentityTile({
    required this.partnerId,
    required this.selected,
    required this.locked,
    required this.onTap,
    super.key,
  });

  final String partnerId;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(partnerId);
    return Material(
      color: selected ? accent.withValues(alpha: 0.10) : AppColors.surfaceMuted,
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
              PartnerAvatar(partnerId: partnerId, size: 42, showRing: selected),
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
              const SizedBox(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : locked
                        ? Icons.lock_outline_rounded
                        : Icons.touch_app_rounded,
                    size: 12,
                    color: selected ? accent : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      selected ? 'Bu telefon' : 'Bu profile geç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: selected ? accent : AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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
