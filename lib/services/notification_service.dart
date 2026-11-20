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

  FlutterLocalNotificationsPlugin? _plugin;
  final Set<int> _planIds = <int>{};
  bool _ready = false;

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
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
  Future<bool> showPartnerMessage(ChatMessage message) async {
    if (!_ready || _plugin == null) return false;
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
    if (!_ready || _plugin == null) return false;
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
    if (!_ready || _plugin == null) return false;
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
