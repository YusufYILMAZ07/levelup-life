import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/game_controller.dart';
import '../../../application/game_state.dart';
import '../../../application/pin_lock_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../services/app_settings.dart';
import '../../../services/backup_service.dart';
import '../../../services/biometric_service.dart';
import '../../../services/cloud_sync_coordinator.dart';
import '../../../services/media_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_service.dart';
import '../../../services/supabase_sync_service.dart';
import '../../birthday/birthday_modal.dart';
import '../../onboarding/widgets/grade_selector.dart';
import '../../widgets/in_app_notification_banner.dart';
import '../../widgets/partner_avatar.dart';
import '../../widgets/section_header.dart';

/// Profil / ayarlar bottom sheet'i.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

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
    // Notifier'ı pop'tan **önce** yakala: sayfa kapandıktan sonra `ref`/context
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final UserProfile? profile = state.profile;
    final UserSetup? setup = state.setup;
    if (profile == null || setup == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                InitialsAvatar(name: profile.displayName, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.displayName,
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${setup.trackLabel} · ${profile.titleLabel}',
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
                  color: AppColors.primary,
                  icon: Icons.military_tech_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _DeviceIdentitySettings(),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'Enerji modu',
              subtitle: 'Bugünkü kapasitene göre görevler uyarlanır.',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final EnergyMode mode in EnergyMode.values)
                  _EnergyOption(
                    mode: mode,
                    selected: profile.energyMode == mode,
                    onTap: () =>
                        ref.read(gameProvider.notifier).setEnergyMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.track_changes_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${setup.goals.length} hedef · '
                      'günde ${setup.dailyQuestTarget} görev · '
                      '${setup.tempo.minutes} dk tempo',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.isCoupleEdition) ...<Widget>[
              ListTile(
                key: const Key('settings-birthday'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.streak.withValues(alpha: 0.12),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: const Icon(
                    Icons.cake_rounded,
                    color: AppColors.streak,
                    size: 21,
                  ),
                ),
                title: Text(
                  'Doğum günü sürprizi',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Mektup, yılın özeti ve aşk notu üretici.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  showBirthdayExperience(context);
                },
              ),
              ListTile(
                key: const Key('settings-restart-couple'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Çift sürümünü yeniden başlat',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Hazır içerik ve tohum verisiyle temiz başlangıç.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: () => _confirmRestartCouple(context, ref),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: AppRadii.smAll,
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: AppColors.danger,
                  size: 21,
                ),
              ),
              title: Text(
                'Hedeflerimi sıfırla',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Tanışma ekranına dön, her şeyi yeniden tanımla.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
              onTap: () => _confirmReset(context, ref),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _ProfilePhotoSettings(),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _NotificationSettings(),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _PrivacySettings(),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _BackupSettings(),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const _CloudSyncSettings(),
          ],
        ),
      ),
    );
  }
}

