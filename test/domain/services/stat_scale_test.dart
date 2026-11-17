import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/services/stat_scale.dart';

void main() {
  group('radarValue', () {
    test('0 veya negatif XP → 0', () {
      expect(StatScale.radarValue(0), 0);
      expect(StatScale.radarValue(-250), 0);
    });

    test('yarım ömür eğrisi: 1.200 XP → 50, 2.400 XP → 75', () {
      expect(StatScale.radarValue(1200), closeTo(50, 0.001));
      expect(StatScale.radarValue(2400), closeTo(75, 0.001));
      expect(StatScale.radarValue(3600), closeTo(87.5, 0.001));
    });

    test('monoton artar ve 100 tavanını aşmaz', () {
      double previous = 0;
      for (int xp = 0; xp <= 40000; xp += 400) {
        final double value = StatScale.radarValue(xp);
        expect(value, greaterThanOrEqualTo(previous));
        expect(value, lessThanOrEqualTo(100));
        previous = value;
      }
    });
  });

  group('xpForRadarValue', () {
    test('radar hedefi ile tersine çözüm tutarlı', () {
      for (final double target in <double>[10, 25, 50, 75, 90, 99]) {
        final int xp = StatScale.xpForRadarValue(target);
        expect(StatScale.radarValue(xp), closeTo(target, 0.1));
      }
    });

    test('0 hedefi için 0 XP', () {
      expect(StatScale.xpForRadarValue(0), 0);
    });
  });

  group('StatRank', () {
    test('eşikler doğru kuşağı verir', () {
      expect(StatRank.forValue(0), StatRank.raw);
      expect(StatRank.forValue(9.9), StatRank.raw);
      expect(StatRank.forValue(10), StatRank.novice);
      expect(StatRank.forValue(25), StatRank.developing);
      expect(StatRank.forValue(40), StatRank.competent);
      expect(StatRank.forValue(55), StatRank.advanced);
      expect(StatRank.forValue(70), StatRank.master);
      expect(StatRank.forValue(85), StatRank.legend);
      expect(StatRank.forValue(100), StatRank.legend);
    });

    test('son kuşağın next değeri yok', () {
      expect(StatRank.legend.next, isNull);
      expect(StatRank.raw.next, StatRank.novice);
    });
  });

  group('rankFor / progressToNextRank', () {
    test('1.200 XP → Yetkin kuşağı', () {
      expect(StatScale.rankFor(1200), StatRank.competent);
    });

    test('kuşak içi ilerleme 0-1 arasında kalır', () {
      for (int xp = 0; xp <= 20000; xp += 250) {
        final double progress = StatScale.progressToNextRank(xp);
        expect(progress, inInclusiveRange(0, 1));
      }
    });

    test('50 radar değeri Yetkin içinde 2/3 ilerleme', () {
      expect(
        StatScale.progressToNextRank(1200),
        closeTo((50 - 40) / (55 - 40), 0.001),
      );
    });

    test('Efsane kuşağında ilerleme 1.0', () {
      expect(StatScale.progressToNextRank(40000), 1.0);
    });
  });
}
