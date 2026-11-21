import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../domain/entities/entities.dart';
import 'app_settings.dart';
import 'notification_service.dart';

/// Ayarlar ekranında gösterilecek push sonucu.
final class PushResult {
  const PushResult({
    required this.ok,
    required this.statusCode,
    required this.message,
  });

  final bool ok;
  final int statusCode;
  final String message;
}

/// OneSignal REST API gövdesini üreten saf yardımcılar (test edilebilir).
abstract final class PushPayloads {
  static Map<String, dynamic> chatMessage({
    required String appId,
    required String recipientId,
    required ChatMessage message,
  }) {
    final String raw = NotificationTexts.messageBody(message).trim();
    final String preview = raw.length > 140 ? '${raw.substring(0, 137)}…' : raw;
    return <String, dynamic>{
      'app_id': appId,
      'include_aliases': <String, dynamic>{
        'external_id': <String>[recipientId],
      },
      'target_channel': 'push',
      'headings': <String, String>{
        'tr': NotificationTexts.partnerTitle(message.senderId),
        'en': NotificationTexts.partnerTitle(message.senderId),
      },
      'contents': <String, String>{'tr': preview, 'en': preview},
      'data': <String, dynamic>{
        'type': 'chat',
        'message_id': message.id,
        'sender_id': message.senderId,
        'route': 'chat',
      },
      'ios_badgeType': 'Increase',
      'ios_badgeCount': 1,
    };
  }

  static Map<String, dynamic> test({
    required String appId,
    required String recipientId,
    required String senderName,
  }) => <String, dynamic>{
    'app_id': appId,
    'include_aliases': <String, dynamic>{
      'external_id': <String>[recipientId],
    },
    'target_channel': 'push',
    'headings': <String, String>{
      'tr': 'LevelUp Life · OneSignal 💞',
      'en': 'LevelUp Life · OneSignal 💞',
    },
    'contents': <String, String>{
      'tr': '$senderName sana kapalıyken de ulaşabilir 🔔',
      'en': '$senderName sana kapalıyken de ulaşabilir 🔔',
    },
    'data': <String, dynamic>{'type': 'test', 'route': 'chat'},
  };
}

/// iOS kapalıyken / arka plandayken OneSignal üzerinden garantili push.
///
/// * Web, test ve eksik yapılandırmada **no-op** çalışır; hiçbir ağ isteği
///   yapmaz ve uygulamayı asla çökertmez.
/// * iOS'ta uygulama açılışında OneSignal başlatılır, izin istenir ve cihaz
///   sahibi `external_id` olarak oturum açar (`yusuf` / `ceyda`).
/// * Mesaj, fotoğraf, video ve dürtme aynı `ChatMessage` üzerinden gittiği
///   için tek bir push yolu vardır.
///
/// Not: Gerçek teslimat için OneSignal panelinde iOS uygulamasına APNs
/// anahtarının yüklenmiş olması gerekir. Bu, kodla değil Apple Developer /
/// OneSignal panel ayarıyla yapılan bir dağıtım adımıdır.
final class PushService {
  PushService({http.Client? client}) : _client = client ?? http.Client();

  static final PushService instance = PushService();

  static const String endpoint = 'https://api.onesignal.com/notifications';

  final http.Client _client;
  bool _initialized = false;
  bool _clickListenerAttached = false;
  String? _appId;
  String? lastError;

  /// Kullanıcı push bildirimine dokunduğunda OneSignal verisini iletir.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  bool get isInitialized => _initialized;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Uygulama açılışında / ayarlar değişince çağrılır.
  Future<bool> initialize(AppSettings settings) async {
    if (!isSupported || !settings.isPushConfigured) return false;
    final String appId = settings.oneSignalAppId.trim();
    try {
      if (!_initialized || _appId != appId) {
        await OneSignal.initialize(appId);
        _initialized = true;
        _appId = appId;
      }
      if (!_clickListenerAttached) {
        // OneSignal, dinleyici kaydolmadan önce gelen soğuk açılış
        // dokunuşlarını tamponlar; kayıt anında bize iletir.
        OneSignal.Notifications.addClickListener((
          OSNotificationClickEvent event,
        ) {
          onNotificationTap?.call(
            event.notification.additionalData ?? const <String, dynamic>{},
          );
        });
        _clickListenerAttached = true;
      }
      await OneSignal.Notifications.requestPermission(true);
      await OneSignal.login(settings.deviceRole);
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      _initialized = false;
      return false;
    }
  }

  /// Cihaz sahibi değişince OneSignal kimliğini günceller.
  Future<void> syncIdentity(AppSettings settings) async {
    if (!_initialized || !isSupported) return;
    try {
      await OneSignal.login(settings.deviceRole);
    } catch (error) {
      lastError = error.toString();
    }
  }

  /// Partnerin `external_id` hedefine anlık push gönderir.
  Future<PushResult> sendChatMessage({
    required AppSettings settings,
    required ChatMessage message,
  }) {
    final String recipientId = CouplePartner.other(message.senderId);
    return _send(
      settings: settings,
      payload: PushPayloads.chatMessage(
        appId: settings.oneSignalAppId.trim(),
        recipientId: recipientId,
        message: message,
      ),
    );
  }

  /// Ayarlardaki "🚀 OneSignal Push Testi Gönder" düğmesi.
  Future<PushResult> sendTest(AppSettings settings) {
    final String recipientId = CouplePartner.other(settings.deviceRole);
    return _send(
      settings: settings,
      payload: PushPayloads.test(
        appId: settings.oneSignalAppId.trim(),
        recipientId: recipientId,
        senderName: CouplePartner.displayName(settings.deviceRole),
      ),
    );
  }

  Future<PushResult> _send({
    required AppSettings settings,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) {
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'Web’de kapalı uygulama push’u yok · iPhone’da çalıştır.',
      );
    }
    if (!settings.isPushConfigured) {
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'OneSignal App ID ve REST API anahtarı gerekli 🔔',
      );
    }
    if (!isSupported) {
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'Bu platformda kapalı uygulama push’u desteklenmiyor.',
      );
    }
    try {
      final http.Response response = await _client
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Key ${settings.oneSignalRestApiKey.trim()}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
      final bool ok = response.statusCode >= 200 && response.statusCode < 300;
      lastError = ok ? null : 'HTTP ${response.statusCode}';
      return PushResult(
        ok: ok,
        statusCode: response.statusCode,
        message: ok
            ? 'Push gönderildi ✅ · HTTP ${response.statusCode}'
            : 'Push gönderilemedi · HTTP ${response.statusCode}',
      );
    } catch (error) {
      lastError = error.toString();
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'Push isteği gönderilemedi · interneti kontrol et.',
      );
    }
  }
}