class _EnergyOption extends StatelessWidget {
  const _EnergyOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final EnergyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = mode.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 1,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(mode.icon, size: 15, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                mode.label,
                style: AppTypography.caption.copyWith(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceIdentitySettings extends ConsumerWidget {
  const _DeviceIdentitySettings();

  void _choose(WidgetRef ref, String partnerId) {
    ref.read(appSettingsProvider.notifier).configureDeviceOwner(partnerId);
    ref.read(gameProvider.notifier).enforceDeviceOwner();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final String owner = settings.deviceRole;
    final String partner = CouplePartner.other(owner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: '📱 Bu Telefon Kimin?',
          subtitle:
              'Her iPhone kendi sahibiyle açılır; yanlış isimle mesaj veya '
              'puan girilmez.',
        ),
        if (!settings.deviceOwnerConfigured)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: AppRadii.mdAll,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              'İlk kurulum: Bu telefonu bir kez seç. Sonra istediğin zaman '
              'aşağıdan değiştirebilirsin 💞',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        Row(
          children: <Widget>[
            for (final String id in CouplePartner.ids) ...<Widget>[
              Expanded(
                child: _RoleChip(
                  key: Key('device-owner-$id'),
                  partnerId: id,
                  selected: owner == id,
                  onTap: () => _choose(ref, id),
                ),
              ),
              if (id != CouplePartner.ids.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: const Key('device-identity-pill'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Text(
                CouplePalette.emojiOf(owner),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${CouplePalette.nameOf(owner)} · '
                  '${CouplePalette.nameOf(partner)} ile Bağlı 🟢',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          key: const Key('device-test-mode'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: const Icon(
            Icons.science_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Tek Cihaz Test Modu (Profil Değiştirmeyi Aç)',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            settings.lockToDeviceOwner
                ? 'Kapalı · bu telefon $owner profiline kilitli'
                : 'Açık · üst bardan Yusuf ⇄ Ceyda geçişi yapılabilir',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          value: !settings.lockToDeviceOwner,
          onChanged: (bool enabled) => ref
              .read(appSettingsProvider.notifier)
              .setLockToDeviceOwner(!enabled),
        ),
      ],
    );
  }
}

class _ProfilePhotoSettings extends ConsumerWidget {
  const _ProfilePhotoSettings();

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    String partnerId,
  ) async {
    try {
      final AppSettings settings = ref.read(appSettingsProvider);
      final PickedMedia? picked = await MediaService().pickAvatar(
        allowCloudUpload: settings.isCloudConfigured,
      );
      if (picked == null) return;
      String source = picked.source;
      final Uint8List? bytes = picked.bytes;
      if (bytes != null &&
          (source.isEmpty || source.startsWith('data:')) &&
          settings.isCloudConfigured) {
        // Web: 250 KB üstü avatar base64 gömülmez; Supabase Storage'a yüklenir.
        final String? uploaded = await ref
            .read(cloudSyncProvider)
            .uploadMediaBytes(
              bytes: bytes,
              fileName: picked.uploadFileName,
              contentType: picked.contentType,
            );
        if (uploaded != null) source = uploaded;
      }
      if (!context.mounted) return;
      if (source.trim().isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('☁️ Fotoğraf yüklenemedi · bağlantıyı kontrol et.'),
            ),
          );
        return;
      }
      ref.read(appSettingsProvider.notifier).setAvatar(partnerId, source);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı güncellendi 🌸'),
            duration: Duration(seconds: 2),
          ),
        );
    } on MediaPickException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Profil fotoğrafları',
          subtitle: 'Sohbette ve üst barda gerçek fotoğraflarınız görünür.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (final String id in CouplePartner.ids) ...<Widget>[
              Expanded(
                child: _AvatarTile(
                  partnerId: id,
                  source: settings.avatarOf(id),
                  onPick: () => _pick(context, ref, id),
                  onRemove: () =>
                      ref.read(appSettingsProvider.notifier).clearAvatar(id),
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
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.partnerId,
    required this.source,
    required this.onPick,
    required this.onRemove,
  });

  final String partnerId;
  final String source;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        key: Key('avatar-$partnerId'),
        onTap: onPick,
        borderRadius: AppRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              PartnerAvatar(partnerId: partnerId, size: 56, showRing: true),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                CouplePalette.nameOf(partnerId),
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                source.trim().isEmpty ? 'Fotoğraf seç' : 'Değiştir',
                style: AppTypography.caption.copyWith(
                  color: CouplePalette.colorOf(partnerId),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
              if (source.trim().isNotEmpty)
                TextButton(
                  key: Key('avatar-clear-$partnerId'),
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Kaldır',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
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

class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

  Future<void> _pickCheckinTime(BuildContext context, WidgetRef ref) async {
    final AppSettings settings = ref.read(appSettingsProvider);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyCheckinHour,
        minute: settings.dailyCheckinMinute,
      ),
      helpText: 'Akşam puanı hatırlatma saati',
    );
    if (picked == null || !context.mounted) return;
    ref
        .read(appSettingsProvider.notifier)
        .setDailyCheckinTime(hour: picked.hour, minute: picked.minute);
  }

  Future<void> _pickQuietRange(BuildContext context, WidgetRef ref) async {
    final AppSettings settings = ref.read(appSettingsProvider);
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.quietStartMinutes ~/ 60,
        minute: settings.quietStartMinutes % 60,
      ),
      helpText: 'Sessiz saatler başlangıcı',
    );
    if (start == null || !context.mounted) return;
    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.quietEndMinutes ~/ 60,
        minute: settings.quietEndMinutes % 60,
      ),
      helpText: 'Sessiz saatler bitişi',
    );
    if (end == null || !context.mounted) return;
    ref
        .read(appSettingsProvider.notifier)
        .setDoNotDisturb(
          enabled: true,
          startMinutes: start.hour * 60 + start.minute,
          endMinutes: end.hour * 60 + end.minute,
        );
  }

