import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/core/utils/date_x.dart';
import 'package:levelup_life/domain/entities/daily_xp_log.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 15, 18, 30);

  group('record', () {
    test('aynı günün XP\'si toplanır', () {
      final DailyXpLog log = DailyXpLog.empty
          .record(at: now, xp: 30)
          .record(at: now.add(const Duration(hours: 2)), xp: 45);

      expect(log.xpOn(now), 75);
      expect(log.activeDays, 1);
      expect(log.totalXp, 75);
    });

    test('sıfır veya negatif XP kaydı yok sayılır', () {
      final DailyXpLog log = DailyXpLog.empty
          .record(at: now, xp: 0)
          .record(at: now, xp: -20);

      expect(log.isEmpty, isTrue);
      expect(log.isNotEmpty, isFalse);
    });

    test('gün 00:00\'a normalize edilir', () {
      final DailyXpLog log =
          DailyXpLog.empty.record(at: DateTime(2026, 11, 15, 23, 59), xp: 10);

      expect(log.byDay.keys.single, DateTime(2026, 11, 15));
    });
  });

  group('series', () {
    test('eskiden yeniye, sabit genişlikte; boş günler 0 XP', () {
      final DailyXpLog log = DailyXpLog.empty
          .record(at: DateTime(2026, 11, 9), xp: 20)
          .record(at: DateTime(2026, 11, 15), xp: 40);

      final List<DailyXp> points = log.series(end: now, days: 7);

      expect(points, hasLength(7));
      expect(points.first.day, DateTime(2026, 11, 9));
      expect(points.last.day, DateTime(2026, 11, 15));
      expect(points.first.xp, 20);
      expect(points.last.xp, 40);
      expect(points[1].xp, 0);
      expect(points.where((DailyXp point) => point.isActive), hasLength(2));
    });

    test('pencere dışındaki kayıtlar seriye girmez', () {
      final DailyXpLog log = DailyXpLog.empty
          .record(at: DateTime(2026, 11, 1), xp: 99)
          .record(at: now, xp: 10);

      final List<DailyXp> points = log.series(end: now, days: 7);

      expect(points.fold<int>(0, (int sum, DailyXp p) => sum + p.xp), 10);
      expect(points.last.xp, 10);
    });

    test('geçersiz gün sayısı en az bir nokta döndürür', () {
      expect(DailyXpLog.empty.series(end: now, days: 0), hasLength(1));
    });
  });

  group('seri yardımcıları', () {
    // Aktif günler: 7, 8, 9, 10 (4'lük blok) + 13, 14, 15 (3'lük blok).
    final DailyXpLog log = DailyXpLog.empty
        .record(at: DateTime(2026, 11, 7), xp: 10)
        .record(at: DateTime(2026, 11, 8), xp: 10)
        .record(at: DateTime(2026, 11, 9), xp: 10)
        .record(at: DateTime(2026, 11, 10), xp: 10)
        .record(at: DateTime(2026, 11, 13), xp: 10)
        .record(at: DateTime(2026, 11, 14), xp: 10)
        .record(at: DateTime(2026, 11, 15), xp: 10);

    test('streakEndingOn kesintisiz günleri sayar', () {
      expect(log.streakEndingOn(DateTime(2026, 11, 15)), 3);
      expect(log.streakEndingOn(DateTime(2026, 11, 10)), 4);
      expect(log.streakEndingOn(DateTime(2026, 11, 11)), 0);
    });

    test('currentStreakOn bugün boşsa dünkü seriyi korur', () {
      expect(log.currentStreakOn(DateTime(2026, 11, 15)), 3);
      expect(log.currentStreakOn(DateTime(2026, 11, 16)), 3);
      expect(log.currentStreakOn(DateTime(2026, 11, 18)), 0);
    });

    test('longestStreak en uzun bloğu verir', () {
      expect(log.longestStreak, 4);
      expect(DailyXpLog.empty.longestStreak, 0);
    });

    test('activeDaysIn yalnızca pencereyi sayar', () {
      expect(log.activeDaysIn(DateTime(2026, 11, 15), 7), 5);
      expect(log.activeDaysIn(DateTime(2026, 11, 15), 30), 7);
    });

    test('lastActiveDay en yeni aktif günü verir', () {
      expect(log.lastActiveDay, DateTime(2026, 11, 15));
      expect(DailyXpLog.empty.lastActiveDay, isNull);
    });
  });

  group('budama ve serileştirme', () {
    test('maxStoredDays üstü budanır, en yeniler kalır', () {
      DailyXpLog log = DailyXpLog.empty;
      for (int i = 0; i < DailyXpLog.maxStoredDays + 5; i++) {
        log = log.record(at: DateX.shiftDays(now, -i), xp: 5);
      }

      expect(log.byDay, hasLength(DailyXpLog.maxStoredDays));
      expect(log.isActiveOn(now), isTrue);
      expect(
        log.isActiveOn(DateX.shiftDays(now, -(DailyXpLog.maxStoredDays - 1))),
        isTrue,
      );
      expect(
        log.isActiveOn(DateX.shiftDays(now, -DailyXpLog.maxStoredDays)),
        isFalse,
      );
    });

    test('JSON round-trip eşitliği ve hash\'i korur', () {
      final DailyXpLog log = DailyXpLog.empty
          .record(at: DateTime(2026, 11, 15), xp: 30)
          .record(at: DateTime(2026, 11, 14), xp: 12);

      final DailyXpLog restored = DailyXpLog.fromJson(log.toJson());

      expect(restored, log);
      expect(restored.hashCode, log.hashCode);
      expect(restored.toJson(), <String, dynamic>{
        '2026-11-15': 30,
        '2026-11-14': 12,
      });
    });

    test('bozuk ve negatif JSON kayıtları atılır', () {
      final DailyXpLog log = DailyXpLog.fromJson(<String, dynamic>{
        '2026-11-15': 20,
        'bozuk-tarih': 30,
        '2026-11-14': -5,
        '2026-11-13': '40',
      });

      expect(log.totalXp, 60);
      expect(log.byDay.keys, containsAll(<DateTime>[
        DateTime(2026, 11, 15),
        DateTime(2026, 11, 13),
      ]));
      expect(log.isActiveOn(DateTime(2026, 11, 14)), isFalse);
    });

    test('boş JSON boş log üretir', () {
      final DailyXpLog log = DailyXpLog.fromJson(const <String, dynamic>{});

      expect(log.isEmpty, isTrue);
      expect(log, DailyXpLog.empty);
    });
  });
}
