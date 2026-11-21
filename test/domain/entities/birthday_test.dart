import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';

void main() {
  group('CoupleSpecialDates', () {
    test('dört gerçek tarih doğru ay ve günde tanımlıdır', () {
      expect(CoupleSpecialDates.all, hasLength(4));
      expect(CoupleSpecialDates.ceydaBirthday.month, 11);
      expect(CoupleSpecialDates.ceydaBirthday.day, 27);
      expect(CoupleSpecialDates.yusufBirthday.month, 12);
      expect(CoupleSpecialDates.yusufBirthday.day, 20);
      expect(CoupleSpecialDates.anniversary.month, 1);
      expect(CoupleSpecialDates.anniversary.day, 31);
      expect(CoupleSpecialDates.valentinesDay.month, 2);
      expect(CoupleSpecialDates.valentinesDay.day, 14);
    });

    test('en yakın özel günü ve gün farkını hesaplar', () {
      final DateTime now = DateTime(2026, 11, 20);
      final SpecialDate next = CoupleSpecialDates.next(now);
      expect(next.id, CoupleSpecialDates.ceydaBirthday.id);
      expect(next.daysUntil(now), 7);
      expect(next.bannerText(now), "🎂 Ceyda'nın Doğum Gününe 7 gün kaldı!");
    });

    test('bugün kutlama metnine geçer ve ertesi yıl tekrar eder', () {
      final DateTime today = DateTime(2027, 1, 31);
      const SpecialDate date = CoupleSpecialDates.anniversary;
      expect(date.isToday(today), isTrue);
      expect(date.daysUntil(today), 0);
      expect(date.bannerText(today), '🎉 Bugün Yıldönümümüz!');
      expect(date.nextOccurrence(DateTime(2027, 2, 1)), DateTime(2028, 1, 31));
    });

    test('sıralama en yakın tarihten uzağa doğrudur', () {
      final DateTime now = DateTime(2026, 12, 21);
      final List<SpecialDate> sorted = CoupleSpecialDates.sorted(now);
      expect(sorted.first.id, CoupleSpecialDates.anniversary.id);
      expect(sorted.map((SpecialDate date) => date.id).toList(), <String>[
        CoupleSpecialDates.anniversary.id,
        CoupleSpecialDates.valentinesDay.id,
        CoupleSpecialDates.ceydaBirthday.id,
        CoupleSpecialDates.yusufBirthday.id,
      ]);
    });

    test('doğum günü selamı yalnızca ilgili günde üretilir', () {
      expect(
        CoupleSpecialDates.ceydaBirthday.greeting(
          DateTime(2026, 11, 27),
          'Ceyda',
        ),
        'İyi ki doğdun Ceyda! 🎂',
      );
      expect(
        CoupleSpecialDates.ceydaBirthday.greeting(
          DateTime(2026, 11, 26),
          'Ceyda',
        ),
        isNull,
      );
      expect(CoupleSpecialDates.anniversary.isBirthday, isFalse);
    });

    test('geriye dönük BirthdayConfig erişimi korunur', () {
      expect(BirthdayConfig.ceyda.day, 27);
      expect(BirthdayConfig.ceyda.month, 11);
      expect(BirthdayConfig.all, hasLength(4));
    });
  });
}
