import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../birthday/birthday_modal.dart';
import '../widgets/partner_avatar.dart';
import 'backup_data_page.dart';
import 'cloud_sync_page.dart';
import 'notifications_settings_page.dart';
import 'privacy_pin_page.dart';
import 'profile_identity_page.dart';
import 'settings_sections.dart';

/// Ayarları tam ekran, iOS-tarzı bir sayfa olarak açar.
///
/// `showSettingsSheet` adı geriye dönük uyumluluk için korunur; çağıran
/// ekranlar alt sayfa beklese de artık kök navigator üzerinde tam ekran
/// [SettingsScreen] açılır.
Future<void> showSettingsSheet(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}

/// Profil kartı, hızlı ayarlar ve alt sayfa girişlerini bir arada tutar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Yeniden başlamak istiyor musun?'),
        content: const Text(
          'Tüm XP, seri ve görevler silinir; tanışma sihirbazı yeniden açılır. '
          'Bu işlem geri alınamaz.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Evet, sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Notifier'ı pop'tan **önce** yakala: ayarlar kapandıktan sonra `ref`
    // üzerinden okuma yapmak geçersiz olabilir.
    final GameController controller = ref.read(gameProvider.notifier);
    Navigator.of(context).pop();
    await controller.resetJourney();
  }

  Future<void> _confirmRestartCouple(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Çift sürümü yeniden başlasın mı?'),
        content: const Text(
          'Sohbet, rubrik puanları ve bucket list hazır içerikle yenilenir. '
          'Günlük ilerleme sıfırlanır.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yeniden başlat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final GameController controller = ref.read(gameProvider.notifier);
    Navigator.of(context).pop();
    await controller.restartCoupleJourney();
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final UserProfile? profile = state.profile;
    final String owner = settings.deviceRole;

    return Scaffold(
      key: const Key('settings-screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('settings-close'),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, size: 22),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Ayarlar',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              AppConstants.appBrandLine,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.sm,
                AppSpacing.xxl,
                AppSpacing.huge,
              ),
              children: <Widget>[
                if (profile != null)
                  _SettingsProfileCard(
                    profile: profile,
                    owner: owner,
                    locked: settings.lockToDeviceOwner,
                    onTap: () => _open(context, const ProfileIdentityPage()),
                  )
                else
                  const _MissingProfileCard(),
                const SizedBox(height: AppSpacing.xl),
                _SettingsGroup(
                  title: 'ENERJİ MODU',
                  subtitle: 'Bugünkü kapasitene göre görevler uyarlanır.',
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: const EnergyModePicker(),
                    ),
                    if (state.setup != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          '${state.setup!.goals.length} hedef · '
                          'günde ${state.setup!.dailyQuestTarget} görev · '
                          '${state.setup!.tempo.minutes} dk tempo',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SettingsGroup(
                  title: 'KİŞİSEL',
                  children: <Widget>[
                    _SettingsRow(
                      rowKey: const Key('settings-profile'),
                      icon: Icons.badge_rounded,
                      color: CouplePalette.colorOf(owner),
                      title: 'Profil & Cihaz Kimliği',
                      subtitle:
                          '${CouplePalette.nameOf(owner)} bu telefonda · '
                          'fotoğraf ve cihaz kilidi',
                      onTap: () => _open(context, const ProfileIdentityPage()),
                    ),
                    _SettingsRow(
                      rowKey: const Key('settings-notifications'),
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Bildirimler',
                      subtitle: 'Mesaj, plan ve akşam puanı hatırlatıcıları',
                      onTap: () =>
                          _open(context, const NotificationsSettingsPage()),
                    ),
                    _SettingsRow(
                      rowKey: const Key('settings-privacy'),
                      icon: Icons.lock_rounded,
                      color: AppColors.primary,
                      title: 'Gizlilik & PIN',
                      subtitle: settings.pinLockEnabled
                          ? 'Uygulama kilidi açık'
                          : 'Uygulama kilidi kapalı',
                      onTap: () => _open(context, const PrivacyPinPage()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SettingsGroup(
                  title: 'VERİ',
                  children: <Widget>[
                    _SettingsRow(
                      rowKey: const Key('settings-cloud'),
                      icon: Icons.cloud_sync_rounded,
                      color: const Color(0xFF0EA5E9),
                      title: 'Bulut & Eşitleme',
                      subtitle: 'İki telefon arasında canlı senkronizasyon',
                      onTap: () => _open(context, const CloudSyncPage()),
                    ),
                    _SettingsRow(
                      rowKey: const Key('settings-backup'),
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Yedek & Veri',
                      subtitle: 'Dışa aktar, geri yükle veya temizle',
                      onTap: () => _open(context, const BackupDataPage()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SettingsGroup(
                  title: 'DENEYİM',
                  children: <Widget>[
                    if (state.isCoupleEdition)
                      _SettingsRow(
                        rowKey: const Key('settings-birthday'),
                        icon: Icons.cake_rounded,
                        color: AppColors.streak,
                        title: 'Doğum günü sürprizi',
                        subtitle: 'Mektup, yılın özeti ve aşk notu üretici',
                        onTap: () => showBirthdayExperience(context),
                      ),
                    if (state.isCoupleEdition)
                      _SettingsRow(
                        rowKey: const Key('settings-restart-couple'),
                        icon: Icons.favorite_rounded,
                        color: AppColors.primary,
                        title: 'Çift sürümünü yeniden başlat',
                        subtitle:
                            'Hazır içerik ve tohum verisiyle temiz başlangıç',
                        onTap: () => _confirmRestartCouple(context, ref),
                      ),
                    _SettingsRow(
                      rowKey: const Key('settings-reset'),
                      icon: Icons.restart_alt_rounded,
                      color: AppColors.danger,
                      title: 'Hedeflerimi sıfırla',
                      subtitle:
                          'Tanışma ekranına dön, her şeyi yeniden tanımla',
                      destructive: true,
                      onTap: () => _confirmReset(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
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

class _SettingsProfileCard extends StatelessWidget {
  const _SettingsProfileCard({
    required this.profile,
    required this.owner,
    required this.locked,
    required this.onTap,
  });

  final UserProfile profile;
  final String owner;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(owner);
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.card,
      child: InkWell(
        key: const Key('settings-profile-card'),
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: CouplePalette.auraOf(owner, peak: 0.22),
            borderRadius: AppRadii.card,
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          child: Row(
            children: <Widget>[
              PartnerAvatar(partnerId: owner, size: 56, showRing: true),
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
                    const SizedBox(height: 2),
                    Text(
                      profile.titleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: _MiniPill(
                            icon: Icons.smartphone_rounded,
                            label:
                                '${CouplePalette.nameOf(owner)} bu telefonda',
                            color: accent,
                          ),
                        ),
                        if (locked) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          _MiniPill(
                            icon: Icons.lock_rounded,
                            label: 'Kilitli',
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _LevelBadge(level: profile.levelNumber, color: accent),
                  const SizedBox(height: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
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

class _MissingProfileCard extends StatelessWidget {
  const _MissingProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Profil henüz hazır değil. Tanışma adımlarını tamamlayınca burada '
        'görünecek.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Text(
            title,
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              top: 2,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          )
        else
          const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          borderRadius: AppRadii.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadii.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(height: 1, indent: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.rowKey,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final Key rowKey;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: AppRadii.smAll,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle.copyWith(
                      color: destructive
                          ? AppColors.danger
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(
        'Lv $level',
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