  Future<void> _sendTest(BuildContext context) async {
    // Her platformda anında görünen iOS-tarzı floating banner.
    InAppNotificationCenter.instance.show(
      title: 'Ceyda 🌸',
      body: 'Sana örnek bir mesaj gönderdi · bildirimler hazır 💞',
      emoji: '🌸',
      kind: InAppNotificationKind.test,
      payload: 'test',
    );
    final bool ok = await NotificationService.instance.showTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '🔔 Floating banner + OS bildirimi gönderildi'
                : 'Floating banner hazır · OS bildirimi bu cihazda kapalı '
                      '(Web / izin yok).',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final AppSettingsController controller = ref.read(
      appSettingsProvider.notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Bildirimler',
          subtitle: 'Kilit ekranında gerçek bildirimler · izin istenir.',
        ),
        _ToggleTile(
          key: const Key('notif-messages'),
          icon: Icons.chat_bubble_rounded,
          title: 'Mesaj Bildirimleri',
          subtitle: 'Yeni mesaj, fotoğraf, video ve dürtmeler',
          value: settings.messageNotifications,
          onChanged: controller.setMessageNotifications,
        ),
        _ToggleTile(
          key: const Key('notif-plan'),
          icon: Icons.alarm_rounded,
          title: 'Plan Başlangıç Hatırlatıcısı',
          subtitle: 'Her plan bloğundan 10 dakika önce',
          value: settings.planReminders,
          onChanged: controller.setPlanReminders,
        ),
        _ToggleTile(
          key: const Key('notif-checkin'),
          icon: Icons.nightlight_round,
          title: 'Akşam Puanlama Hatırlatıcısı',
          subtitle: 'Her akşam ${settings.dailyCheckinLabel} · 1-2-3 puanları',
          value: settings.dailyCheckinReminder,
          onChanged: controller.setDailyCheckinReminder,
        ),
        ListTile(
          key: const Key('notif-checkin-time'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(
            Icons.schedule_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Check-in saati',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            settings.dailyCheckinLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
          onTap: () => _pickCheckinTime(context, ref),
        ),
        _ToggleTile(
          key: const Key('notif-dnd'),
          icon: Icons.do_not_disturb_on_rounded,
          title: 'Sessiz Saatler (DND)',
          subtitle: '${settings.quietHoursLabel} · bildirim gönderilmez',
          value: settings.doNotDisturbEnabled,
          onChanged: (bool value) => controller.setDoNotDisturb(enabled: value),
        ),
        if (settings.doNotDisturbEnabled)
          ListTile(
            key: const Key('notif-dnd-range'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              Icons.bedtime_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            title: Text(
              'Sessiz aralık',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              settings.quietHoursLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
            onTap: () => _pickQuietRange(context, ref),
          ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          key: const Key('notif-test'),
          onPressed: () => _sendTest(context),
          icon: const Icon(Icons.notifications_active_rounded, size: 18),
          label: const Text('🔔 Örnek Partner Mesajı Bildirimi Test Et'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _PushSettings(),
        const SizedBox(height: AppSpacing.lg),
        const _NotificationHealthPanel(),
      ],
    );
  }
}

class _PushSettings extends ConsumerStatefulWidget {
  const _PushSettings();

  @override
  ConsumerState<_PushSettings> createState() => _PushSettingsState();
}

class _PushSettingsState extends ConsumerState<_PushSettings> {
  late final TextEditingController _appId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = ref.read(appSettingsProvider);
    _appId = TextEditingController(text: settings.oneSignalAppId);
  }

  @override
  void dispose() {
    _appId.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    ref.read(appSettingsProvider.notifier).savePushConfig(appId: _appId.text);
    final bool ok = await PushService.instance.initialize(
      ref.read(appSettingsProvider),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(
      ok
          ? 'OneSignal hazır · kapalıyken de bildirimler açık 🔔'
          : 'Ayar kaydedildi · OneSignal başlatılamadı (Web/test olabilir).',
    );
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final PushResult result = await PushService.instance.sendTest(
      ref.read(appSettingsProvider),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '🔔 Kapalıyken de Bildirim (OneSignal Push)',
          subtitle:
              'Uygulama kapalıyken bile partnerine ulaş. Yalnızca App ID '
              'gerekir; REST anahtarı Supabase Edge Function’da saklanır.',
          trailing: InfoPill(
            label: settings.isPushConfigured ? 'Hazır' : 'Kurulmadı',
            color: settings.isPushConfigured
                ? AppColors.success
                : AppColors.textTertiary,
            dense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CloudField(
          key: const Key('onesignal-app-id'),
          controller: _appId,
          label: 'OneSignal App ID',
          hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.icon(
              key: const Key('onesignal-save'),
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.lock_rounded, size: 16),
              label: Text(_busy ? 'Kaydediliyor…' : 'Push’u Etkinleştir'),
            ),
            OutlinedButton.icon(
              key: const Key('onesignal-test'),
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('🚀 OneSignal Push Testi Gönder'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'iOS’ta gerçek teslimat için OneSignal paneline APNs anahtarını '
          'eklemen gerekir. REST anahtarı yalnızca bu cihazda saklanır.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Tek ekranda bildirim & senkron sağlığını gösteren üretim paneli.
class _NotificationHealthPanel extends ConsumerStatefulWidget {
  const _NotificationHealthPanel();

  @override
  ConsumerState<_NotificationHealthPanel> createState() =>
      _NotificationHealthPanelState();
}

class _NotificationHealthPanelState
    extends ConsumerState<_NotificationHealthPanel> {
  bool _busy = false;
  bool _testBusy = false;
  bool _localPermission = false;
  PushDiagnostics? _diagnostics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _busy = true);
    final AppSettings settings = ref.read(appSettingsProvider);
    // Widget testlerinde / platform kanalı yokken spinner sonsuza kadar
    // dönmesin: her tanı çağrısı kısa timeout ile güvenli varsayılana düşer.
    final bool local = await NotificationService.instance
        .hasPermission()
        .timeout(const Duration(seconds: 2), onTimeout: () => false);
    final PushDiagnostics diagnostics = await PushService.instance
        .refreshDiagnostics(settings)
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => PushDiagnostics(
            initialized: false,
            permissionGranted: false,
            externalId: PushService.externalIdFor(settings),
            expectedExternalId: PushService.externalIdFor(settings),
            subscriptionId: null,
            lastError: 'Tanı zaman aşımı',
          ),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _localPermission = local;
      _diagnostics = diagnostics;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    await NotificationService.instance.requestPermissions();
    await PushService.instance.initialize(ref.read(appSettingsProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  Future<void> _sendTest() async {
    setState(() => _testBusy = true);
    final PushResult result = await PushService.instance.sendTest(
      ref.read(appSettingsProvider),
    );
    ref.read(pushHealthProvider.notifier).set(result);
    if (!mounted) return;
    setState(() => _testBusy = false);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final SyncStatusInfo sync = ref.watch(syncStatusProvider);
    final CloudSyncCoordinator cloud = ref.watch(cloudSyncProvider);
    final int pending = cloud.pendingMessageCount;
    final int pendingDeletes = cloud.pendingDeleteCount;
    final PushDiagnostics? diagnostics = _diagnostics;
    final PushResult? lastPush = ref.watch(pushHealthProvider);
    final String identity =
        diagnostics?.externalId ??
        PushService.externalIdFor(settings) ??
        'Oda kodu bekleniyor';
    final bool identityOk = diagnostics?.identityMatches ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '🩺 Bildirim & Senkron Sağlık Paneli',
          subtitle:
              'Yerel izin, OneSignal kimliği, Supabase üyeliği ve çevrimdışı '
              'kuyruğu tek bakışta.',
          trailing: IconButton(
            key: const Key('health-refresh'),
            tooltip: 'Yenile',
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
          ),
        ),
        _HealthRow(
          key: const Key('health-local-permission'),
          ok: _localPermission,
          label: 'Yerel bildirim izni',
          value: _localPermission ? 'Açık' : 'Kapalı · izin ver',
          action: _localPermission
              ? null
              : TextButton(
                  key: const Key('health-request-permission'),
                  onPressed: _busy ? null : _requestPermission,
                  child: const Text('Aç'),
                ),
        ),
        _HealthRow(
          key: const Key('health-onesignal'),
          ok: identityOk && (diagnostics?.permissionGranted ?? false),
          label: 'OneSignal aboneliği',
          value: diagnostics == null
              ? 'Kontrol ediliyor…'
              : identityOk
              ? identity
              : 'Eşleşmiyor · $identity',
        ),
        _HealthRow(
          key: const Key('health-membership'),
          ok: sync.isConnected,
          label: 'Supabase Auth + oda üyeliği',
          value: sync.isConnected
              // Oda kodu tam gösterilmez (ekran görüntüsü/paylaşım sızıntısı).
              ? 'Üye · ${settings.maskedRoomCode}'
              : sync.message,
        ),
        _HealthRow(
          key: const Key('health-outbox'),
          ok: pending == 0 && pendingDeletes == 0,
          label: 'Bekleyen çevrimdışı mesaj / silme',
          value: pending == 0 && pendingDeletes == 0
              ? 'Yok · her şey senkron'
              : '$pending mesaj · $pendingDeletes silme',
        ),
        if (lastPush != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (lastPush.ok ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.08),
              borderRadius: AppRadii.smAll,
            ),
            child: Text(
              lastPush.ok
                  ? '${lastPush.message}'
                        '${lastPush.onesignalStatus == null ? '' : ' · OneSignal ${lastPush.onesignalStatus}'}'
                  : lastPush.message,
              style: AppTypography.caption.copyWith(
                color: lastPush.ok ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: const Key('health-send-test'),
          onPressed: _testBusy ? null : _sendTest,
          icon: const Icon(Icons.send_rounded, size: 17),
          label: Text(
            _testBusy
                ? 'Test gönderiliyor…'
                : '📨 Karşı Tarafa Test Bildirimi Gönder',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Test yanıtı Edge Function HTTP kodunu ve OneSignal teslim '
          'durumunu gösterir. 401/403’te oturum bir kez otomatik yenilenir.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.ok,
    required this.label,
    required this.value,
    this.action,
    super.key,
  });

  final bool ok;
  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final Color color = ok ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        title,
        style: AppTypography.subtitle.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PrivacySettings extends ConsumerWidget {
  const _PrivacySettings();

  Future<void> _pickGrace(BuildContext context, WidgetRef ref) async {
    const List<int> options = <int>[0, 15, 30, 60, 120, 300];
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('Arka plan toleransı'),
        children: <Widget>[
          for (final int seconds in options)
            SimpleDialogOption(
              key: Key('pin-grace-$seconds'),
              onPressed: () => Navigator.of(dialogContext).pop(seconds),
              child: Text(seconds == 0 ? 'Hemen kilitle' : '$seconds saniye'),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    ref.read(appSettingsProvider.notifier).setLockGraceSeconds(picked);
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    String? error;
    final String? pin = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          void save() {
            final String value = AppSettings.normalizePin(controller.text);
            if (value.length != 4) {
              setState(() => error = '4 haneli bir PIN gir (ör. 3101)');
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: const Text('Özel alan PIN’i'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: const Key('pin-input'),
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    hintText: '4 hane · ör. 3101',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Varsayılan PIN yıldönümümüz: 3101 💍',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    error!,
                    key: const Key('pin-error-text'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                key: const Key('pin-save'),
                onPressed: save,
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (pin == null || !context.mounted) return;
    final bool saved = await ref
        .read(appSettingsProvider.notifier)
        .setPinCodeAsync(pin);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'PIN güncellendi 🔒 · PBKDF2 ile korunuyor'
                : 'PIN kaydedilemedi · tekrar dene',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Gizlilik',
          subtitle: 'Sohbet ve anılar yalnızca ikimize açık.',
        ),
        SwitchListTile.adaptive(
          key: const Key('pin-toggle'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: const Icon(
            Icons.lock_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Özel Alan Kilidi (4 haneli PIN)',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            'Açılışta ve uygulamaya dönüşte sorulur',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          value: settings.pinLockEnabled,
          onChanged: (bool value) {
            ref.read(appSettingsProvider.notifier).setPinLockEnabled(value);
            if (!value) ref.read(pinLockProvider.notifier).unlock();
          },
        ),
        ListTile(
          key: const Key('pin-change'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.password_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'PIN’i değiştir',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            settings.hasPin
                ? 'Şu an özel PIN · •••• · yalnızca ${settings.needsPinMigration ? 'SHA-256 (girişte PBKDF2’ye yükseltilir)' : 'PBKDF2'} özeti saklanır'
                : 'Şu an varsayılan PIN · 3101',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
          onTap: () => _changePin(context, ref),
        ),
        SwitchListTile.adaptive(
          key: const Key('biometric-toggle'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: const Icon(
            Icons.fingerprint_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Face ID / Parmak İzi ile Aç',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            settings.biometricEnabled
                ? 'Biyometrik kilit açık · PIN yedek olarak kalır'
                : 'PIN yerine biyometrik doğrulama kullan',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          value: settings.biometricEnabled,
          onChanged: (bool value) async {
            ref.read(appSettingsProvider.notifier).setBiometricEnabled(value);
            if (!value) return;
            final bool available = await ref
                .read(biometricServiceProvider)
                .isAvailable();
            if (!available && context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bu cihazda biyometri bulunamadı · PIN kullanılmaya '
                      'devam eder.',
                    ),
                  ),
                );
            }
          },
        ),
        ListTile(
          key: const Key('pin-grace'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(
            Icons.timelapse_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Arka plan toleransı',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            'Kamera/galeri dönüşünde ${settings.lockGraceSeconds} sn '
            'boyunca kilit sorulmaz',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
          onTap: () => _pickGrace(context, ref),
        ),
        ListTile(
          key: const Key('pin-lock-now'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.lock_clock_rounded,
            size: 20,
            color: CouplePalette.ceyda,
          ),
          title: Text(
            'Şimdi kilitle',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            'Özel alanı hemen gizle',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
          onTap: () {
            ref.read(appSettingsProvider.notifier).setPinLockEnabled(true);
            ref.read(pinLockProvider.notifier).lock();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _CloudSyncSettings extends ConsumerStatefulWidget {
  const _CloudSyncSettings();

  @override
  ConsumerState<_CloudSyncSettings> createState() => _CloudSyncSettingsState();
}

class _CloudSyncSettingsState extends ConsumerState<_CloudSyncSettings> {
  late final TextEditingController _url;
  late final TextEditingController _key;
  late final TextEditingController _room;
  late String _role;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = ref.read(appSettingsProvider);
    _url = TextEditingController(text: settings.supabaseUrl);
    _key = TextEditingController(text: settings.supabaseAnonKey);
    _room = TextEditingController(
      text: settings.roomCode.isEmpty
          ? AppSettings.defaultRoomCode
          : settings.roomCode,
    );
    _role = settings.deviceRole;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _room.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  Future<void> _connect() async {
    if (_url.text.trim().isEmpty || _key.text.trim().isEmpty) {
      _snack('Supabase URL ve anon key gerekli ☁️');
      return;
    }
    setState(() => _busy = true);
    ref
        .read(appSettingsProvider.notifier)
        .saveCloudConfig(
          url: _url.text,
          anonKey: _key.text,
          roomCode: _room.text,
          deviceRole: _role,
        );
    await ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ref.read(syncStatusProvider).message);
  }

  Future<void> _copySql() async {
    await Clipboard.setData(ClipboardData(text: SupabaseSyncService.schemaSql));
    _snack('SQL panoya kopyalandı · Supabase → SQL Editor’a yapıştır');
  }

  Future<void> _disconnect() async {
    await ref.read(cloudSyncProvider).disconnect();
    ref.read(appSettingsProvider.notifier).clearCloudConfig();
    if (!mounted) return;
    setState(() {
      _url.clear();
      _key.clear();
    });
    _snack('Bulut kapatıldı · yerel mod sürüyor');
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final SyncStatusInfo status = ref.watch(syncStatusProvider);
    final Color statusColor = switch (status.status) {
      SyncStatus.connected => AppColors.success,
      SyncStatus.connecting => AppColors.streak,
      SyncStatus.error => AppColors.danger,
      SyncStatus.disabled => AppColors.textTertiary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: '☁️ İki Telefon Canlı Senkronizasyon (Supabase)',
          subtitle:
              'Supabase ile dünyanın her yerinden aynı oda. Boş bırakırsan '
              'uygulama tamamen yerel çalışır.',
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  status.message,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (status.isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CloudField(
          key: const Key('cloud-url'),
          controller: _url,
          label: 'Project URL',
          hint: 'https://xxxx.supabase.co',
        ),
        _CloudField(
          key: const Key('cloud-key'),
          controller: _key,
          label: 'Anon public key',
          hint: 'eyJhbGciOi…',
          obscure: true,
        ),
        _CloudField(
          key: const Key('cloud-room'),
          controller: _room,
          label: 'Oda Kodu',
          hint: AppSettings.defaultRoomCode,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Bu Telefon: ${CouplePalette.nameOf(_role)} '
          '${CouplePalette.emojiOf(_role)}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            for (final String id in CouplePartner.ids) ...<Widget>[
              Expanded(
                child: _RoleChip(
                  key: Key('cloud-role-$id'),
                  partnerId: id,
                  selected: _role == id,
                  onTap: () => setState(() => _role = id),
                ),
              ),
              if (id != CouplePartner.ids.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.icon(
              key: const Key('cloud-connect'),
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.cloud_done_rounded, size: 18),
              label: Text(_busy ? 'Bağlanıyor…' : 'Bağlan ve Senkronize Et'),
            ),
            OutlinedButton.icon(
              key: const Key('cloud-sql'),
              onPressed: _copySql,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('SQL şemasını kopyala'),
            ),
            if (settings.isCloudConfigured)
              TextButton(
                key: const Key('cloud-disconnect'),
                onPressed: _disconnect,
                child: const Text('Bağlantıyı kes'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kurulum: Supabase → SQL Editor → önce v6 güvenlik, sonra v6.1 '
          'sohbet/push migration’ını çalıştır. Ardından buraya URL + anon key '
          '+ oda kodunu gir; iki telefon aynı odaya bağlanınca mesajlar anında '
          'akar.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CloudField extends StatelessWidget {
  const _CloudField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          hintStyle: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
          ),
          labelStyle: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
          border: const OutlineInputBorder(
            borderRadius: AppRadii.smAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadii.smAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadii.smAll,
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
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
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              PartnerAvatar(partnerId: partnerId, size: 26),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  '${CouplePalette.nameOf(partnerId)} '
                  '${CouplePalette.emojiOf(partnerId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: selected ? accent : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 15, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// v6: tüm yerel veriyi JSON olarak dışa aktarma / doğrulamalı geri yükleme.
class _BackupSettings extends ConsumerWidget {
  const _BackupSettings();

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final String json = BackupService.export(ref.read(gameProvider));
    await Clipboard.setData(ClipboardData(text: json));
    try {
      await Share.share(
        json,
        subject: 'LevelUp Life yedeği',
        sharePositionOrigin: null,
      );
    } catch (_) {
      // Paylaşım sayfası yoksa pano kopyası yeterlidir (Web/masaüstü).
    }
    if (!context.mounted) return;
    _snack(context, '💾 Yedek panoya kopyalandı · ${json.length} karakter');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? raw = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('📥 Yedeği geri yükle'),
        content: TextField(
          key: const Key('backup-import-input'),
          controller: controller,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(
            hintText: 'Yedek JSON’unu buraya yapıştır',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const Key('backup-import-apply'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;

    BackupRestore restore;
    try {
      restore = BackupService.parse(raw);
    } on BackupException catch (error) {
      _snack(context, '⚠️ ${error.message}');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Yedek doğrulandı ✅'),
        content: Text(
          'Tarih: ${restore.exportedAt?.toLocal() ?? 'bilinmiyor'}\n'
          'Sürüm: v${restore.schemaVersion}\n'
          '${restore.state.partners.length} partner · '
          '${restore.state.couple.messages.length} mesaj\n\n'
          'Mevcut veri bu yedekle değiştirilecek.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('backup-restore-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(gameProvider.notifier).importState(restore.state);
    if (!context.mounted) return;
    _snack(context, '✅ Yedek geri yüklendi');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Yedekleme',
          subtitle:
              'Tüm XP, sohbet ve plan tek JSON dosyasında. Doğrulamalı geri '
              'yükleme yarım veri bırakmaz.',
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              key: const Key('backup-export'),
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('💾 Yedeği paylaş'),
            ),
            OutlinedButton.icon(
              key: const Key('backup-import'),
              onPressed: () => _import(context, ref),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('📥 Yedekten yükle'),
            ),
          ],
        ),
      ],
    );
  }
}
