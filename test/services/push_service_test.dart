import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/push_service.dart';

void main() {
  group('PushPayloads', () {
    test('mesajı partnerin external_id hedefine yönlendirir', () {
      final ChatMessage message = ChatMessage(
        id: 'msg-1',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 11, 20, 20),
        text: 'Seni seviyorum',
      );

      final Map<String, dynamic> payload = PushPayloads.chatMessage(
        appId: 'app-id',
        recipientId: CouplePartner.ceydaId,
        message: message,
      );

      expect(payload['app_id'], 'app-id');
      expect(payload['target_channel'], 'push');
      expect(payload['include_aliases'], <String, dynamic>{
        'external_id': <String>[CouplePartner.ceydaId],
      });
      expect((payload['headings'] as Map<String, dynamic>)['tr'], 'Yusuf 💻');
      expect(
        (payload['contents'] as Map<String, dynamic>)['tr'],
        'Seni seviyorum',
      );
      expect((payload['data'] as Map<String, dynamic>)['route'], 'chat');
    });

    test('test push’u karşı partneri hedefler', () {
      final Map<String, dynamic> payload = PushPayloads.test(
        appId: 'app-id',
        recipientId: CouplePartner.yusufId,
        senderName: 'Ceyda',
      );
      expect(
        (payload['include_aliases'] as Map<String, dynamic>)['external_id'],
        <String>[CouplePartner.yusufId],
      );
      expect(
        (payload['contents'] as Map<String, dynamic>)['tr'],
        contains('Ceyda'),
      );
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
