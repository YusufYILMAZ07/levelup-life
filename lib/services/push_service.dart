import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/entities.dart';
import 'app_settings.dart';
import 'message_delivery_policy.dart';
import 'notification_service.dart';

/// UTF-16 surrogate pair'i ortadan bölmeden rune-safe kırpma.
///
/// Emoji / birleşik karakterler çok code unit taşır; `substring` bunları
/// bozabilir. Bu yardımcı code point sınırında keser ve `…` ekler.
String _runeSafeTruncate(String input, int maxChars) {
  if (input.runes.length <= maxChars) return input;
  final StringBuffer buffer = StringBuffer();
  int count = 0;
  for (final int rune in input.runes) {
    if (count == maxChars) break;
    buffer.writeCharCode(rune);
    count++;
  }
  return '${buffer.toString().trimRight()}…';
}

/// Ayarlar ekranında gösterilecek push sonucu.
final class PushResult {
  const PushResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    this.onesignalStatus,
    this.onesignalId,
    this.duplicate = false,
    this.suppressed = false,
  });

  final bool ok;
  final int statusCode;
  final String message;

  /// Edge Function'ın OneSignal'dan aldığı HTTP kodu.
  final int? onesignalStatus;

  /// OneSignal bildirim kimliği (teslim takibi).
  final String? onesignalId;

  /// Sunucu idempotency katmanı bu mesajı daha önce göndermiş.
  final bool duplicate;

  /// Alıcının sunucu tarafı sessiz saati nedeniyle bilinçli bastırıldı.
  final bool suppressed;

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  static const PushResult notConfigured = PushResult(
    ok: false,
    statusCode: 0,
    message: 'OneSignal App ID gerekli 🔔',
  );

  factory PushResult.fromError(Object error) {
    if (error is FunctionException) {
      final String detail = error.details?.toString() ?? '';
      if (error.status == 401) {
        return const PushResult(
          ok: false,
          statusCode: 401,
          message: 'Push oturumu doğrulanamadı · Supabase’e yeniden bağlan.',
        );
      }
      if (error.status == 403) {
        return const PushResult(
          ok: false,
          statusCode: 403,
          message: 'Bu cihaz odaya üye değil · Ayarlar’dan odaya bağlan.',
        );
      }
      return PushResult(
        ok: false,
        statusCode: error.status,
        message: detail.trim().isEmpty
            ? 'Push gönderilemedi · HTTP ${error.status}'
            : 'Push gönderilemedi · HTTP ${error.status} · $detail',
      );
    }
    return const PushResult(
      ok: false,
      statusCode: 0,
      message: 'Push isteği gönderilemedi · interneti kontrol et.',
    );
  }
}

/// Ayarlar → Bildirim Sağlık Paneli için anlık OneSignal durumu.
final class PushDiagnostics {
  const PushDiagnostics({
    required this.initialized,
    required this.permissionGranted,
    required this.externalId,
    required this.expectedExternalId,
    required this.subscriptionId,
    required this.lastError,
  });

  final bool initialized;
  final bool permissionGranted;
  final String? externalId;
  final String? expectedExternalId;
  final String? subscriptionId;
  final String? lastError;

  bool get identityMatches =>
      externalId != null &&
      expectedExternalId != null &&
      externalId == expectedExternalId;

  bool get subscriptionActive =>
      initialized && permissionGranted && identityMatches;
}

/// Son push hatasını sohbet ekranı ve sağlık panelinde canlı göstermek için.
final class PushHealthController extends Notifier<PushResult?> {
  @override
  PushResult? build() => null;

  void set(PushResult? result) => state = result;
}

