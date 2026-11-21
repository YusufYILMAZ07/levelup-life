import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/rpg_stats.dart';
import 'package:levelup_life/domain/entities/stat_key.dart';
import 'package:levelup_life/domain/services/stat_scale.dart';

void main() {
  group('initial', () {
    test('her zaman 5 stat içerir ve hepsi 0 XP', () {
      expect(RpgStats.initial.ordered.length, StatKey.values.length);
      for (final StatProgress progress in RpgStats.initial.ordered) {
        expect(progress.xp, 0);
        expect(progress.questsCompleted, 0);
        expect(progress.radarValue, 0);
        expect(progress.rank, StatRank.raw);
      }
      expect(RpgStats.initial.totalXp, 0);
    });

    test('ordered sırası StatKey.values ile aynı (radar sabit)', () {
      expect(
        RpgStats.initial.ordered.map((StatProgress p) => p.stat).toList(),
        StatKey.values,
      );
    });
  });

  group('recordQuest / gainXp', () {
    test('sadece hedef statı büyütür, sayaçyı artırır', () {
      final RpgStats stats = RpgStats.initial
          .recordQuest(StatKey.intelligence, 120)
          .recordQuest(StatKey.intelligence, 80);

      expect(stats[StatKey.intelligence].xp, 200);
      expect(stats[StatKey.intelligence].questsCompleted, 2);
      expect(stats[StatKey.strength].xp, 0);
      expect(stats.totalQuests, 2);
      expect(stats.totalXp, 200);
    });

    test('negatif XP yok sayılır', () {
      final RpgStats stats = RpgStats.initial
          .recordQuest(StatKey.strength, -50)
          .gainXp(StatKey.strength, -10);

      expect(stats[StatKey.strength].xp, 0);
      expect(stats[StatKey.strength].questsCompleted, 1);
    });

    test('orijinal örnek değişmez (immutable)', () {
      final RpgStats stats = RpgStats.initial;
      stats.recordQuest(StatKey.vitality, 300);

      expect(stats[StatKey.vitality].xp, 0);
    });
  });

  group('türetilmiş değerler', () {
    test('radar değerleri half-life eğrisini kullanır', () {
      final RpgStats stats = RpgStats.initial.gainXp(
        StatKey.intelligence,
        1200,
      );

      expect(stats[StatKey.intelligence].radarValue, closeTo(50, 0.001));
      expect(stats[StatKey.intelligence].rank, StatRank.competent);
      expect(stats.radarValues.length, StatKey.values.length);
      expect(stats.averageRadarValue, closeTo(10, 0.001));
    });

    test('strongest / weakest doğru statı bulur', () {
      final RpgStats stats = RpgStats.initial
          .gainXp(StatKey.intelligence, 400)
          .gainXp(StatKey.productivity, 900)
          .gainXp(StatKey.strength, 50);

      expect(stats.strongest.stat, StatKey.productivity);
      expect(stats.weakest.stat, StatKey.vitality);
      expect(stats.imbalance, greaterThan(0));
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final RpgStats stats = RpgStats.initial
          .recordQuest(StatKey.intelligence, 320)
          .recordQuest(StatKey.willpower, 75);

      expect(RpgStats.fromJson(stats.toJson()), stats);
    });

    test('eksik statlar 0 XP olarak tamamlanır', () {
      final RpgStats stats = RpgStats.fromJson(<String, dynamic>{
        'INT': <String, dynamic>{'xp': 240, 'quests_completed': 3},
      });

      expect(stats[StatKey.intelligence].xp, 240);
      expect(stats[StatKey.strength].xp, 0);
      expect(stats.ordered.length, StatKey.values.length);
    });

    test('bilinmeyen stat kodu sessizce atlanır', () {
      final RpgStats stats = RpgStats.fromJson(<String, dynamic>{
        'LUCK': <String, dynamic>{'xp': 999},
        'STR': <String, dynamic>{'xp': '150'},
      });

      expect(stats[StatKey.strength].xp, 150);
      expect(stats.totalXp, 150);
    });
  });
}
