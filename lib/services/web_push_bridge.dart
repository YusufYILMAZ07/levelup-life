import 'web_push_bridge_stub.dart'
    if (dart.library.js_interop) 'web_push_bridge_web.dart'
    as platform;

/// OneSignal Web SDK v16'nın anlık durum fotoğrafı.
///
/// `permission` ve `optedIn` ayrı tutulur: iOS Safari izin verse bile
/// kullanıcı abonelikten çıkmış olabilir; "kapalıyken bildirim" için ikisi
/// birden gerekir.
final class WebPushStatus {
  const WebPushStatus({
    required this.supported,
    required this.standalone,
    required this.permissionGranted,
    required this.optedIn,
    required this.initialized,
  });

  /// Web Push API'si bu tarayıcıda kullanılabilir (HTTPS + service worker).
  final bool supported;

  /// Sayfa iPhone ana ekranından mı açıldı (`display-mode: standalone`)?
  final bool standalone;

  /// Bildirim izni verildi mi?
  final bool permissionGranted;

  /// OneSignal push aboneliği açık mı (`PushSubscription.optedIn`)?
  final bool optedIn;

  /// OneSignal Web SDK başarıyla başlatıldı mı?
  final bool initialized;

  /// iPhone ana ekranı + izin + abonelik tamam → kilit ekranına düşer.
  bool get ready => supported && standalone && permissionGranted && optedIn;

  /// Mobil/test ortamı ve köprü yokken kullanılan güvenli varsayılan.
  static const WebPushStatus unsupported = WebPushStatus(
    supported: false,
    standalone: false,
    permissionGranted: false,
    optedIn: false,
    initialized: false,
  );
}

/// Platforma özgü Web Push sürücüsü.
///
/// * Web: `web_push_bridge_web.dart` → gerçek OneSignal JS köprüsü.
/// * Mobil / test: `web_push_bridge_stub.dart` → hiçbir şey yapmayan stub.
abstract interface class WebPushDriver {
  /// Bu platformda Web Push köprüsü var mı?
  bool get supported;

  Future<WebPushStatus> init(String appId);

  Future<WebPushStatus> requestPermission();

  Future<WebPushStatus> login(String externalId);

  Future<WebPushStatus> logout();

  Future<WebPushStatus> status();
}

/// Flutter ↔ OneSignal Web SDK köprüsünün tek giriş noktası.
///
/// [`PushService`] bu sınıfı enjekte edilebilir tutar; böylece VM
/// testlerinde sahte (fake) bir [`WebPushDriver`] ile sağlık paneli ve
/// `external_id` eşleşmesi doğrulanabilir.
final class WebPushBridge {
  WebPushBridge({WebPushDriver? driver})
    : _driver = driver ?? platform.createWebPushDriver();

  /// Üretimde kullanılan tekil köprü.
  static final WebPushBridge instance = WebPushBridge();

  final WebPushDriver _driver;

  bool get supported => _driver.supported;

  Future<WebPushStatus> init(String appId) => _driver.init(appId);

  Future<WebPushStatus> requestPermission() => _driver.requestPermission();

  Future<WebPushStatus> login(String externalId) => _driver.login(externalId);

  Future<WebPushStatus> logout() => _driver.logout();

  Future<WebPushStatus> status() => _driver.status();
}
