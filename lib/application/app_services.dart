import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_mutation.dart';
import '../application/game_state.dart';
import '../application/pin_lock_controller.dart';
import '../application/shell_controller.dart';
import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../presentation/widgets/in_app_notification_banner.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_coordinator.dart';
import '../services/message_delivery_policy.dart';
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

  /// Plan/check-in bildirimlerinin yeniden zamanlanmasını tetikleyen imza.
  ///
  /// v6.2: `weekday` ve sayısal sessiz saat sınırları da imzaya dahil; aksi
  /// hâlde kullanıcı planı başka güne taşıdığında ya da Rahatsız Etme saatini
  /// değiştirdiğinde eski hatırlatıcılar ekranda kalıyordu.
  @visibleForTesting
  static String scheduleSignature(GameState state, AppSettings settings) =>
      <String>[
        settings.planReminders.toString(),
        settings.dailyCheckinReminder.toString(),
        settings.dailyCheckinLabel,
        settings.doNotDisturbEnabled.toString(),
        settings.quietStartMinutes.toString(),
        settings.quietEndMinutes.toString(),
        settings.quietHoursLabel,
        state.activePartnerId,
        for (final ScheduleBlock block in state.couple.scheduleBlocks)
          '${block.id}:${block.weekday}:${block.startMinutes}:'
              '${block.endMinutes}:${block.title}',
      ].join('|');

  /// Testlerde tam alarm izni tazelemesini taklit etmek için (üretimde null).
  @visibleForTesting
  static Future<bool> Function()? debugExactAlarmRefresher;

  /// `_syncSchedules` gerçekten bir yeniden zamanlama yaptığında artar.
  ///
  /// Widget testleri imza karşılaştırmasının (ve tam alarm değişiminde
  /// sıfırlanmasının) gerçekten yeniden zamanlamaya yol açtığını böyle görür.
  @visibleForTesting
  static int debugScheduleSyncCount = 0;

  @override
  ConsumerState<AppServices> createState() => _AppServicesState();
}

