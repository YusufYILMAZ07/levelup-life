import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/stable_key.dart';
import '../domain/entities/entities.dart';

/// Bildirim metinleri — saf fonksiyonlar, plugin olmadan test edilebilir.
abstract final class NotificationTexts {
  static const String dailyCheckinBody =
      'Günün 1-2-3 gelişim puanlarını girmeyi unutma ⭐';

  static String partnerTitle(String partnerId) =>
      '${CouplePartner.displayName(partnerId)} '
      '${CouplePartner.emoji(partnerId)}';

  /// Gelen mesajın türüne göre sıcak bir gövde metni.
  static String messageBody(ChatMessage message) {
    if (message.hasVideo) return 'Yeni bir video gönderdi 🎥';
    if (message.kind == ChatMessageKind.proof) {
      return 'Plan kanıtı paylaştı 📅';
    }
    if (message.kind == ChatMessageKind.nudge) {
      return message.text.trim().isEmpty
          ? 'Sana bir dürtme gönderdi 💫'
          : message.text.trim();
    }
    if (message.hasImage) return 'Yeni bir fotoğraf gönderdi 📸';
    if (message.kind == ChatMessageKind.loveNote) {
      return message.text.trim().isEmpty
          ? 'Sana bir aşk notu bıraktı 💌'
          : message.text.trim();
    }
    if (message.text.trim().isNotEmpty) return message.text.trim();
    if (message.questBadgeTitle != null) {
      return '${message.questBadgeTitle} görevini tamamladı 🎯';
    }
    return 'Sana yeni bir mesaj gönderdi 💌';
  }

  static String capsuleBody(RewardCapsule capsule) =>
      '${capsule.emoji} ${capsule.title} kapsülü açıldı! '
      'Birlikte kutlayın 💞';

  static String timeLabel(int minutes) {
    final int safe = minutes.clamp(0, 24 * 60);
    final int hour = safe ~/ 60;
    final int minute = safe % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// `13:50 · 10 dk sonra '🏋️ Sporda' planın başlıyor!`
  static String planReminderBody({
    required ScheduleBlock block,
    int leadMinutes = 10,
  }) {
    final String emoji = block.category.emoji;
    final int reminderMinutes = (block.startMinutes - leadMinutes).clamp(
      0,
      24 * 60,
    );
    return '${timeLabel(reminderMinutes)} · $leadMinutes dk sonra '
        "'$emoji ${block.title}' planın başlıyor!";
  }

  static String testTitle() => 'LevelUp Life · test 🌸';

  static String testBody() =>
      'Bildirimler hazır! Yusuf & Ceyda bildirimlerini buradan görecek 💞';

  /// Özel günden bir gün önce 20:00.
  static String specialDateEve(SpecialDate date) =>
      '✨ Yarın büyük gün! ${date.title} yaklaşıyor ❤️';

  /// Özel günün sabahı 09:00.
  static String specialDateDay(SpecialDate date) =>
      '🎉 Bugün ${date.title}! Uygulamayı aç ve sürprizi gör 💖';
}

/// Gerçek iOS / Android bildirim motoru.
///
/// * platform desteklenmiyorsa (Web, test) **sessizce devre dışı** kalır;
///   hiçbir çağrı exception fırlatmaz → uygulama asla çökmez.
/// * anlık partner mesajı, plan başlangıç hatırlatıcısı ve 21:30 akşam
///   puanı bildirimlerini yönetir.
final class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String channelId = 'levelup_couple_messages';
  static const String channelName = 'Yusuf & Ceyda';
  static const String channelDescription =
      'Mesajlar, anılar, plan hatırlatıcıları ve akşam puanı';

  static const int _dailyCheckinId = 9001;
  static const int _testId = 9002;
  static const int _specialDateIdBase = 9200;

  /// Bildirim kimliği aralıkları (namespace).
  ///
  /// Uygulama yeniden açıldığında bellek içi bir küme kaybolur; iptal işlemi
  /// `pendingNotificationRequests()` ile **aralığa göre** yapılır.
  static const int planIdStart = 2000;
  static const int planIdSize = 4000;
  static const int messageIdStart = 10000;
  static const int messageIdSize = 10000;
  static const int capsuleIdStart = 20000;
  static const int capsuleIdSize = 2000;
  static const int activityIdStart = 30000;
  static const int activityIdSize = 2000;

