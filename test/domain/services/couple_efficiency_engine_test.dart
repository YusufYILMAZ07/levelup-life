import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/domain/services/services.dart';

/// Testlerde "şimdi" sabittir → 7 günlük pencere deterministiktir.
final DateTime _now = DateTime(2026, 11, 15, 12);

const Map<String, PartnerData> _noPartners = <String, PartnerData>{};

CoupleState _ratedCouple({
  required String partnerId,
  required Map<StatKey, int> scores,
  required DateTime day,
  CoupleState? from,
}) {
  CoupleState couple = from ?? const CoupleState();
  for (final MapEntry<StatKey, int> entry in scores.entries) {
    couple = couple.ratePillar(
      partnerId: partnerId,
      pillar: entry.key,
      score: entry.value,
      day: day,
    );
  }
  return couple;
}

void main() {
  group('ağırlıklar', () {
    test('dört bileşenin ağırlığı 1.0 eder', () {
      final double total = EfficiencyFactor.values.fold<double>(
        0,
        (double sum, EfficiencyFactor factor) => sum + factor.weight,
      );
      expect(total, closeTo(1.0, 1e-9));
    });

    test('rubrik %40, tutarlılık %35, bonus %15, etkileşim %10', () {
      expect(EfficiencyFactor.rubric.weight, closeTo(0.40, 1e-9));
      expect(EfficiencyFactor.consistency.weight, closeTo(0.35, 1e-9));
      expect(EfficiencyFactor.bonus.weight, closeTo(0.15, 1e-9));
      expect(EfficiencyFactor.interaction.weight, closeTo(0.10, 1e-9));
    });
  });

  group('veri yokken', () {
    test('nötr skor uygulanır ve beraberlik ilan edilir', () {
      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: const CoupleState(),
        partners: _noPartners,
        now: _now,
      );

      expect(duel.yusuf.hasData, isFalse);
      expect(duel.ceyda.hasData, isFalse);
      expect(duel.yusuf.score, CoupleEfficiencyEngine.neutralScore);
      expect(duel.ceyda.score, CoupleEfficiencyEngine.neutralScore);
      expect(duel.isTie, isTrue);
      expect(duel.hasAnyData, isFalse);
      expect(duel.leaderId, isEmpty);
      expect(duel.headline, contains('İlk puanlar'));
      expect(duel.couplePercent, CoupleEfficiencyEngine.neutralScore.round());
    });
  });

  group('rubrik ve tutarlılık', () {
    test('tam rubrik haftası yüksek skor üretir', () {
      CoupleState couple = const CoupleState();
      for (int i = 0; i < CoupleEfficiencyEngine.windowDays; i++) {
        final DateTime day = DateTime(2026, 11, 9 + i, 12);
        couple = _ratedCouple(
          partnerId: CouplePartner.yusufId,
          day: day,
          from: couple,
          scores: const <StatKey, int>{
            StatKey.intelligence: 3,
            StatKey.productivity: 3,
            StatKey.strength: 2,
            StatKey.vitality: 2,
            StatKey.willpower: 2,
          },
        );
      }
      couple = couple.recordQuestCompletion(
        partnerId: CouplePartner.yusufId,
        day: _now,
        count: 21,
      );

      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: couple,
        partners: _noPartners,
        now: _now,
      );

      expect(duel.yusuf.hasData, isTrue);
      expect(duel.yusuf.ratedDays, CoupleEfficiencyEngine.windowDays);
      expect(duel.yusuf.rubric, greaterThan(0.8));
      expect(duel.yusuf.consistency, greaterThan(0.4));
      expect(duel.yusuf.percent, greaterThan(50));
      expect(duel.yusuf.strongestPillar, StatKey.intelligence);
    });

    test('tek taraflı veride diğer partner nötr kalır ve fark adil olur', () {
      final CoupleState couple = _ratedCouple(
        partnerId: CouplePartner.ceydaId,
        day: _now,
        scores: const <StatKey, int>{StatKey.intelligence: 3},
      );

      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: couple,
        partners: _noPartners,
        now: _now,
      );

      expect(duel.yusuf.hasData, isFalse);
      expect(duel.yusuf.score, CoupleEfficiencyEngine.neutralScore);
      expect(duel.ceyda.hasData, isTrue);
      expect(duel.isTie, isFalse);
      expect(duel.leaderId, CouplePartner.ceydaId);
      expect(duel.gap, greaterThan(0));
    });

    test('eşit skorlar beraberlik olarak raporlanır', () {
      CoupleState couple = _ratedCouple(
        partnerId: CouplePartner.yusufId,
        day: _now,
        scores: const <StatKey, int>{StatKey.intelligence: 2},
      );
      couple = _ratedCouple(
        partnerId: CouplePartner.ceydaId,
        day: _now,
        from: couple,
        scores: const <StatKey, int>{StatKey.intelligence: 2},
      );

      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: couple,
        partners: _noPartners,
        now: _now,
      );

      expect(duel.isTie, isTrue);
      expect(duel.leaderId, isEmpty);
      expect(duel.headline, contains('Berabere'));
    });
  });

  group('sinerji', () {
    test(
      'iki taraf 2+ puana ulaşınca uygunluk doğar, tek sefer ödül verilir',
      () {
        CoupleState couple = _ratedCouple(
          partnerId: CouplePartner.yusufId,
          day: _now,
          scores: const <StatKey, int>{StatKey.vitality: 2},
        );
        expect(
          CoupleEfficiencyEngine.isSynergyEligible(
            couple,
            StatKey.vitality,
            _now,
          ),
          isFalse,
        );

        couple = _ratedCouple(
          partnerId: CouplePartner.ceydaId,
          day: _now,
          from: couple,
          scores: const <StatKey, int>{StatKey.vitality: 2},
        );
        expect(
          CoupleEfficiencyEngine.shouldAwardSynergy(
            couple,
            StatKey.vitality,
            _now,
          ),
          isTrue,
        );

        couple = couple.markSynergy(pillar: StatKey.vitality, day: _now);
        expect(
          CoupleEfficiencyEngine.shouldAwardSynergy(
            couple,
            StatKey.vitality,
            _now,
          ),
          isFalse,
        );
      },
    );

    test('her sinerji çift skoruna 5 puan ekler (en fazla 3 sayılır)', () {
      final CoupleDuelResult base = CoupleEfficiencyEngine.evaluate(
        couple: const CoupleState(),
        partners: _noPartners,
        now: _now,
      );

      CoupleState couple = const CoupleState();
      for (final StatKey pillar in <StatKey>[
        StatKey.intelligence,
        StatKey.vitality,
        StatKey.strength,
        StatKey.productivity,
      ]) {
        couple = couple.markSynergy(pillar: pillar, day: _now);
      }

      final CoupleDuelResult boosted = CoupleEfficiencyEngine.evaluate(
        couple: couple,
        partners: _noPartners,
        now: _now,
      );

      expect(boosted.synergyCount, 4);
      expect(
        boosted.coupleScore - base.coupleScore,
        closeTo(
          CoupleEfficiencyEngine.maxSynergyForScore *
              CoupleEfficiencyEngine.synergyBonusPoints,
          1e-9,
        ),
      );
      expect(boosted.couplePercent, lessThanOrEqualTo(100));
    });
  });

  group('haftalık XP', () {
    UserProfile profileWithXp(Map<DateTime, int> xpByDay) {
      DailyXpLog log = DailyXpLog.empty;
      for (final MapEntry<DateTime, int> entry in xpByDay.entries) {
        log = log.record(at: entry.key, xp: entry.value);
      }
      return UserProfile.starter(
        id: CouplePartner.yusufId,
        displayName: 'Yusuf',
        createdAt: DateTime(2026, 11, 1),
      ).copyWith(xpLog: log);
    }

    test('pencere içindeki günlük XP toplamı partner bazında raporlanır', () {
      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: const CoupleState(),
        partners: <String, PartnerData>{
          CouplePartner.yusufId: PartnerData(
            profile: profileWithXp(<DateTime, int>{
              DateTime(2026, 11, 15, 9): 40,
              DateTime(2026, 11, 12, 18): 25,
              DateTime(2026, 10, 31, 10): 90, // pencere dışı
            }),
          ),
        },
        now: _now,
      );

      expect(duel.yusuf.weeklyXp, 65);
      expect(duel.ceyda.weeklyXp, 0);
    });

    test('profil yoksa haftalık XP sıfır kalır', () {
      final CoupleDuelResult duel = CoupleEfficiencyEngine.evaluate(
        couple: const CoupleState(),
        partners: const <String, PartnerData>{
          CouplePartner.yusufId: PartnerData(),
        },
        now: _now,
      );

      expect(duel.yusuf.weeklyXp, 0);
      expect(duel.yusuf.hasData, isFalse);
    });
  });
}
