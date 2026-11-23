import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
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
}
