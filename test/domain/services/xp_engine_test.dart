import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/core/constants/app_constants.dart';
import 'package:levelup_life/domain/entities/rank_tier.dart';
import 'package:levelup_life/domain/services/xp_engine.dart';

void main() {
  group('xpForLevel', () {
    test('ilk seviye eşiği 100 XP (motivasyon kancası)', () {
      expect(XpEngine.xpForLevel(1), 100);
    });

    test('eğri monoton artar (hiçbir seviye öncekinden ucuz değil)', () {
      for (
        int level = AppConstants.minLevel;
        level < AppConstants.maxLevel;
        level++
      ) {
        expect(
          XpEngine.xpForLevel(level + 1),
          greaterThanOrEqualTo(XpEngine.xpForLevel(level)),
          reason: 'Lv$level → Lv${level + 1} eğrisi bozuldu',
        );
      }
    });

    test('tüm değerler 5\'in katı (UI temiz sayı gösterir)', () {
      for (
        int level = AppConstants.minLevel;
        level < AppConstants.maxLevel;
        level++
      ) {
        expect(XpEngine.xpForLevel(level) % 5, 0);
      }
    });

    test('soft cap sonrası büyüme yavaşlar', () {
      final int midGrowth = XpEngine.xpForLevel(45) - XpEngine.xpForLevel(44);
      final int lateGrowth = XpEngine.xpForLevel(90) - XpEngine.xpForLevel(89);
      expect(lateGrowth, lessThan(midGrowth));
    });

    test('aralık dışı seviyeler kırpılır', () {
      expect(XpEngine.xpForLevel(0), XpEngine.xpForLevel(1));
      expect(
        XpEngine.xpForLevel(500),
        XpEngine.xpForLevel(AppConstants.maxLevel),
      );
    });
  });

  group('levelForTotalXp', () {
    test('0 XP → Lv1', () {
      expect(XpEngine.levelForTotalXp(0), 1);
    });

    test('eşik tamamlanınca seviye atlar, 1 XP eksikte atmaz', () {
      for (final int level in <int>[2, 5, 20, 60, 98]) {
        final int threshold = XpEngine.totalXpForLevel(level);
        expect(XpEngine.levelForTotalXp(threshold), level);
        expect(XpEngine.levelForTotalXp(threshold - 1), level - 1);
      }
    });

    test('maxTotalXp Lv99 verir', () {
      expect(
        XpEngine.levelForTotalXp(XpEngine.maxTotalXp),
        AppConstants.maxLevel,
      );
    });

    test('negatif XP güvenli (bozuk cache çökertmez)', () {
      expect(XpEngine.levelForTotalXp(-500), 1);
    });
  });

  group('progressForTotalXp', () {
    test('Lv1 içinde 40 XP → %40 ve kalan XP doğru', () {
      final LevelProgress progress = XpEngine.progressForTotalXp(40);

      expect(progress.level, 1);
      expect(progress.xpIntoLevel, 40);
      expect(progress.xpForNextLevel, XpEngine.xpForLevel(1));
      expect(progress.xpRemaining, 60);
      expect(progress.percent, 40);
      expect(progress.isMaxLevel, isFalse);
      expect(progress.tier, RankTier.rookie);
    });

    test('max seviyede fraction 1.0 ve kalan XP 0', () {
      final LevelProgress progress = XpEngine.progressForTotalXp(
        XpEngine.maxTotalXp + 5000,
      );

      expect(progress.level, AppConstants.maxLevel);
      expect(progress.isMaxLevel, isTrue);
      expect(progress.fraction, 1.0);
      expect(progress.xpRemaining, 0);
      expect(progress.tier, RankTier.legend);
    });

    test('progressFrom taşan XP\'yi kaybetmez', () {
      final LevelProgress progress = XpEngine.progressFrom(3, 500);

      expect(progress.totalXp, XpEngine.totalXpForLevel(3) + 500);
      expect(progress.level, greaterThan(3));
    });

    test('xpToNextLevel progress ile tutarlı', () {
      for (final int totalXp in <int>[0, 99, 100, 1234, 9999]) {
        expect(
          XpEngine.xpToNextLevel(totalXp),
          XpEngine.progressForTotalXp(totalXp).xpRemaining,
        );
      }
    });
  });

  group('applyMultipliers', () {
    test('çarpanlar sırayla uygulanır', () {
      // 100 × 1.3 × 1.15 = 149.5 → 150
      expect(XpEngine.applyMultipliers(100, <double>[1.3, 1.15]), 150);
    });

    test('sıfır veya negatif XP → 0', () {
      expect(XpEngine.applyMultipliers(0, <double>[2]), 0);
      expect(XpEngine.applyMultipliers(-40, <double>[2]), 0);
    });

    test('görev asla 1 XP altına düşmez', () {
      expect(XpEngine.applyMultipliers(1, <double>[0.01]), 1);
    });

    test('applyBonus bonus oranını 1+b olarak uygular', () {
      expect(XpEngine.applyBonus(100, 0.15), 115);
      expect(XpEngine.applyBonus(100, 0), 100);
    });
  });
}
