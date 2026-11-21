import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_state.dart';
import '../application/pin_lock_controller.dart';
import '../application/shell_controller.dart';
import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../presentation/widgets/in_app_notification_banner.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_coordinator.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';

/// Uygulama yaşam döngüsüne bağlı yan etkiler:
///
/// * yeni partner mesajı → gerçek OS bildirimi
/// * plan saatleri → 10 dk önce haftalık hatırlatıcı
/// * 21:30 akşam puanı hatırlatıcısı
/// * Supabase ayarları değişince bağlan / kop
/// * arka plana geçince PIN kilidi
class AppServices extends ConsumerStatefulWidget {
  const AppServices({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppServices> createState() => _AppServicesState();
}

class _AppServicesState extends ConsumerState<AppServices>
    with WidgetsBindingObserver {
  String _planSignature = '';
  Set<String> _openedCapsules = <String>{};
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Bildirime dokunma → doğru sekme. Lokal bildirimler payload, OneSignal
    // push'ları ise `route` verisi taşır; ikisi de soğuk açılışta çalışır.
    NotificationService.instance.onNotificationTap =
        _handleLocalNotificationTap;
    PushService.instance.onNotificationTap = _handlePushTap;
    unawaited(_bootstrap());
  }

  void _handleLocalNotificationTap(String? payload) {
    if (!mounted || payload == null) return;
    if (payload.startsWith('chat:')) {
      ref.read(shellTabProvider.notifier).goToChat();
    }
  }

  void _handlePushTap(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['route']?.toString() == 'chat') {
      ref.read(shellTabProvider.notifier).goToChat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _openedCapsules = ref
        .read(gameProvider)
        .couple
        .rewardCapsules
        .where((RewardCapsule capsule) => capsule.isOpened)
        .map((RewardCapsule capsule) => capsule.id)
        .toSet();

    final AppSettings settings = ref.read(appSettingsProvider);
    final bool ready = await NotificationService.instance.init();
    if (ready &&
        (settings.messageNotifications ||
            settings.planReminders ||
            settings.dailyCheckinReminder)) {
      await NotificationService.instance.requestPermissions();
    }
    if (ready) {
      // 4 gerçek özel gün: yıllık 20:00 + 09:00 bildirimleri.
      await NotificationService.instance.scheduleSpecialDates();
    }
    await PushService.instance.initialize(settings);
    ref.read(gameProvider.notifier).enforceDeviceOwner(settings);
    _booted = true;
    if (!mounted) return;
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
    await ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider));
    if (mounted) unawaited(_maybePromptDeviceOwner());
  }

  /// İlk açılışta tek seferlik "Bu telefon kimin?" karşılaması.
  Future<void> _maybePromptDeviceOwner() async {
    final AppSettings settings = ref.read(appSettingsProvider);
    final GameState state = ref.read(gameProvider);
    if (settings.deviceOwnerConfigured ||
        !state.isOnboarded ||
        !state.isCoupleEdition) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final String? picked = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('📱 Bu telefon kimin?'),
        content: const Text(
          'Her iPhone kendi sahibiyle açılsın. Yanlış isimle mesaj veya '
          'puan girilmesini böylece engelleriz 💞',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('device-welcome-later'),
            onPressed: () => Navigator.of(dialogContext).pop('later'),
            child: const Text('Daha sonra'),
          ),
          OutlinedButton(
            key: const Key('device-welcome-ceyda'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(CouplePartner.ceydaId),
            child: const Text('Ceyda’nın iPhone’u 🌸'),
          ),
          FilledButton(
            key: const Key('device-welcome-yusuf'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(CouplePartner.yusufId),
            child: const Text('Yusuf’un iPhone’u 💻'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final AppSettingsController controller = ref.read(
      appSettingsProvider.notifier,
    );
    if (picked == null || picked == 'later') {
      controller.markDeviceOwnerConfigured();
      return;
    }
    controller.configureDeviceOwner(picked);
    ref
        .read(gameProvider.notifier)
        .enforceDeviceOwner(ref.read(appSettingsProvider));
    unawaited(PushService.instance.initialize(ref.read(appSettingsProvider)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Debounce edilmiş son durumu hemen diske yaz: uygulama öldürülse de
      // hiçbir dokunuş kaybolmaz.
      unawaited(ref.read(gameStoreProvider).flush());
      ref.read(pinLockProvider.notifier).lockIfEnabled();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
      unawaited(
        ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider)),
      );
    }
  }

  void _handleNewMessages(
    GameState previous,
    GameState next, {
    bool allowPush = true,
    bool allowTestPreview = true,
  }) {
    final AppSettings settings = ref.read(appSettingsProvider);
    if (!settings.messageNotifications) return;
    final Set<String> known = previous.couple.messages
        .map((ChatMessage message) => message.id)
        .toSet();
    for (final ChatMessage message in next.couple.messages) {
      if (known.contains(message.id)) continue;
      final bool own = message.senderId == next.activePartnerId;
      if (!own) {
        // Gelen mesaj: OS bildirimi + her platformda floating banner.
        unawaited(NotificationService.instance.showPartnerMessage(message));
        _showIncomingBanner(message);
        continue;
      }
      if (allowPush) {
        // Giden mesaj: partnerin kapalı iPhone'una OneSignal push'u.
        unawaited(
          PushService.instance.sendChatMessage(
            settings: settings,
            message: message,
          ),
        );
      }
      if (allowTestPreview && !settings.lockToDeviceOwner) {
        // Tek cihaz test modu: profil değiştirip gönderirken de anında görsel
        // geri bildirim ver; gerçek çift kullanımında bu banner gösterilmez.
        _showSentBanner(message, next.activePartnerId);
      }
    }
  }

  void _showIncomingBanner(ChatMessage message) {
    final InAppNotificationKind kind;
    final String emoji;
    if (message.hasVideo) {
      kind = InAppNotificationKind.video;
      emoji = '🎥';
    } else if (message.kind == ChatMessageKind.nudge) {
      kind = InAppNotificationKind.nudge;
      emoji = '💫';
    } else if (message.hasImage) {
      kind = InAppNotificationKind.photo;
      emoji = '📸';
    } else {
      kind = InAppNotificationKind.message;
      emoji = NotificationTexts.partnerTitle(message.senderId).endsWith('🌸')
          ? '🌸'
          : '💌';
    }
    InAppNotificationCenter.instance.show(
      title: NotificationTexts.partnerTitle(message.senderId),
      body: NotificationTexts.messageBody(message),
      emoji: emoji,
      kind: kind,
      payload: 'chat:${message.id}',
    );
  }

  void _showSentBanner(ChatMessage message, String senderId) {
    final String recipient = CouplePartner.other(senderId);
    final String body = message.text.trim().isNotEmpty
        ? message.text.trim()
        : message.preview;
    InAppNotificationCenter.instance.show(
      title: '${CouplePartner.displayName(recipient)} için gönderildi ✅',
      body: body,
      emoji: message.hasVideo
          ? '🎥'
          : message.hasImage
          ? '📸'
          : '💌',
      kind: InAppNotificationKind.sent,
      payload: 'chat:${message.id}',
    );
  }

  void _handleCapsules(GameState previous, GameState next) {
    final Set<String> opened = next.couple.rewardCapsules
        .where((RewardCapsule capsule) => capsule.isOpened)
        .map((RewardCapsule capsule) => capsule.id)
        .toSet();
    final Set<String> fresh = opened.difference(_openedCapsules);
    _openedCapsules = opened;
    if (fresh.isEmpty || !ref.read(appSettingsProvider).messageNotifications) {
      return;
    }
    // Toplu geçmiş çekiminde bildirim yağmuru olmasın: yalnızca en son açılan.
    RewardCapsule? latest;
    for (final RewardCapsule capsule in next.couple.rewardCapsules) {
      if (!fresh.contains(capsule.id)) continue;
      final DateTime at =
          capsule.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime best =
          latest?.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latest == null || at.isAfter(best)) latest = capsule;
    }
    if (latest != null) {
      unawaited(NotificationService.instance.showCapsuleUnlocked(latest));
    }
  }

  /// Karşı telefondan gelen rubrik / plan değişimlerini sessizce bildirir.
  void _handleRemoteActivity(GameState previous, GameState next) {
    final AppSettings settings = ref.read(appSettingsProvider);
    if (!settings.messageNotifications) return;
    final String partnerId = CouplePartner.other(settings.deviceRole);
    if (!_sameScores(previous.couple.rubricScores, next.couple.rubricScores)) {
      unawaited(
        NotificationService.instance.showPartnerActivity(
          partnerId: partnerId,
          body: 'Gelişim puanlarını güncelledi ⭐',
          payload: 'sync-rubric',
        ),
      );
    }
    if (_planSignatureOf(previous) != _planSignatureOf(next)) {
      unawaited(
        NotificationService.instance.showPartnerActivity(
          partnerId: partnerId,
          body: 'Haftalık planını güncelledi 📅',
          payload: 'sync-plan',
        ),
      );
    }
  }

  static bool _sameScores(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, int> entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static String _planSignatureOf(GameState state) => state.couple.scheduleBlocks
      .map(
        (ScheduleBlock block) =>
            '${block.id}:${block.weekday}:${block.startMinutes}:'
            '${block.title}',
      )
      .join('|');

  /// Tüm bildirim anahtarları kapalıyken biri açılırsa OS iznini yeniden
  /// ister (özellikle Android 13+ ve iOS). İzin sonrası plan hatırlatıcıları
  /// yenilenir; aksi halde ilk izin reddedildiğinde sessiz kalırdı.
  Future<void> _ensureNotificationPermission() async {
    final bool ready = await NotificationService.instance.init();
    if (!ready) return;
    await NotificationService.instance.requestPermissions();
    _planSignature = '';
    if (!mounted) return;
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
  }

  void _syncSchedules(GameState state, AppSettings settings) {
    final List<ScheduleBlock> blocks = state.couple.scheduleBlocks;
    final String signature = <String>[
      settings.planReminders.toString(),
      settings.dailyCheckinReminder.toString(),
      state.activePartnerId,
      for (final ScheduleBlock block in blocks)
        '${block.id}:${block.startMinutes}:${block.title}',
    ].join('|');
    if (signature == _planSignature || !_booted) return;
    _planSignature = signature;

    if (settings.planReminders) {
      unawaited(
        NotificationService.instance.syncPlanReminders(
          partnerId: state.activePartnerId,
          blocks: blocks,
        ),
      );
    } else {
      unawaited(NotificationService.instance.cancelPlanReminders());
    }
    if (settings.dailyCheckinReminder) {
      unawaited(NotificationService.instance.scheduleDailyCheckin());
    } else {
      unawaited(NotificationService.instance.cancelDailyCheckin());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameProvider, (GameState? previous, GameState next) {
      if (previous == null) return;
      final CloudSyncCoordinator cloud = ref.read(cloudSyncProvider);
      if (cloud.isApplyingRemote) {
        _handleRemoteActivity(previous, next);
        // Geçmişin tamamı çekilirken bildirim yağmuru olmaz; tek bir canlı
        // uzak paket geldiyse floating banner yine gösterilir.
        if (!cloud.isApplyingHistory) {
          _handleNewMessages(
            previous,
            next,
            allowPush: false,
            allowTestPreview: false,
          );
        }
      } else {
        _handleNewMessages(previous, next);
      }
      _handleCapsules(previous, next);
      _syncSchedules(next, ref.read(appSettingsProvider));
      cloud.onLocalStateChanged(next);
    });

    ref.listen<AppSettings>(appSettingsProvider, (
      AppSettings? previous,
      AppSettings next,
    ) {
      if (previous == null) return;
      final bool hadNotifications =
          previous.messageNotifications ||
          previous.planReminders ||
          previous.dailyCheckinReminder;
      final bool wantsNotifications =
          next.messageNotifications ||
          next.planReminders ||
          next.dailyCheckinReminder;
      if (!hadNotifications && wantsNotifications) {
        unawaited(_ensureNotificationPermission());
      }
      if (previous.oneSignalAppId != next.oneSignalAppId ||
          previous.oneSignalRestApiKey != next.oneSignalRestApiKey) {
        unawaited(PushService.instance.initialize(next));
      } else if (previous.deviceRole != next.deviceRole) {
        unawaited(PushService.instance.syncIdentity(next));
      }
      if (previous.pinLockEnabled != next.pinLockEnabled) {
        ref.read(pinLockProvider.notifier).syncWithSettings();
      }
      if (previous.lockToDeviceOwner != next.lockToDeviceOwner ||
          previous.deviceRole != next.deviceRole) {
        ref.read(gameProvider.notifier).enforceDeviceOwner(next);
      }
      _syncSchedules(ref.read(gameProvider), next);
      unawaited(ref.read(cloudSyncProvider).configure(next));
    });

    return widget.child;
  }
}