final NotifierProvider<PushHealthController, PushResult?> pushHealthProvider =
    NotifierProvider<PushHealthController, PushResult?>(
      PushHealthController.new,
    );

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
    bool urgent = false,
  }) {
    final String raw = NotificationTexts.messageBody(message).trim();
    final String preview = _runeSafeTruncate(raw, 140);
    final bool nudge = message.kind == ChatMessageKind.nudge;
    return <String, dynamic>{
      'recipient_id': recipientId,
      'sender_id': senderId,
      'room_code': roomCode,
      'type': nudge ? 'nudge' : 'chat',
      'message_id': message.id,
      'recipient_external_id': MessageDeliveryPolicy.scopedExternalId(
        roomCode: roomCode,
        role: recipientId,
      ),
      'sender_external_id': MessageDeliveryPolicy.scopedExternalId(
        roomCode: roomCode,
        role: senderId,
      ),
      'urgent': urgent || nudge,
      'headings': NotificationTexts.partnerTitle(message.senderId),
      'contents': preview,
      'data': <String, dynamic>{
        'type': nudge ? 'nudge' : 'chat',
        'message_id': message.id,
        'sender_id': message.senderId,
        'room_code': roomCode,
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
    'recipient_external_id': MessageDeliveryPolicy.scopedExternalId(
      roomCode: roomCode,
      role: recipientId,
    ),
    'sender_external_id': MessageDeliveryPolicy.scopedExternalId(
      roomCode: roomCode,
      role: senderId,
    ),
    'headings': 'CEYYUS · OneSignal 💞',
    'contents': '$senderName sana kapalıyken de ulaşabilir 🔔',
    'data': <String, dynamic>{
      'type': 'test',
      'route': 'chat',
      'room_code': roomCode,
    },
  };
}

/// iOS/Android kapalıyken OneSignal üzerinden garantili push.
///
/// * OneSignal **SDK** yalnızca iOS/Android/macOS'ta başlatılır; Web'de
///   `initialize`/`login` atlanır (SDK yok) ve uygulama asla çökertmez.
/// * Gönderim **her platformda** (Web dahil) [PushPayloads.functionName] Edge
///   Function'ı üzerinden yapılır: Web'den atılan mesaj/dürtme partnerin
///   iOS/Android telefonuna push olarak gider.
/// * Uygulama açılışında OneSignal başlatılır, izin istenir ve cihaz sahibi
///   oda kapsamlı `external_id` olarak oturum açar
///   (`<oda>__<rol>`).
/// * Gönderim [PushPayloads.functionName] Edge Function'ı üzerinden yapılır.
/// * Ön planda Realtime bağlıyken OneSignal ikinci bildirimi bastırılır.
/// * 401/403'te Supabase oturumu tazelenip **bir kez** yeniden denenir.
///
/// Not: Gerçek teslimat için OneSignal panelinde iOS uygulamasına APNs
/// anahtarının yüklenmiş olması ve Edge Function secret'larının tanımlı olması
/// gerekir (README → Push kurulumu).
final class PushService {
  PushService({
    SupabaseClient? Function()? clientProvider,
    bool Function()? supabaseReady,
    this.webOverride,
  }) : _clientProvider = clientProvider ?? (() => Supabase.instance.client),
       _supabaseReady = supabaseReady ?? _defaultSupabaseReady;

  static final PushService instance = PushService();

  final SupabaseClient? Function() _clientProvider;
  final bool Function() _supabaseReady;

  /// Test enjeksiyonu: `kIsWeb` derleme sabitini VM testlerinde taklit eder.
  /// Üretimde `null` → gerçek `kIsWeb` değeri kullanılır.
  final bool? webOverride;

  /// Çalışma zamanının web olup olmadığı (OneSignal SDK kapısı için).
  bool get isWeb => webOverride ?? kIsWeb;

  bool _initialized = false;
  bool _clickListenerAttached = false;
  bool _foregroundListenerAttached = false;
  String? _appId;
  String? _externalId;
  bool _permissionGranted = false;
  Map<String, dynamic>? _pendingTap;
  PushResult? lastResult;
  String? lastError;

  /// AppServices tarafından bağlanır; OneSignal foreground filtresinde kullanılır.
  bool Function()? isAppResumed;
  bool Function()? isRealtimeConnected;

  /// 401/403 sonrası oturum + oda üyeliğini tazeleyen köprü.
  Future<bool> Function()? refreshMembership;

  void Function(Map<String, dynamic> data)? _onNotificationTap;

  /// Kullanıcı push bildirimine dokunduğunda OneSignal verisini iletir.
  ///
  /// Dinleyici henüz bağlanmadan gelen soğuk açılış dokunuşu `_pendingTap`
  /// içinde tutulur ve callback atandığı anda bir kez teslim edilir.
  void Function(Map<String, dynamic> data)? get onNotificationTap =>
      _onNotificationTap;

  set onNotificationTap(void Function(Map<String, dynamic> data)? callback) {
    _onNotificationTap = callback;
    final Map<String, dynamic>? pending = _pendingTap;
    if (callback != null && pending != null) {
      _pendingTap = null;
      callback(pending);
    }
  }

  bool get isInitialized => _initialized;

  String? get externalId => _externalId;

  String? get subscriptionId =>
      _initialized ? OneSignal.User.pushSubscription.id : null;

  bool get permissionGranted => _permissionGranted;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static String? externalIdFor(AppSettings settings) =>
      MessageDeliveryPolicy.scopedExternalId(
        roomCode: settings.roomCode,
        role: settings.deviceRole,
      );

  static bool _defaultSupabaseReady() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Uygulama açılışında / ayarlar değişince çağrılır.
  Future<bool> initialize(
    AppSettings settings, {
    bool requestPermission = true,
  }) async {
    if (isWeb || !isSupported || !settings.isPushConfigured) return false;
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
          final Map<String, dynamic> data =
              event.notification.additionalData ?? const <String, dynamic>{};
          final void Function(Map<String, dynamic>)? callback =
              _onNotificationTap;
          if (callback == null) {
            _pendingTap = data;
          } else {
            callback(data);
          }
        });
        _clickListenerAttached = true;
      }
      if (!_foregroundListenerAttached) {
        OneSignal.Notifications.addForegroundWillDisplayListener((
          OSNotificationWillDisplayEvent event,
        ) {
          final bool suppress =
              MessageDeliveryPolicy.shouldSuppressForegroundPush(
                appResumed: isAppResumed?.call() ?? false,
                realtimeConnected: isRealtimeConnected?.call() ?? false,
              );
          // Her iki dalda da varsayılanı kapatıp tek bir kez gösteriyoruz;
          // böylece Realtime + OneSignal aynı mesaj için iki bildirim üretmez.
          event.preventDefault();
          if (!suppress) event.notification.display();
        });
        _foregroundListenerAttached = true;
      }
      _permissionGranted = requestPermission
          ? await OneSignal.Notifications.requestPermission(true)
          : OneSignal.Notifications.permission;
      lastError = null;
      await syncIdentity(settings);
      return true;
    } catch (error) {
      lastError = error.toString();
      _initialized = false;
      return false;
    }
  }

  /// Cihaz sahibi / oda kodu değişince OneSignal kimliğini günceller.
  ///
  /// Oda kodu yoksa eski, oda dışı `external_id` **temizlenir**; böylece aynı
  /// App ID'yi kullanan başka bir çiftin cihazına push gitmez.
  Future<void> syncIdentity(AppSettings settings) async {
    if (!_initialized || !isSupported) return;
    try {
      final String? scoped = externalIdFor(settings);
      if (scoped == null) {
        await OneSignal.logout();
        _externalId = null;
        lastError = 'Oda kodu tanımlanmadan push kimliği açılmaz.';
        return;
      }
      await OneSignal.login(scoped);
      _externalId = scoped;
      lastError = null;
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
    int attempt = 0,
  }) async {
    // v6.2: Web istemcisi OneSignal SDK'sını başlatamaz (bkz. `isSupported`)
    // ama Edge Function çağrısını **yapabilir**. Böylece Web'den gönderilen
    // mesaj/dürtme partnerin iOS/Android telefonuna push götürür.
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
      final Map<String, dynamic> data = _asMap(response.data);
      final bool duplicate = data['duplicate'] == true;
      final String? suppressed = data['suppressed']?.toString();
      final PushResult result = PushResult(
        ok: ok,
        statusCode: response.status,
        message: ok
            ? duplicate
                  ? 'Push daha önce gönderilmiş ✅ · tekrar yok'
                  : suppressed != null && suppressed.isNotEmpty
                  ? 'Push alıcının sessiz saatinde · sunucu bekletti 🌙'
                  : 'Push gönderildi ✅ · HTTP ${response.status}'
            : 'Push gönderilemedi · HTTP ${response.status}',
        onesignalStatus: _asInt(data['onesignal_status']),
        onesignalId: data['id']?.toString(),
        duplicate: duplicate,
        suppressed: suppressed != null && suppressed.isNotEmpty,
      );
      lastResult = result;
      lastError = ok ? null : 'HTTP ${response.status}';
      return result;
    } on FunctionException catch (error) {
      if ((error.status == 401 || error.status == 403) && attempt == 0) {
        final bool refreshed = await _refreshAuth();
        if (refreshed) {
          return _send(
            settings: settings,
            payload: payload,
            attempt: attempt + 1,
          );
        }
      }
      final PushResult result = PushResult.fromError(error);
      lastResult = result;
      lastError = result.message;
      return result;
    } catch (error) {
      final PushResult result = PushResult.fromError(error);
      lastResult = result;
      lastError = result.message;
      return result;
    }
  }

  Future<bool> _refreshAuth() async {
    final Future<bool> Function()? hook = refreshMembership;
    if (hook != null) {
      try {
        if (await hook()) return true;
      } catch (_) {
        // Koordinatör henüz bağlı değilse yerel auth yenilemeye düş.
      }
    }
    if (!_supabaseReady()) return false;
    try {
      final SupabaseClient? client = _clientProvider();
      if (client == null) return false;
      await client.auth.refreshSession();
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      return client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Sağlık panelinin canlı OneSignal kimlik/izin fotoğrafı.
  Future<PushDiagnostics> refreshDiagnostics(AppSettings settings) async {
    if (isSupported && _initialized) {
      try {
        _permissionGranted = OneSignal.Notifications.permission;
      } catch (error) {
        lastError = error.toString();
      }
    }
    return PushDiagnostics(
      initialized: _initialized,
      permissionGranted: _permissionGranted,
      externalId: _externalId,
      expectedExternalId: externalIdFor(settings),
      subscriptionId: subscriptionId,
      lastError: lastError,
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    return const <String, dynamic>{};
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
