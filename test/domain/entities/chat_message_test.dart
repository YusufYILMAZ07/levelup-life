import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';

void main() {
  group('ChatMessage v4 medya modeli', () {
    test('video + yanıt + okundu bilgisi JSON ile korunur', () {
      final ChatMessage message = ChatMessage(
        id: 'm1',
        senderId: CouplePartner.ceydaId,
        createdAt: DateTime.utc(2026, 11, 18, 20, 15),
        text: 'Bu akşamki klip',
        photoDataOrUrl: '/var/mobile/media/clip.mp4',
        photoCaption: 'Kampüs akşamı',
        mediaType: ChatMediaType.video,
        replyToMessageId: 'm0',
        replyPreviewText: 'Saat kaçta?',
        isRead: true,
        durationSeconds: 12,
        isLiked: true,
        kind: ChatMessageKind.photo,
      );

      final ChatMessage restored = ChatMessage.fromJson(message.toJson());

      expect(restored, message);
      expect(restored.hasVideo, isTrue);
      expect(restored.isReply, isTrue);
      expect(restored.durationSeconds, 12);
      expect(restored.isRead, isTrue);
      expect(restored.preview, '🎥 Kampüs akşamı');
    });

    test('v3 kayıtları media_type olmadan da okunur', () {
      final ChatMessage legacy = ChatMessage.fromJson(<String, dynamic>{
        'id': 'old',
        'sender_id': 'yusuf',
        'created_at': '2026-11-18T10:00:00.000Z',
        'photo_data_or_url': 'preset:coffee',
        'photo_caption': 'İlk kahve',
        'kind': 'photo',
      });

      expect(legacy.photoDataOrUrl, 'preset:coffee');
      expect(legacy.mediaPathOrUrl, 'preset:coffee');
      expect(legacy.effectiveMediaType, ChatMediaType.image);
      expect(legacy.hasImage, isTrue);
      expect(legacy.hasVideo, isFalse);
      expect(legacy.isRead, isFalse);
    });

    test('data URL video türü içerikten çıkarılır', () {
      final ChatMessage inferred = ChatMessage(
        id: 'v1',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 1, 1),
        photoDataOrUrl: 'data:video/mp4;base64,AAAA',
        kind: ChatMessageKind.photo,
      );

      expect(inferred.hasVideo, isTrue);
      expect(inferred.effectiveMediaType, ChatMediaType.video);
      expect(ChatMediaType.fromCode(null), ChatMediaType.none);
      expect(ChatMediaType.fromCode('video'), ChatMediaType.video);
    });

    test('copyWith yanıtı temizleyebilir ve okundu işaretleyebilir', () {
      final ChatMessage message = ChatMessage(
        id: 'm2',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 11, 18),
        text: 'Selam',
      ).withReply(messageId: 'm1', preview: 'Önceki mesaj');

      expect(message.isReply, isTrue);
      expect(message.copyWith(clearReply: true).replyToMessageId, isNull);
      expect(message.markRead().isRead, isTrue);
      expect(message.markRead().markRead(), message.markRead());
    });
  });
}
