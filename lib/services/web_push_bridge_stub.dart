import 'web_push_bridge.dart';

/// Mobil / masaüstü VM derlemelerinde kullanılan güvenli stub.
///
/// OneSignal Web SDK'sı yoktur; tüm çağrılar [`WebPushStatus.unsupported`]
/// döner ve uygulama asla istisna fırlatmaz.
WebPushDriver createWebPushDriver() => const StubWebPushDriver();

final class StubWebPushDriver implements WebPushDriver {
  const StubWebPushDriver();

  @override
  bool get supported => false;

  @override
  Future<WebPushStatus> init(String appId) async => WebPushStatus.unsupported;

  @override
  Future<WebPushStatus> requestPermission() async => WebPushStatus.unsupported;

  @override
  Future<WebPushStatus> login(String externalId) async =>
      WebPushStatus.unsupported;

  @override
  Future<WebPushStatus> logout() async => WebPushStatus.unsupported;

  @override
  Future<WebPushStatus> status() async => WebPushStatus.unsupported;
}
