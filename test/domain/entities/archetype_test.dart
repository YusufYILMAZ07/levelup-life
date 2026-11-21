import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/archetype.dart';
import 'package:levelup_life/domain/entities/stat_key.dart';

void main() {
  group('bonus tablosu', () {
    test('ana stat +%15, ikincil stat +%7', () {
      expect(Archetype.scholar.bonusFor(StatKey.intelligence), 0.15);
      expect(Archetype.scholar.bonusFor(StatKey.willpower), 0.07);
      expect(Archetype.scholar.bonusFor(StatKey.strength), 0);
    });

    test('polymath her statta +%9', () {
      for (final StatKey stat in StatKey.values) {
        expect(Archetype.polymath.bonusFor(stat), 0.09);
      }
    });

    test('her arketipin bir ana statı ve bonuslu stat listesi var', () {
      for (final Archetype archetype in Archetype.values) {
        expect(archetype.bonusFor(archetype.primaryStat), greaterThan(0));
        expect(archetype.boostedStats, isNotEmpty);
      }
    });

    test('polymath dışındaki sınıflar ana stattan +%15 alır', () {
      for (final Archetype archetype in Archetype.values) {
        expect(
          archetype.bonusFor(archetype.primaryStat),
          archetype == Archetype.polymath ? 0.09 : 0.15,
        );
      }
    });
  });

  group('recommend', () {
    test('odak boşsa polymath önerilir', () {
      expect(Archetype.recommend(<StatKey>{}), Archetype.polymath);
    });

    test('tek odak statı ilgili sınıfı seçer', () {
      expect(
        Archetype.recommend(<StatKey>{StatKey.intelligence}),
        Archetype.scholar,
      );
      expect(
        Archetype.recommend(<StatKey>{StatKey.strength}),
        Archetype.athlete,
      );
      expect(
        Archetype.recommend(<StatKey>{StatKey.vitality}),
        Archetype.guardian,
      );
      expect(
        Archetype.recommend(<StatKey>{StatKey.productivity}),
        Archetype.hustler,
      );
      expect(Archetype.recommend(<StatKey>{StatKey.willpower}), Archetype.monk);
    });

    test('iki odak statı toplam bonusu en yüksek sınıfı seçer', () {
      expect(
        Archetype.recommend(<StatKey>{StatKey.intelligence, StatKey.willpower}),
        Archetype.scholar,
      );
      expect(
        Archetype.recommend(<StatKey>{StatKey.strength, StatKey.vitality}),
        Archetype.athlete,
      );
    });

    test('aynı girdi her zaman aynı sonucu verir (deterministik)', () {
      const Set<StatKey> focus = <StatKey>{
        StatKey.productivity,
        StatKey.intelligence,
      };
      final Archetype first = Archetype.recommend(focus);
      for (int i = 0; i < 5; i++) {
        expect(Archetype.recommend(focus), first);
      }
    });
  });

  group('serileştirme', () {
    test('code round-trip', () {
      for (final Archetype archetype in Archetype.values) {
        expect(Archetype.fromCode(archetype.code), archetype);
        expect(Archetype.fromCode(archetype.name), archetype);
      }
    });

    test('bilinmeyen/null kod polymath döner', () {
      expect(Archetype.fromCode('wizard'), Archetype.polymath);
      expect(Archetype.fromCode(null), Archetype.polymath);
    });
  });
}
