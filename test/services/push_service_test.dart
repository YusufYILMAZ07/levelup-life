import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/message_delivery_policy.dart';
import 'package:levelup_life/services/push_service.dart';

void main() {
  group('PushPayloads (Edge Function gövdesi)', () {
    test('mesajı partnerin external_id hedefine yönlendirir', () {
      final ChatMessage message = ChatMessage(
        id: 'msg-1',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 11, 20, 20),
        text: 'Seni seviyorum',
      );

      final Map<String, dynamic> payload = PushPayloads.chatMessage(
        recipientId: CouplePartner.ceydaId,
        senderId: CouplePartner.yusufId,
        roomCode: 'YUSUF-CEYDA-2026',
        message: message,
      );

      expect(payload['recipient_id'], CouplePartner.ceydaId);
      expect(payload['sender_id'], CouplePartner.yusufId);
      expect(payload['room_code'], 'YUSUF-CEYDA-2026');
      expect(payload['type'], 'chat');
      expect(payload['headings'], 'Yusuf 💻');
      expect(payload['contents'], 'Seni seviyorum');
      expect((payload['data'] as Map<String, dynamic>)['route'], 'chat');
      // REST anahtarı istemci gövdesinde asla yer almaz.
      expect(payload.containsKey('app_id'), isFalse);
      expect(payload.toString().contains('os_v2_'), isFalse);
    });

    test('test push’u karşı partneri hedefler', () {
      final Map<String, dynamic> payload = PushPayloads.test(
        recipientId: CouplePartner.yusufId,
        senderId: CouplePartner.ceydaId,
        roomCode: 'YUSUF-CEYDA-2026',
        senderName: 'Ceyda',
      );
      expect(payload['recipient_id'], CouplePartner.yusufId);
      expect(payload['contents'], contains('Ceyda'));
      expect(payload['room_code'], 'YUSUF-CEYDA-2026');
    });
  });

  test('eksik yapılandırmada ağ isteği yapmadan Türkçe uyarı verir', () async {
    const AppSettings settings = AppSettings(deviceRole: CouplePartner.yusufId);
    final PushResult result = await PushService().sendTest(settings);

    expect(result.ok, isFalse);
    expect(result.statusCode, 0);
    expect(result.message, contains('OneSignal'));
  });

  group('Oda kapsamlı OneSignal kimliği', () {
    test('couple:<oda>:<rol> biçiminde normalize edilir', () {
      expect(
        MessageDeliveryPolicy.scopedExternalId(
          roomCode: ' YUSUF-CEYDA-2026 ',
          role: 'Ceyda',
        ),
        'yusuf-ceyda-2026__ceyda',
      );
      // Aynı App ID farklı odalar → farklı alias.
      expect(
        MessageDeliveryPolicy.scopedExternalId(
          roomCode: 'OTHER-ROOM-2026',
          role: 'ceyda',
        ),
        isNot('yusuf-ceyda-2026__ceyda'),
      );
      expect(
        MessageDeliveryPolicy.scopedExternalId(roomCode: '   ', role: 'yusuf'),
        isNull,
      );
    });

    test('push gövdesi alıcı ve gönderen alias’ını taşır', () {
      final ChatMessage nudge = ChatMessage(
        id: 'nudge-1',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 11, 23, 22),
        text: 'Hadi bir puan daha',
        kind: ChatMessageKind.nudge,
      );
      final Map<String, dynamic> payload = PushPayloads.chatMessage(
        recipientId: CouplePartner.ceydaId,
        senderId: CouplePartner.yusufId,
        roomCode: 'YUSUF-CEYDA-2026',
        message: nudge,
      );

      expect(payload['type'], 'nudge');
      expect(payload['urgent'], isTrue);
      expect(payload['recipient_external_id'], 'yusuf-ceyda-2026__ceyda');
      expect(payload['sender_external_id'], 'yusuf-ceyda-2026__yusuf');
      expect(
        (payload['data'] as Map<String, dynamic>)['message_id'],
        'nudge-1',
      );
    });
  });

  group('Gelen mesaj yerel bildirim politikası', () {
    final DateTime now = DateTime(2026, 11, 23, 23, 30);
    const AppSettings dnd = AppSettings(
      doNotDisturbEnabled: true,
      quietStartMinutes: 23 * 60,
      quietEndMinutes: 7 * 60,
    );

    test('alıcı sessiz saatteyse yerel bildirim bastırılır', () {
      expect(
        MessageDeliveryPolicy.shouldShowIncomingLocal(
          settings: dnd,
          now: now,
          chatVisible: false,
          appResumed: false,
        ),
        isFalse,
      );
    });

    test('bildirimler kapalıysa veya sohbet açıksa banner gösterilmez', () {
      expect(
        MessageDeliveryPolicy.shouldShowIncomingLocal(
          settings: const AppSettings(messageNotifications: false),
          now: DateTime(2026, 11, 23, 12),
          chatVisible: false,
          appResumed: true,
        ),
        isFalse,
      );
      expect(
        MessageDeliveryPolicy.shouldShowIncomingLocal(
          settings: const AppSettings(),
          now: DateTime(2026, 11, 23, 12),
          chatVisible: true,
          appResumed: true,
        ),
        isFalse,
      );
    });

    test('normal koşulda gelen mesaj görünür', () {
      expect(
        MessageDeliveryPolicy.shouldShowIncomingLocal(
          settings: const AppSettings(),
          now: DateTime(2026, 11, 23, 12),
          chatVisible: false,
          appResumed: true,
        ),
        isTrue,
      );
    });
  });

  group('Ön plan çift bildirim filtresi', () {
    test('Realtime bağlı + uygulama ön planda → OneSignal bastırılır', () {
      expect(
        MessageDeliveryPolicy.shouldSuppressForegroundPush(
          appResumed: true,
          realtimeConnected: true,
        ),
        isTrue,
      );
      expect(
        MessageDeliveryPolicy.shouldSuppressForegroundPush(
          appResumed: true,
          realtimeConnected: false,
        ),
        isFalse,
      );
      expect(
        MessageDeliveryPolicy.shouldSuppressForegroundPush(
          appResumed: false,
          realtimeConnected: true,
        ),
        isFalse,
      );
    });
  });
}
