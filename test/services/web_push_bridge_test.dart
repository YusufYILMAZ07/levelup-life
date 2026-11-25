import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/message_delivery_policy.dart';
import 'package:levelup_life/services/push_service.dart';
import 'package:levelup_life/services/web_push_bridge.dart';

/// Testlerde JS köprüsünü taklit eden sahte sürücü.
final class _FakeWebPushDriver implements WebPushDriver {
  _FakeWebPushDriver({
    this.supports = true,
    this.standalone = true,
    this.permission = false,
    this.optedIn = false,
  });

  final bool supports;
  final bool standalone;
  bool permission;
  bool optedIn;
  bool initialized = false;
  String? lastAppId;
  String? lastLogin;
  final List<String> calls = <String>[];

  @override
  bool get supported => supports;

  @override
  Future<WebPushStatus> init(String appId) async {
    calls.add('init');
    lastAppId = appId;
    initialized = true;
    return status();
  }

  @override
  Future<WebPushStatus> login(String externalId) async {
    calls.add('login');
    lastLogin = externalId;
    return status();
  }

  @override
  Future<WebPushStatus> logout() async {
    calls.add('logout');
    lastLogin = null;
    return status();
  }

  @override
  Future<WebPushStatus> requestPermission() async {
    calls.add('requestPermission');
    permission = true;
    optedIn = true;
    return status();
  }

  @override
  Future<WebPushStatus> status() async => WebPushStatus(
    supported: supports,
    standalone: standalone,
    permissionGranted: permission,
    optedIn: optedIn,
    initialized: initialized,
  );
}

