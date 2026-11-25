import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/push_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// v6.2: Web istemcisi OneSignal SDK'sız da partnerine push gönderebilir.
void main() {
  const AppSettings settings = AppSettings(
    supabaseUrl: 'https://demo.supabase.co',
    supabaseAnonKey: 'anon-key',
    roomCode: 'YUSUF-CEYDA-2026',
    deviceRole: CouplePartner.yusufId,
    oneSignalAppId: 'onesignal-app-id',
  );

  test(
    'Web (kIsWeb) OneSignal SDK’yı atlar ama Edge Function push’unu engellemez',
    () async {
      final List<http.Request> requests = <http.Request>[];
      final MockClient httpClient = MockClient((http.Request request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 'onesignal-1',
            'onesignal_status': 200,
            'duplicate': false,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SupabaseClient supabase = SupabaseClient(
        settings.supabaseUrl,
        settings.supabaseAnonKey,
        httpClient: httpClient,
      );
      final PushService push = PushService(
        clientProvider: () => supabase,
        supabaseReady: () => true,
        webOverride: true,
      );

      // Web'de OneSignal SDK başlatılmaz (yerel abonelik yok)...
      expect(await push.initialize(settings), isFalse);
      expect(push.isInitialized, isFalse);

      // ...ancak gönderim yolu engellenmez: Edge Function çağrılır.
      final PushResult result = await push.sendTest(settings);

      expect(result.ok, isTrue);
      expect(result.statusCode, 200);
      expect(result.onesignalStatus, 200);
      expect(result.onesignalId, 'onesignal-1');
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/functions/v1/${PushPayloads.functionName}',
      );
      expect(requests.single.method, 'POST');

      final Map<String, dynamic> body =
          jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['room_code'], 'YUSUF-CEYDA-2026');
      expect(body['recipient_id'], CouplePartner.ceydaId);
      expect(body['sender_id'], CouplePartner.yusufId);
      expect(body['recipient_external_id'], 'yusuf-ceyda-2026__ceyda');
      // REST API anahtarı istemci gövdesinde asla yer almaz.
      expect(body.containsKey('app_id'), isFalse);
    },
  );
}