  FlutterLocalNotificationsPlugin? _plugin;
  bool _ready = false;
  bool _permissionRequested = false;
  bool? _exactAlarmAllowed;
  Future<bool>? _initFuture;
  Future<void> _planSyncQueue = Future<void>.value();
  String? _pendingLaunchPayload;
  void Function(String? payload)? _onNotificationTap;

  /// Bildirime dokunulduğunda payload'ı uygulamaya taşır.
  ///
  /// Dinleyici bağlanmadan önce gelen soğuk başlatma payload'ı tamponda
  /// tutulur ve setter atandığı anda bir kez teslim edilir.
  void Function(String? payload)? get onNotificationTap => _onNotificationTap;

  set onNotificationTap(void Function(String? payload)? callback) {
    _onNotificationTap = callback;
    final String? pending = _pendingLaunchPayload;
    if (callback != null && pending != null) {
      _pendingLaunchPayload = null;
      callback(pending);
    }
  }

  bool get isReady => _ready;

  /// Ayar ekranında gösterilebilecek son hata (opsiyonel).
  String? lastError;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      presentList: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      presentList: true,
    ),
  );

  /// Uygulama açılışında bir kez çağrılır. Başarısız olsa bile uygulama
  /// çalışmaya devam eder (offline-first).
  ///
  /// Devam eden `Future` paylaşılır; aynı anda gelen birden çok `init()`
  /// çağrısı ayrı ayrı plugin açmaz.
  Future<bool> init() {
    if (_ready) return Future<bool>.value(true);
    if (!isSupportedPlatform) return Future<bool>.value(false);
    final Future<bool>? pending = _initFuture;
    if (pending != null) return pending;
    final Future<bool> future = _doInit();
    _initFuture = future;
    return future;
  }

  Future<bool> _doInit() async {
    try {
      tzdata.initializeTimeZones();
      try {
        // Cihazın gerçek saat dilimi (v6). Sabit Europe/Istanbul yalnızca son
        // çare fallback'idir; böylece seyahat/DR dahil doğru saatte planlanır.
        final String zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        } catch (_) {
          // Bilinmeyen bölge → paketin varsayılanı kullanılır.
        }
      }

      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final String? payload = response.payload;
          if (_onNotificationTap != null) {
            _onNotificationTap!(payload);
          } else {
            _pendingLaunchPayload = payload;
          }
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _plugin = plugin;
      _ready = true;
      // Uygulama tamamen kapalıyken bildirime dokunulduysa payload'ı
      // initialize callback'i değil, launch details taşır.
      final NotificationAppLaunchDetails? launchDetails = await plugin
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final String? payload = launchDetails?.notificationResponse?.payload;
        if (_onNotificationTap != null) {
          _onNotificationTap!(payload);
        } else {
          _pendingLaunchPayload = payload;
        }
      }
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      _ready = false;
      return false;
    }
  }

  /// Bildirim izni şu an verilmiş mi? (Ayarlar sağlık paneli için)
  Future<bool> hasPermission() async {
    if (!await ensureInitialized() || _plugin == null) return false;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin!
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final NotificationsEnabledOptions? options = await ios
            .checkPermissions();
        return options?.isEnabled ?? options?.isProvisionalEnabled ?? false;
      }
      final MacOSFlutterLocalNotificationsPlugin? macos = _plugin!
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final NotificationsEnabledOptions? options = await macos
            .checkPermissions();
        return options?.isEnabled ?? options?.isProvisionalEnabled ?? false;
      }
    } catch (error) {
      lastError = error.toString();
    }
    return false;
  }

  /// Android 14+ exact alarm izni varsa `exactAllowWhileIdle`, aksi hâlde
  /// çökmeyen `inexactAllowWhileIdle` kullanılır.
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android || _plugin == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    final bool? cached = _exactAlarmAllowed;
    if (cached != null) {
      return cached
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool allowed =
          await android?.canScheduleExactNotifications() ?? false;
      _exactAlarmAllowed = allowed;
      return allowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      _exactAlarmAllowed = false;
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Android 14+ "tam alarm" (exact alarm) izni kullanıcı tarafından sistem
  /// ayarlarından değiştirildiğinde önbelleği tazeler.
  ///
  /// `AppLifecycleState.resumed` anında çağrılır: kullanıcı izni verdikten
  /// sonra uygulamayı yeniden başlatmaya gerek kalmadan plan hatırlatıcıları
  /// tam zamanında planlanır. Diğer platformlarda `true` döner (kısıt yok).
  Future<bool> refreshExactAlarmPermission() async {
    _exactAlarmAllowed = null;
    if (!isSupportedPlatform) return true;
    if (!await ensureInitialized() || _plugin == null) return false;
    final AndroidScheduleMode mode = await _androidScheduleMode();
    return mode == AndroidScheduleMode.exactAllowWhileIdle;
  }

  /// iOS / Android 13+ izin isteği. Reddedilirse sessizce döner.
  Future<bool> requestPermissions() async {
    if (!_ready || _plugin == null) return false;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin!
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final MacOSFlutterLocalNotificationsPlugin? macos = _plugin!
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      lastError = error.toString();
    }
    return false;
  }

  /// Her genel API'nin başında güvenli başlatma.
  ///
  /// Plugin daha önce açılmadıysa (uygulama arka plandan döndü, ayar ekranı
  /// doğrudan çağırdı…) burada açılır; başarısızsa `false` döner ve çağrı
  /// sessizce atlanır.
  Future<bool> ensureInitialized() async {
    if (_ready && _plugin != null) return true;
    return init();
  }

  /// İzin bir kez istenir; her bildirimde tekrar diyalog açılmaz.
  Future<void> _ensurePermission({bool force = false}) async {
    if (_permissionRequested && !force) return;
    final bool granted = await requestPermissions();
    if (granted) _permissionRequested = true;
  }

  /// Belirli bir kimlik aralığındaki bekleyen bildirimleri iptal eder.
  ///
  /// [matches] verilirse payload filtresi de uygulanır.
  Future<int> cancelPendingInRange({
    required int start,
    required int end,
    bool Function(String? payload)? matches,
  }) async {
    if (!await ensureInitialized() || _plugin == null) return 0;
    int cancelled = 0;
    try {
      final List<PendingNotificationRequest> pending = await _plugin!
          .pendingNotificationRequests();
      for (final PendingNotificationRequest request in pending) {
        if (request.id < start || request.id >= end) continue;
        if (matches != null && !matches(request.payload)) continue;
        try {
          await _plugin!.cancel(request.id);
          cancelled++;
        } catch (_) {
          // Tek bildirim iptal edilemezse diğerleri etkilenmez.
        }
      }
    } catch (error) {
      lastError = error.toString();
    }
    return cancelled;
  }

  Future<bool> showTestNotification() async {
    final bool ready = await init();
    if (!ready || _plugin == null) return false;
    try {
      await requestPermissions();
      await _plugin!.show(
        _testId,
        NotificationTexts.testTitle(),
        NotificationTexts.testBody(),
        _details,
        payload: 'test',
      );
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  /// Partnerden gelen mesaj / fotoğraf / video / dürtme için anlık bildirim.
  ///
  /// `init()` daha önce çağrılmadıysa **burada** çağrılır; böylece bildirim
  /// sessizce kaybolmaz.
  Future<bool> showPartnerMessage(ChatMessage message) async {
    if (!await ensureInitialized() || _plugin == null) return false;
    await _ensurePermission();
    try {
      final int id = StableKey.namespacedId(
        key: 'msg:${message.id}',
        start: messageIdStart,
        size: messageIdSize,
      );
      await _plugin!.show(
        id,
        NotificationTexts.partnerTitle(message.senderId),
        NotificationTexts.messageBody(message),
        _details,
        payload: 'chat:${message.id}',
      );
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<bool> showCapsuleUnlocked(RewardCapsule capsule) async {
    if (!await ensureInitialized() || _plugin == null) return false;
    await _ensurePermission();
    try {
      await _plugin!.show(
        StableKey.namespacedId(
          key: 'capsule:${capsule.id}',
          start: capsuleIdStart,
          size: capsuleIdSize,
        ),
        'Ödül kapsülü açıldı 🎁',
        NotificationTexts.capsuleBody(capsule),
        _details,
        payload: 'capsule:${capsule.id}',
      );
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  /// Bulut senkronundan gelen rubrik / plan güncellemesi gibi "sessiz"
  /// değişiklikler için partner bildirimi (mesaj balonu değil).
  Future<bool> showPartnerActivity({
    required String partnerId,
    required String body,
    String payload = 'sync',
  }) async {
    if (!await ensureInitialized() || _plugin == null) return false;
    await _ensurePermission();
    try {
      await _plugin!.show(
        StableKey.namespacedId(
          key: 'activity:$payload',
          start: activityIdStart,
          size: activityIdSize,
        ),
        NotificationTexts.partnerTitle(partnerId),
        body,
        _details,
        payload: payload,
      );
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  /// Aktif partnerin haftalık planı için "10 dk önce" hatırlatıcılarını
  /// yeniden kurar (her blok haftalık tekrar eder). Planlanan sayıyı döner.
  Future<int> syncPlanReminders({
    required String partnerId,
    required List<ScheduleBlock> blocks,
  }) {
    // Eşzamanlı plan yenilemeleri seri kuyrukla korunur; son çağrı kazanır ve
    // iptal/yeniden kurma işlemleri iç içe girmez.
    final Completer<int> completer = Completer<int>();
    _planSyncQueue = _planSyncQueue.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(
          await _syncPlanRemindersInternal(
            partnerId: partnerId,
            blocks: blocks,
          ),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<int> _syncPlanRemindersInternal({
    required String partnerId,
    required List<ScheduleBlock> blocks,
  }) async {
    // v6: bellek içi küme yerine kalıcı bekleyen bildirimler iptal edilir.
    await cancelPlanReminders();
    if (!await ensureInitialized() || _plugin == null) return 0;
    await _ensurePermission();
    final AndroidScheduleMode scheduleMode = await _androidScheduleMode();
    int scheduled = 0;
    for (final ScheduleBlock block in blocks) {
      if (block.partnerId != partnerId || block.title.trim().isEmpty) continue;
      try {
        final DateTime when = nextWeeklyReminder(
          now: DateTime.now(),
          weekday: block.weekday,
          startMinutes: block.startMinutes,
        );
        final int id = _planNotificationId(block.id);
        await _plugin!.zonedSchedule(
          id,
          'Plan hatırlatıcısı ⏰',
          NotificationTexts.planReminderBody(block: block),
          tz.TZDateTime.from(when, tz.local),
          _details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'plan:${block.id}',
        );
        scheduled++;
      } catch (error) {
        lastError = error.toString();
      }
    }
    return scheduled;
  }

  /// Plan hatırlatıcılarını **payload ve kimlik aralığı** ile iptal eder.
  ///
  /// Uygulama kapanıp açıldığında `_planIds` gibi bellek içi bir küme boş
  /// olacağı için v6'da `pendingNotificationRequests()` kullanılır; eski
  /// sürümden kalan bildirimler de temizlenir.
  Future<int> cancelPlanReminders() => cancelPendingInRange(
    start: planIdStart,
    end: planIdStart + planIdSize,
    matches: (String? payload) =>
        payload == null || payload.startsWith('plan:'),
  );

  /// Her akşam [hour]:[minute]'te nazik puanlama hatırlatıcısı.
  Future<bool> scheduleDailyCheckin({int hour = 21, int minute = 30}) async {
    if (!await ensureInitialized() || _plugin == null) return false;
    await _ensurePermission();
    final AndroidScheduleMode scheduleMode = await _androidScheduleMode();
    try {
      final DateTime now = DateTime.now();
      DateTime when = DateTime(now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) {
        when = DateTime(now.year, now.month, now.day + 1, hour, minute);
      }
      await _plugin!.zonedSchedule(
        _dailyCheckinId,
        'Akşam puanı ⭐',
        NotificationTexts.dailyCheckinBody,
        tz.TZDateTime.from(when, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'checkin',
      );
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<void> cancelDailyCheckin() async {
    try {
      await _plugin?.cancel(_dailyCheckinId);
    } catch (_) {
      // Sessiz.
    }
  }

  /// 4 özel gün için **her yıl tekrar eden** iki bildirim kurar:
  /// bir gün önce 20:00 ve günün sabahı 09:00.
  Future<int> scheduleSpecialDates({
    DateTime? now,
    List<SpecialDate> dates = CoupleSpecialDates.all,
  }) async {
    if (!await ensureInitialized() || _plugin == null) return 0;
    await _ensurePermission();
    final AndroidScheduleMode scheduleMode = await _androidScheduleMode();
    final DateTime at = now ?? DateTime.now();
    int scheduled = 0;
    for (int i = 0; i < dates.length; i++) {
      final SpecialDate date = dates[i];
      final List<_SpecialReminder> reminders = <_SpecialReminder>[
        _SpecialReminder(
          hour: 20,
          minute: 0,
          oneDayBefore: true,
          title: '✨ Yarın büyük gün! ${date.emoji}',
          body: NotificationTexts.specialDateEve(date),
        ),
        _SpecialReminder(
          hour: 9,
          minute: 0,
          oneDayBefore: false,
          title: '🎉 Bugün ${date.title}!',
          body: NotificationTexts.specialDateDay(date),
        ),
      ];
      for (int r = 0; r < reminders.length; r++) {
        final _SpecialReminder reminder = reminders[r];
        try {
          final DateTime when = nextSpecialReminder(
            date: date,
            now: at,
            hour: reminder.hour,
            minute: reminder.minute,
            oneDayBefore: reminder.oneDayBefore,
          );
          await _plugin!.zonedSchedule(
            _specialDateIdBase + i * 10 + r,
            reminder.title,
            reminder.body,
            tz.TZDateTime.from(when, tz.local),
            _details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: scheduleMode,
            matchDateTimeComponents: DateTimeComponents.dateAndTime,
            payload: 'special:${date.id}',
          );
          scheduled++;
        } catch (error) {
          lastError = error.toString();
        }
      }
    }
    return scheduled;
  }

  /// Yıllık özel gün bildiriminin bir sonraki gerçek zamanı (saf fonksiyon).
  static DateTime nextSpecialReminder({
    required SpecialDate date,
    required DateTime now,
    required int hour,
    required int minute,
    required bool oneDayBefore,
  }) {
    DateTime occurrence = date.nextOccurrence(now);
    DateTime candidate = _reminderAt(
      occurrence,
      hour: hour,
      minute: minute,
      oneDayBefore: oneDayBefore,
    );
    if (!candidate.isAfter(now)) {
      occurrence = DateTime(
        occurrence.year + 1,
        occurrence.month,
        occurrence.day,
      );
      candidate = _reminderAt(
        occurrence,
        hour: hour,
        minute: minute,
        oneDayBefore: oneDayBefore,
      );
    }
    return candidate;
  }

  static DateTime _reminderAt(
    DateTime occurrence, {
    required int hour,
    required int minute,
    required bool oneDayBefore,
  }) => DateTime(
    occurrence.year,
    occurrence.month,
    occurrence.day - (oneDayBefore ? 1 : 0),
    hour,
    minute,
  );

  Future<void> cancelAll() async {
    try {
      await _plugin?.cancelAll();
    } catch (_) {
      // Sessiz.
    }
  }

  /// Bir sonraki haftalık hatırlatıcı anı — saf fonksiyon (test edilebilir).
  static DateTime nextWeeklyReminder({
    required DateTime now,
    required int weekday,
    required int startMinutes,
    int leadMinutes = 10,
  }) {
    final int reminderMinutes = (startMinutes - leadMinutes).clamp(0, 1439);
    final int safeWeekday = weekday.clamp(1, 7);
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      reminderMinutes ~/ 60,
      reminderMinutes % 60,
    );
    while (candidate.weekday != safeWeekday || !candidate.isAfter(now)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        candidate.hour,
        candidate.minute,
      );
    }
    return candidate;
  }

  static int _planNotificationId(String blockId) => StableKey.namespacedId(
    key: 'plan:$blockId',
    start: planIdStart,
    size: planIdSize,
  );
}

/// Özel gün bildirim planının iç yardımcısı.
final class _SpecialReminder {
  const _SpecialReminder({
    required this.hour,
    required this.minute,
    required this.oneDayBefore,
    required this.title,
    required this.body,
  });

  final int hour;
  final int minute;
  final bool oneDayBefore;
  final String title;
  final String body;
}