void main() {
  const AppSettings settings = AppSettings(
    supabaseUrl: 'https://demo.supabase.co',
    supabaseAnonKey: 'anon-key',
    roomCode: 'YUSUF-CEYDA-2026',
    deviceRole: CouplePartner.yusufId,
    oneSignalAppId: 'onesignal-app-id',
  );

  group('WebPushBridge stub (mobil / VM test)', () {
    test('köprü yokken desteklenmiyor der ve istisna fırlatmaz', () async {
      final WebPushBridge bridge = WebPushBridge();

      expect(bridge.supported, isFalse);
      expect((await bridge.init('app-id')).supported, isFalse);
      expect((await bridge.status()).initialized, isFalse);

      final WebPushStatus permission = await bridge.requestPermission();
      expect(permission.permissionGranted, isFalse);
      expect(permission.ready, isFalse);

      expect((await bridge.login('room__yusuf')).supported, isFalse);
      expect((await bridge.logout()).supported, isFalse);
    });

    test('WebPushStatus.ready yalnızca tüm koşullar tamamsa true', () {
      expect(WebPushStatus.unsupported.ready, isFalse);
      const WebPushStatus onlyPermission = WebPushStatus(
        supported: true,
        standalone: true,
        permissionGranted: true,
        optedIn: false,
        initialized: true,
      );
      expect(onlyPermission.ready, isFalse);
      const WebPushStatus complete = WebPushStatus(
        supported: true,
        standalone: true,
        permissionGranted: true,
        optedIn: true,
        initialized: true,
      );
      expect(complete.ready, isTrue);
    });
  });

  group('WebPushBridge sürücü delegasyonu', () {
    test('init / login / logout çağrılarını sürücüye iletir', () async {
      final _FakeWebPushDriver driver = _FakeWebPushDriver();
      final WebPushBridge bridge = WebPushBridge(driver: driver);

      expect(bridge.supported, isTrue);
      final WebPushStatus afterInit = await bridge.init('app-42');
      expect(afterInit.initialized, isTrue);
      expect(driver.lastAppId, 'app-42');

      await bridge.login('yusuf-ceyda-2026__yusuf');
      expect(driver.lastLogin, 'yusuf-ceyda-2026__yusuf');

      await bridge.logout();
      expect(driver.lastLogin, isNull);
      expect(driver.calls, <String>['init', 'login', 'logout']);
    });
  });

  group('PushService · iPhone PWA sağlık durumu', () {
    test(
      'Web’de Web SDK köprüsü başlatır ve oda kapsamlı kimlikle girer',
      () async {
        final _FakeWebPushDriver driver = _FakeWebPushDriver();
        final PushService push = PushService(
          webOverride: true,
          webPushBridge: WebPushBridge(driver: driver),
        );

        final bool initialized = await push.initialize(settings);

        expect(initialized, isTrue);
        expect(push.isInitialized, isTrue);
        expect(driver.lastAppId, 'onesignal-app-id');
        expect(push.externalId, 'yusuf-ceyda-2026__yusuf');
        expect(driver.lastLogin, 'yusuf-ceyda-2026__yusuf');
        // Aynı kapsam hem istemci hem push gövdesinde kullanılır.
        expect(
          push.externalId,
          MessageDeliveryPolicy.scopedExternalId(
            roomCode: settings.roomCode,
            role: settings.deviceRole,
          ),
        );
        expect(
          PushPayloads.test(
            recipientId: CouplePartner.ceydaId,
            senderId: CouplePartner.yusufId,
            roomCode: settings.normalizedRoomCode,
            senderName: 'Yusuf',
          )['sender_external_id'],
          push.externalId,
        );
      },
    );

    test('izin öncesi sağlık fotoğrafı: standalone var, opt-in yok', () async {
      final _FakeWebPushDriver driver = _FakeWebPushDriver();
      final PushService push = PushService(
        webOverride: true,
        webPushBridge: WebPushBridge(driver: driver),
      );
      await push.initialize(settings);

      final PushDiagnostics diagnostics = await push.refreshDiagnostics(
        settings,
      );

      expect(diagnostics.isStandalonePwa, isTrue);
      expect(diagnostics.webPushSupported, isTrue);
      expect(diagnostics.webPushOptedIn, isFalse);
      expect(diagnostics.webPushReady, isFalse);
      expect(diagnostics.identityMatches, isTrue);
    });

    test(
      'requestWebPushPermission izin + opt-in sonrası yeşil durum verir',
      () async {
        final _FakeWebPushDriver driver = _FakeWebPushDriver();
        final PushService push = PushService(
          webOverride: true,
          webPushBridge: WebPushBridge(driver: driver),
        );
        await push.initialize(settings);

        final WebPushStatus status = await push.requestWebPushPermission();

        expect(status.permissionGranted, isTrue);
        expect(status.optedIn, isTrue);
        expect(status.ready, isTrue);
        expect(driver.calls, contains('requestPermission'));

        final PushDiagnostics diagnostics = await push.refreshDiagnostics(
          settings,
        );
        expect(diagnostics.webPushReady, isTrue);
        expect(diagnostics.permissionGranted, isTrue);
        expect(diagnostics.webPushOptedIn, isTrue);
      },
    );

    test('oda kodu yoksa Web kimliği temizlenir (logout)', () async {
      const AppSettings noRoom = AppSettings(
        oneSignalAppId: 'onesignal-app-id',
        deviceRole: CouplePartner.ceydaId,
      );
      final _FakeWebPushDriver driver = _FakeWebPushDriver();
      final PushService push = PushService(
        webOverride: true,
        webPushBridge: WebPushBridge(driver: driver),
      );

      expect(await push.initialize(noRoom), isTrue);
      expect(driver.calls, contains('logout'));
      expect(push.externalId, isNull);
    });

    test('OneSignal App ID yoksa SDK başlatılmaz', () async {
      const AppSettings noAppId = AppSettings(
        roomCode: 'YUSUF-CEYDA-2026',
        deviceRole: CouplePartner.yusufId,
      );
      final _FakeWebPushDriver driver = _FakeWebPushDriver();
      final PushService push = PushService(
        webOverride: true,
        webPushBridge: WebPushBridge(driver: driver),
      );

      expect(await push.initialize(noAppId), isFalse);
      expect(driver.calls, isEmpty);
    });

    test('köprü yoksa (stub) web başlatma sessizce false döner', () async {
      final PushService push = PushService(webOverride: true);

      expect(await push.initialize(settings), isFalse);
      expect(await push.requestWebPushPermission(), WebPushStatus.unsupported);
    });

    test(
      'standalone değilse izin + opt-in olsa da kilit ekranı hazır olmaz',
      () async {
        final _FakeWebPushDriver driver = _FakeWebPushDriver(
          standalone: false,
          permission: true,
          optedIn: true,
        );
        final PushService push = PushService(
          webOverride: true,
          webPushBridge: WebPushBridge(driver: driver),
        );
        await push.initialize(settings);

        final PushDiagnostics diagnostics = await push.refreshDiagnostics(
          settings,
        );

        expect(diagnostics.permissionGranted, isTrue);
        expect(diagnostics.webPushOptedIn, isTrue);
        expect(diagnostics.isStandalonePwa, isFalse);
        expect(diagnostics.webPushReady, isFalse);
      },
    );

    test('sürücü Web Push desteklemiyorsa başlatma false döner', () async {
      final WebPushBridge bridge = WebPushBridge(
        driver: _FakeWebPushDriver(supports: false),
      );
      expect(bridge.supported, isFalse);

      final PushService push = PushService(
        webOverride: true,
        webPushBridge: bridge,
      );
      expect(await push.initialize(settings), isFalse);
    });
  });
}
