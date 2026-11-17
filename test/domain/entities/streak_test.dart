import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/core/constants/app_constants.dart';
import 'package:levelup_life/core/utils/date_x.dart';
import 'package:levelup_life/domain/entities/streak.dart';

void main() {
  final DateTime day1 = DateTime(2026, 11, 10, 21, 30);
  final DateTime day2 = DateTime(2026, 11, 11, 8, 15);
  final DateTime day3 = DateTime(2026, 11, 12, 18);
  final DateTime day5 = DateTime(2026, 11, 14, 12);

  group('registerActivity', () {
    test('ilk görev seriyi 1 yapar ve günü normalize eder', () {
      final Streak streak = Streak.empty.registerActivity(day1);

      expect(streak.currentDays, 1);
      expect(streak.longestDays, 1);
      expect(streak.totalActiveDays, 1);
      expect(streak.lastActiveDay, DateX.dateOnly(day1));
      expect(streak.isActive, isTrue);
    });

    test('aynı gün ikinci görev seriyi artırmaz', () {
      final Streak streak = Streak.empty
          .registerActivity(day1)
          .registerActivity(day1.add(const Duration(hours: 2)));

      expect(streak.currentDays, 1);
      expect(streak.totalActiveDays, 1);
    });

    test('ardışık günler seriyi büyütür ve rekoru günceller', () {
      final Streak streak = Streak.empty
          .registerActivity(day1)
          .registerActivity(day2)
          .registerActivity(day3);

      expect(streak.currentDays, 3);
      expect(streak.longestDays, 3);
      expect(streak.totalActiveDays, 3);
    });

    test('bir gün atlanınca seri 1\'e döner, rekor korunur', () {
      final Streak streak = Streak.empty
          .registerActivity(day1)
          .registerActivity(day2)
          .registerActivity(day3)
          .registerActivity(day5);

      expect(streak.currentDays, 1);
      expect(streak.longestDays, 3);
      expect(streak.totalActiveDays, 4);
    });

    test('geçmişe dönük tamamlama seriyi bozmaz', () {
      final Streak streak =
          Streak.empty.registerActivity(day3).registerActivity(day1);

      expect(streak.currentDays, 1);
      expect(streak.lastActiveDay, DateX.dateOnly(day3));
    });
  });

  group('durum sorguları', () {
    test('isCompletedOn sadece aynı gün için true', () {
      final Streak streak = Streak.empty.registerActivity(day1);

      expect(streak.isCompletedOn(day1), isTrue);
      expect(streak.isCompletedOn(day2), isFalse);
    });

    test('dün aktifse bugün seri risk altında', () {
      final Streak streak = Streak.empty.registerActivity(day1);

      expect(streak.isAtRiskOn(day2), isTrue);
      expect(streak.isAtRiskOn(day1), isFalse);
      expect(Streak.empty.isAtRiskOn(day1), isFalse);
    });

    test('isAliveOn sadece bugün veya dün için true', () {
      final Streak streak = Streak.empty.registerActivity(day1);

      expect(streak.isAliveOn(day1), isTrue);
      expect(streak.isAliveOn(day2), isTrue);
      expect(streak.isAliveOn(day3), isFalse);
    });
  });

  group('dondurma (freeze)', () {
    test('bir gün kaçırıldıysa ve hak varsa kurtarılabilir', () {
      final Streak streak = Streak.empty
          .registerActivity(day1)
          .registerActivity(day2);

      expect(streak.canFreezeOn(day3.add(const Duration(days: 1))), isTrue);
      expect(streak.canFreezeOn(day2), isFalse);
    });

    test('dondurma hakkı harcar, seri sayısını artırmaz', () {
      final Streak streak =
          Streak.empty.registerActivity(day1).registerActivity(day2);
      final DateTime now = DateTime(2026, 11, 13, 9);
      final Streak frozen = streak.freezeMissedDay(now);

      expect(frozen.freezeTokens, streak.freezeTokens - 1);
      expect(frozen.currentDays, streak.currentDays);
      expect(frozen.lastActiveDay, DateX.dateOnly(now).subtract(const Duration(days: 1)));
    });

    test('dondurulmuş günün ardından seri devam eder', () {
      final Streak streak =
          Streak.empty.registerActivity(day1).registerActivity(day2);
      final DateTime now = DateTime(2026, 11, 13, 9);
      final Streak continued = streak.freezeMissedDay(now).registerActivity(now);

      expect(continued.currentDays, 3);
      expect(continued.totalActiveDays, 3);
    });

    test('hak yoksa dondurma çalışmaz', () {
      final Streak streak =
          Streak.empty.registerActivity(day1).copyWith(freezeTokens: 0);
      final DateTime now = DateTime(2026, 11, 13, 9);

      expect(streak.freezeMissedDay(now), streak);
    });

    test('token ekleme üst sınırı aşmaz, negatife düşmez', () {
      expect(
        Streak.empty.addFreezeTokens(10).freezeTokens,
        AppConstants.maxFreezeTokens,
      );
      expect(Streak.empty.addFreezeTokens(-99).freezeTokens, 0);
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final Streak streak = Streak.empty
          .registerActivity(day1)
          .registerActivity(day2)
          .copyWith(freezeTokens: 1);

      expect(Streak.fromJson(streak.toJson()), streak);
    });

    test('bozuk JSON varsayılanlara düşer', () {
      final Streak streak = Streak.fromJson(<String, dynamic>{
        'current_days': 'x',
        'last_active_day': 'bozuk-tarih',
      });

      expect(streak.currentDays, 0);
      expect(streak.lastActiveDay, isNull);
      expect(streak.freezeTokens, AppConstants.startingFreezeTokens);
    });
  });
}
