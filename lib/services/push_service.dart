import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const PushResult notConfigured = PushResult(
    ok: false,
    statusCode: 0,
    message: 'OneSignal App ID gerekli 🔔',
  );
}

/// Supabase Edge Function'a gönderilen gövdeyi üreten saf yardımcılar.
///
/// **v6 güvenlik değişikliği:** OneSignal REST API anahtarı artık istemcide
/// değildir. İstemci yalnızca `send-couple-push` fonksiyonunu çağırır; Edge
/// Function oturum sahibini doğrular, oda üyeliğini kontrol eder ve OneSignal
/// isteğini sunucu tarafındaki `ONESIGNAL_REST_API_KEY` ile yapar.
abstract final class PushPayloads {
  /// Edge Function adı.
  static const String functionName = 'send-couple-push';

  static Map<String, dynamic> chatMessage({
    required String recipientId,
    required String senderId,
    required String roomCode,
    required ChatMessage message,
  }) {
    final String raw = NotificationTexts.messageBody(message).trim();
    final String preview = raw.length > 140 ? '${raw.substring(0, 137)}…' : raw;
    return <String, dynamic>{
      'recipient_id': recipientId,
      'sender_id': senderId,
      'room_code': roomCode,
      'type': 'chat',
      'message_id': message.id,
      'headings': NotificationTexts.partnerTitle(message.senderId),
      'contents': preview,
      'data': <String, dynamic>{
        'type': 'chat',
        'message_id': message.id,
        'sender_id': message.senderId,
        'route': 'chat',
      },
    };
  }

  static Map<String, dynamic> test({
    required String recipientId,
    required String senderId,
    required String roomCode,
    required String senderName,
  }) => <String, dynamic>{
    'recipient_id': recipientId,
    'sender_id': senderId,
    'room_code': roomCode,
    'type': 'test',
    'headings': 'LevelUp Life · OneSignal 💞',
    'contents': '$senderName sana kapalıyken de ulaşabilir 🔔',
    'data': <String, dynamic>{'type': 'test', 'route': 'chat'},
  };
}

/// iOS/Android kapalıyken OneSignal üzerinden garantili push.
///
/// * Web, test ve eksik yapılandırmada **no-op** çalışır; ağ isteği yapmaz ve
///   uygulamayı asla çökertmez.
/// * Uygulama açılışında OneSignal başlatılır, izin istenir ve cihaz sahibi
///   `external_id` olarak oturum açar (`yusuf` / `ceyda`).
/// * Gönderim [PushPayloads.functionName] Edge Function'ı üzerinden yapılır.
///
/// Not: Gerçek teslimat için OneSignal panelinde iOS uygulamasına APNs
/// anahtarının yüklenmiş olması ve Edge Function secret'larının tanımlı olması
/// gerekir (README → Push kurulumu).
final class PushService {
  PushService({
    SupabaseClient? Function()? clientProvider,
    bool Function()? supabaseReady,
  }) : _clientProvider = clientProvider ?? (() => Supabase.instance.client),
       _supabaseReady = supabaseReady ?? _defaultSupabaseReady;

  static final PushService instance = PushService();

  final SupabaseClient? Function() _clientProvider;
  final bool Function() _supabaseReady;

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

  static bool _defaultSupabaseReady() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

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
        recipientId: recipientId,
        senderId: message.senderId,
        roomCode: settings.normalizedRoomCode,
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
        recipientId: recipientId,
        senderId: settings.deviceRole,
        roomCode: settings.normalizedRoomCode,
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
    if (!settings.isPushConfigured) return PushResult.notConfigured;
    if (!settings.isCloudConfigured) {
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'Push için önce Supabase bağlantısını kur ☁️',
      );
    }
    if (!_supabaseReady()) {
      return const PushResult(
        ok: false,
        statusCode: 0,
        message: 'Supabase istemcisi hazır değil · Ayarlar’dan bağlan.',
      );
    }
    try {
      final SupabaseClient? client = _clientProvider();
      if (client == null) {
        return const PushResult(
          ok: false,
          statusCode: 0,
          message: 'Supabase istemcisi hazır değil · Ayarlar’dan bağlan.',
        );
      }
      final FunctionResponse response = await client.functions
          .invoke(PushPayloads.functionName, body: payload)
          .timeout(const Duration(seconds: 15));
      final bool ok = response.status >= 200 && response.status < 300;
      lastError = ok ? null : 'HTTP ${response.status}';
      return PushResult(
        ok: ok,
        statusCode: response.status,
        message: ok
            ? 'Push gönderildi ✅ · HTTP ${response.status}'
            : 'Push gönderilemedi · HTTP ${response.status}',
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
