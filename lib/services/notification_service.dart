import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  FlutterLocalNotificationsPlugin? _plugin;
  final Set<int> _planIds = <int>{};
  bool _ready = false;

  /// Bildirime dokunulduğunda payload'ı uygulamaya taşır.
  ///
  /// AppServices bu köprüyü Sohbet sekmesine yönlendirmek için kullanır.
  void Function(String? payload)? onNotificationTap;

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
  Future<bool> init() async {
    if (_ready) return true;
    if (!isSupportedPlatform) return false;
    try {
      tzdata.initializeTimeZones();
      try {
        // Türkiye tek saat diliminde; cihaz saati plugin'i eklemeden doğru
        // yerel saatle planlama yapılır.
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        // Bilinmeyen bölge → paketin varsayılanı kullanılır.
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
          onNotificationTap?.call(response.payload);
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
        onNotificationTap?.call(launchDetails?.notificationResponse?.payload);
      }
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      _ready = false;
      return false;
    }
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
    if (!await init() || _plugin == null) return false;
    try {
      final int id = 1000 + (message.id.hashCode.abs() % 800);
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
    if (!await init() || _plugin == null) return false;
    await requestPermissions();
    try {
      await _plugin!.show(
        1900 + (capsule.id.hashCode.abs() % 90),
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
    if (!await init() || _plugin == null) return false;
    await requestPermissions();
    try {
      await _plugin!.show(
        1800 + (payload.hashCode.abs() % 90),
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
  }) async {
    await cancelPlanReminders();
    if (!_ready || _plugin == null) return 0;
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'plan:${block.id}',
        );
        _planIds.add(id);
        scheduled++;
      } catch (error) {
        lastError = error.toString();
      }
    }
    return scheduled;
  }

  Future<void> cancelPlanReminders() async {
    if (_plugin == null) return;
    for (final int id in _planIds) {
      try {
        await _plugin!.cancel(id);
      } catch (_) {
        // Sessiz: iptal edilemeyen bildirim uygulamayı etkilemez.
      }
    }
    _planIds.clear();
  }

  /// Her akşam 21:30'da nazik puanlama hatırlatıcısı.
  Future<bool> scheduleDailyCheckin({int hour = 21, int minute = 30}) async {
    if (!_ready || _plugin == null) return false;
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
    if (!await init() || _plugin == null) return 0;
    await requestPermissions();
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
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
    _planIds.clear();
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

  static int _planNotificationId(String blockId) =>
      2000 + (blockId.hashCode.abs() % 6000);
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