class _AppServicesState extends ConsumerState<AppServices>
    with WidgetsBindingObserver {
  String _planSignature = '';
  Set<String> _openedCapsules = <String>{};
  bool _booted = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Bildirime dokunma → doğru sekme. Lokal bildirimler payload, OneSignal
    // push'ları ise `route` verisi taşır; ikisi de soğuk açılışta çalışır.
    NotificationService.instance.onNotificationTap =
        _handleLocalNotificationTap;
    PushService.instance.onNotificationTap = _handlePushTap;
    PushService.instance.isAppResumed = () =>
        _lifecycle == AppLifecycleState.resumed;
    PushService.instance.isRealtimeConnected = () =>
        ref.read(cloudSyncProvider).isConnected;
    PushService.instance.refreshMembership = () =>
        ref.read(cloudSyncProvider).refreshSessionAndMembership();
    unawaited(_bootstrap());
  }

  /// Yerel bildirim payload'ını doğru sekmeye yönlendirir.
  ///
  /// v6.2: yalnızca `chat:` değil **tüm** payload türleri (plan, rubrik,
  /// check-in, özel gün) hedeflenir; aksi hâlde kullanıcı bildirime dokunup
  /// uygulamayı açtığında hiçbir şey olmuyor gibi görünüyordu.
  void _handleLocalNotificationTap(String? payload) {
    if (!mounted || payload == null) return;
    final String clean = payload.trim();
    if (clean.isEmpty) return;
    final ShellTabController tabs = ref.read(shellTabProvider.notifier);
    if (clean.startsWith('chat:')) {
      tabs.goToChat();
      ref
          .read(chatFocusMessageProvider.notifier)
          .focus(clean.substring('chat:'.length));
      return;
    }
    if (clean == 'sync-rubric') {
      // Karşı taraf rubriği güncelledi → Gelişim sekmesi.
      tabs.goToDevelopment();
      return;
    }
    if (clean == 'sync-plan' || clean.startsWith('plan:')) {
      // Plan değişikliği / plan hatırlatıcısı → Bugün (Plan) sekmesi.
      tabs.goTo(ShellTabController.today);
      return;
    }
    if (clean == 'checkin' || clean.startsWith('checkin:')) {
      tabs.goTo(ShellTabController.today);
      return;
    }
    if (clean.startsWith('special:')) {
      // Özel günler İlerleme sekmesinde listelenir.
      tabs.goTo(ShellTabController.progress);
    }
  }

  void _handlePushTap(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['route']?.toString() != 'chat') return;
    ref.read(shellTabProvider.notifier).goToChat();
    ref
        .read(chatFocusMessageProvider.notifier)
        .focus(data['message_id']?.toString());
  }

  bool get _chatVisible =>
      _lifecycle == AppLifecycleState.resumed &&
      ref.read(shellTabProvider) == ShellTabController.chat;

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
    await PushService.instance.initialize(
      settings,
      requestPermission: settings.wantsNotifications,
    );
    if (!mounted) return;
    ref.read(gameProvider.notifier).enforceDeviceOwner();
    _booted = true;
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
    await ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider));
    if (!mounted) return;
    unawaited(_maybePromptDeviceOwner());
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
    ref.read(gameProvider.notifier).enforceDeviceOwner();
    unawaited(PushService.instance.initialize(ref.read(appSettingsProvider)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Debounce edilmiş son durumu hemen diske yaz: uygulama öldürülse de
      // hiçbir dokunuş kaybolmaz.
      unawaited(ref.read(gameStoreProvider).flush());
      // v6: kilidi hemen basmak yerine zaman damgası tutulur; kamera/galeri
      // gibi kısa sistem geçişleri grace period içinde ekranı kilitlemez.
      ref.read(pinLockProvider.notifier).onAppPaused();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(pinLockProvider.notifier).onAppResumed();
      // Kullanıcı sistem ayarlarından tam alarm iznini verdiyse yeniden
      // başlatmaya gerek kalmadan etkinleşsin (Android 14+). İzin değiştiyse
      // plan hatırlatıcıları `exact` moduna, kaldırıldıysa `inexact` moduna
      // anında geçer.
      unawaited(_refreshExactAlarmScheduleMode());
      _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
      unawaited(
        ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider)),
      );
    }
  }

  /// Tam alarm izni değişimini kontrol eder ve gerekiyorsa planları yeniler.
  Future<void> _refreshExactAlarmScheduleMode() async {
    final Future<bool> Function() refresher =
        AppServices.debugExactAlarmRefresher ??
        NotificationService.instance.refreshExactAlarmPermission;
    bool changed;
    try {
      changed = await refresher();
    } catch (_) {
      // İzin sorgusu başarısız olsa bile diğer resume işleri devam eder.
      return;
    }
    if (!changed || !mounted) return;
    // İmza sıfırlanmazsa `_syncSchedules` "aynı" sanıp erken döner ve
    // hatırlatıcılar eski `inexact` modunda kalırdı.
    _planSignature = '';
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
  }

  void _handleNewMessages(
    GameState previous,
    GameState next, {
    bool allowPush = true,
    bool allowTestPreview = true,
  }) {
    final AppSettings settings = ref.read(appSettingsProvider);
    final Set<String> known = previous.couple.messages
        .map((ChatMessage message) => message.id)
        .toSet();
    for (final ChatMessage message in next.couple.messages) {
      if (known.contains(message.id)) continue;
      final bool own = message.senderId == next.activePartnerId;
      if (!own) {
        // Gelen mesaj: alıcının kendi ayarı + sessiz saati + açık sohbet
        // kontrolü yalnızca bu dalda uygulanır.
        final bool showLocal = MessageDeliveryPolicy.shouldShowIncomingLocal(
          settings: settings,
          now: DateTime.now(),
          chatVisible: _chatVisible,
          appResumed: _lifecycle == AppLifecycleState.resumed,
        );
        if (showLocal) {
          unawaited(NotificationService.instance.showPartnerMessage(message));
          _showIncomingBanner(message);
        } else if (_chatVisible) {
          // Sohbet açıkken sistem bildirimi yok; hafif dokunsal geri bildirim.
          unawaited(HapticFeedback.selectionClick());
        }
        continue;
      }
      if (allowPush) {
        // Giden mesaj/dürtme: gönderenin sessiz saati veya bildirim kapalı
        // ayarı bu çağrıyı ASLA engellemez. Coordinator, Supabase satırı
        // yazıldıktan sonra tam bir kez Edge Function'a iletir.
        unawaited(ref.read(cloudSyncProvider).requestPushFor(message));
      }
      if (allowTestPreview && !settings.lockToDeviceOwner) {
        // Tek cihaz test modu: profil değiştirip gönderirken de anında görsel
        // geri bildirim ver; gerçek çift kullanımında bu banner gösterilmez.
        _showSentBanner(message, next.activePartnerId);
      }
    }
  }

  void _showIncomingBanner(ChatMessage message) {
    // PIN kilitliyken mesaj içeriği asla üst banner'da görünmez.
    if (ref.read(pinLockProvider)) return;
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
    if (ref.read(pinLockProvider)) return;
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
    final AppSettings settings = ref.read(appSettingsProvider);
    if (fresh.isEmpty || !settings.messageNotifications) return;
    // Sessiz saatte kapsül bildirimi de gösterilmez (v6.2 tutarlılık).
    if (settings.isQuietAt(DateTime.now())) return;
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
    if (settings.isQuietAt(DateTime.now())) return;
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
    if (!mounted) return;
    final bool ready = await NotificationService.instance.init();
    if (!ready || !mounted) return;
    await NotificationService.instance.requestPermissions();
    if (!mounted) return;
    // OneSignal izni de yalnızca kullanıcı bildirimleri açtığında istenir.
    await PushService.instance.initialize(ref.read(appSettingsProvider));
    if (!mounted) return;
    _planSignature = '';
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
  }

  void _syncSchedules(GameState state, AppSettings settings) {
    final List<ScheduleBlock> blocks = state.couple.scheduleBlocks;
    final String signature = AppServices.scheduleSignature(state, settings);
    if (signature == _planSignature || !_booted) return;
    _planSignature = signature;
    AppServices.debugScheduleSyncCount++;

    if (settings.planReminders) {
      // Sessiz saate denk gelen hatırlatıcı planlanmaz (DND).
      final List<ScheduleBlock> audible = <ScheduleBlock>[
        for (final ScheduleBlock block in blocks)
          if (!_fallsIntoQuietHours(block, settings)) block,
      ];
      unawaited(
        NotificationService.instance.syncPlanReminders(
          partnerId: state.activePartnerId,
          blocks: audible,
        ),
      );
    } else {
      unawaited(NotificationService.instance.cancelPlanReminders());
    }
    if (settings.dailyCheckinReminder) {
      final int minutes = settings.shiftOutOfQuietHours(
        settings.dailyCheckinHour * 60 + settings.dailyCheckinMinute,
      );
      unawaited(
        NotificationService.instance.scheduleDailyCheckin(
          hour: minutes ~/ 60,
          minute: minutes % 60,
        ),
      );
    } else {
      unawaited(NotificationService.instance.cancelDailyCheckin());
    }
  }

  /// Plan hatırlatıcısının (başlangıçtan 10 dk önce) sessiz saate denk gelip
  /// gelmediğini hesaplar.
  static bool _fallsIntoQuietHours(ScheduleBlock block, AppSettings settings) {
    if (!settings.doNotDisturbEnabled) return false;
    // Gece yarısı sınırı: `00:00–00:09` bloklarının 10 dk öncesi `23:50–23:59`
    // olmalı; `clamp(0, 1439)` negatifi 00:00'a yuvarlıyordu.
    final int reminder = (block.startMinutes - 10 + 1440) % 1440;
    final DateTime probe = DateTime(2000, 1, 1, reminder ~/ 60, reminder % 60);
    return settings.isQuietAt(probe);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameProvider, (GameState? previous, GameState next) {
      if (previous == null) return;
      final CloudSyncCoordinator cloud = ref.read(cloudSyncProvider);
      // Deterministik ayrım: bayrak yerine en son mutasyonun kaynağı kullanılır.
      // `history` (toplu geçmiş) bildirim üretmez; `remote` (tek canlı paket)
      // yalnızca alıcı bildirimi üretir ve asla echo push tetiklemez.
      final MutationOrigin origin = ref.read(gameProvider.notifier).lastOrigin;
      if (origin == MutationOrigin.remote) {
        _handleRemoteActivity(previous, next);
        _handleNewMessages(
          previous,
          next,
          allowPush: false,
          allowTestPreview: false,
        );
        _handleCapsules(previous, next);
      } else if (origin == MutationOrigin.local) {
        _handleNewMessages(previous, next);
        _handleCapsules(previous, next);
      }
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
      final bool identityChanged =
          previous.deviceRole != next.deviceRole ||
          previous.roomCode != next.roomCode ||
          previous.partnerModeEnabled != next.partnerModeEnabled;
      if (previous.oneSignalAppId != next.oneSignalAppId) {
        unawaited(PushService.instance.initialize(next));
      } else if (identityChanged) {
        unawaited(PushService.instance.syncIdentity(next));
      }
      // PIN kilidi `build()` içinde reaktif: ayar değişimi ekranı otomatik
      // günceller; burada ayrıca senkronize etmek gerekmez.
      if (previous.lockToDeviceOwner != next.lockToDeviceOwner ||
          previous.deviceRole != next.deviceRole) {
        ref.read(gameProvider.notifier).enforceDeviceOwner();
      }
      _syncSchedules(ref.read(gameProvider), next);
      unawaited(ref.read(cloudSyncProvider).configure(next));
    });

    return widget.child;
  }
}
