import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'web_push_bridge.dart';

/// Web derlemesinde `web/index.html` içindeki `window.CeyyusWebPush`
/// nesnesini kullanan gerçek OneSignal v16 köprüsü.
WebPushDriver createWebPushDriver() => const WebPushDriverWeb();

@JS('CeyyusWebPush')
external JSObject? get _ceyyusWebPush;

/// `window.CeyyusWebPush` sözleşmesi.
///
/// Tüm `init/login/logout/requestPermission` çağrıları JS tarafında
/// `Promise` döner; `getStatus()` senkron bir durum nesnesidir.
extension type _CeyyusWebPushApi._(JSObject _) implements JSObject {
  external bool isStandalone();

  external JSPromise<JSAny?> init(JSString appId);

  external JSPromise<JSAny?> requestPermission();

  external JSPromise<JSAny?> login(JSString externalId);

  external JSPromise<JSAny?> logout();

  external JSObject getStatus();
}

final class WebPushDriverWeb implements WebPushDriver {
  const WebPushDriverWeb();

  _CeyyusWebPushApi? get _api {
    final JSObject? raw = _ceyyusWebPush;
    return raw == null ? null : _CeyyusWebPushApi._(raw);
  }

  @override
  bool get supported => _api != null;

  @override
  Future<WebPushStatus> init(String appId) async {
    final _CeyyusWebPushApi api = _requireApi();
    await api.init(appId.toJS).toDart;
    return _readStatus(api.getStatus());
  }

  @override
  Future<WebPushStatus> requestPermission() async {
    final _CeyyusWebPushApi api = _requireApi();
    await api.requestPermission().toDart;
    return _readStatus(api.getStatus());
  }

  @override
  Future<WebPushStatus> login(String externalId) async {
    final _CeyyusWebPushApi api = _requireApi();
    await api.login(externalId.toJS).toDart;
    return _readStatus(api.getStatus());
  }

  @override
  Future<WebPushStatus> logout() async {
    final _CeyyusWebPushApi api = _requireApi();
    await api.logout().toDart;
    return _readStatus(api.getStatus());
  }

  @override
  Future<WebPushStatus> status() async {
    final _CeyyusWebPushApi? api = _api;
    if (api == null) return WebPushStatus.unsupported;
    return _readStatus(api.getStatus());
  }

  _CeyyusWebPushApi _requireApi() {
    final _CeyyusWebPushApi? api = _api;
    if (api == null) {
      throw StateError(
        'CeyyusWebPush köprüsü yüklü değil · Safari + HTTPS gerekir.',
      );
    }
    return api;
  }

  WebPushStatus _readStatus(JSObject raw) {
    bool flag(String key) {
      final JSAny? value = raw.getProperty<JSAny?>(key.toJS);
      return value.dartify() == true;
    }

    return WebPushStatus(
      supported: flag('supported'),
      standalone: flag('standalone'),
      permissionGranted: flag('permission'),
      optedIn: flag('optedIn'),
      initialized: flag('initialized'),
    );
  }
}
