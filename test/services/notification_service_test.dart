import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/notification_service.dart';

void main() {
  group('NotificationTexts', () {
    test('mesaj türüne göre sıcak gövde metni üretir', () {
      ChatMessage message(
        ChatMediaType type, {
        ChatMessageKind kind = ChatMessageKind.photo,
      }) {
        return ChatMessage(
          id: 'n',
          senderId: CouplePartner.ceydaId,
          createdAt: DateTime(2026, 11, 18),
          text: 'Bugün çok yoruldum',
          photoDataOrUrl: type == ChatMediaType.none ? null : 'source',
          mediaType: type,
          kind: kind,
        );
      }

      expect(
        NotificationTexts.messageBody(message(ChatMediaType.image)),
        'Yeni bir fotoğraf gönderdi 📸',
      );
      expect(
        NotificationTexts.messageBody(message(ChatMediaType.video)),
        'Yeni bir video gönderdi 🎥',
      );
      expect(
        NotificationTexts.messageBody(
          message(ChatMediaType.none, kind: ChatMessageKind.proof),
        ),
        'Plan kanıtı paylaştı 📅',
      );
      expect(
        NotificationTexts.messageBody(message(ChatMediaType.none)),
        'Bugün çok yoruldum',
      );
      expect(
        NotificationTexts.messageBody(
          ChatMessage(
            id: 'empty',
            senderId: CouplePartner.yusufId,
            createdAt: DateTime(2026, 11, 18),
          ),
        ),
        'Sana yeni bir mesaj gönderdi 💌',
      );
    });

    test('partner başlığı isim + emoji içerir', () {
      expect(
        NotificationTexts.partnerTitle(CouplePartner.ceydaId),
        contains('Ceyda'),
      );
      expect(NotificationTexts.timeLabel(830), '13:50');
      expect(NotificationTexts.timeLabel(-5), '00:00');
    });

    test('plan hatırlatıcısı 10 dk önce ve saat bilgisiyle yazılır', () {
      const ScheduleBlock block = ScheduleBlock(
        id: 'b1',
        partnerId: CouplePartner.ceydaId,
        weekday: DateTime.wednesday,
        startMinutes: 14 * 60,
        endMinutes: 15 * 60,
        title: 'Sporda',
        category: ScheduleCategory.workout,
      );

      final String body = NotificationTexts.planReminderBody(block: block);

      expect(body, contains('13:50'));
      expect(body, contains('10 dk sonra'));
      expect(body, contains('Sporda'));
      expect(body, contains(ScheduleCategory.workout.emoji));
    });
  });

  group('Özel gün bildirimleri', () {
    test('bir gün önce 20:00 ve günün sabahı 09:00 planlanır', () {
      final DateTime now = DateTime(2026, 11, 20, 12);
      final DateTime eve = NotificationService.nextSpecialReminder(
        date: CoupleSpecialDates.ceydaBirthday,
        now: now,
        hour: 20,
        minute: 0,
        oneDayBefore: true,
      );
      final DateTime day = NotificationService.nextSpecialReminder(
        date: CoupleSpecialDates.ceydaBirthday,
        now: now,
        hour: 9,
        minute: 0,
        oneDayBefore: false,
      );

      expect(eve, DateTime(2026, 11, 26, 20));
      expect(day, DateTime(2026, 11, 27, 9));
      expect(
        NotificationTexts.specialDateEve(CoupleSpecialDates.ceydaBirthday),
        contains("Ceyda'nın Doğum Günü"),
      );
      expect(
        NotificationTexts.specialDateDay(CoupleSpecialDates.ceydaBirthday),
        startsWith('🎉 Bugün'),
      );
    });

    test('geçmiş saat bir sonraki yıla taşınır', () {
      final DateTime now = DateTime(2026, 11, 27, 10);
      final DateTime day = NotificationService.nextSpecialReminder(
        date: CoupleSpecialDates.ceydaBirthday,
        now: now,
        hour: 9,
        minute: 0,
        oneDayBefore: false,
      );
      expect(day, DateTime(2027, 11, 27, 9));
      expect(day.isAfter(now), isTrue);
    });

    test('yılbaşı gecesi bir gün önce aralık 31’e düşer', () {
      final DateTime now = DateTime(2026, 12, 1);
      final DateTime eve = NotificationService.nextSpecialReminder(
        date: CoupleSpecialDates.anniversary,
        now: now,
        hour: 20,
        minute: 0,
        oneDayBefore: true,
      );
      expect(eve, DateTime(2027, 1, 30, 20));
    });
  });

  group('Bildirim zamanlaması', () {
    test('aynı gün içindeki hatırlatıcı 10 dk önceye kurulur', () {
      final DateTime now = DateTime(2026, 11, 16, 9); // Pazartesi
      expect(now.weekday, DateTime.monday);

      final DateTime at = NotificationService.nextWeeklyReminder(
        now: now,
        weekday: DateTime.monday,
        startMinutes: 10 * 60,
      );

      expect(at, DateTime(2026, 11, 16, 9, 50));
    });

    test('geçmiş saat bir sonraki haftaya taşınır', () {
      final DateTime now = DateTime(2026, 11, 16, 9);

      final DateTime at = NotificationService.nextWeeklyReminder(
        now: now,
        weekday: DateTime.monday,
        startMinutes: 9 * 60,
      );

      expect(at, DateTime(2026, 11, 23, 8, 50));
      expect(at.isAfter(now), isTrue);
    });
  });
}
