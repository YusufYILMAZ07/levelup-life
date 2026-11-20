import 'dart:math' as math;

import '../../core/utils/date_x.dart';
import '../entities/entities.dart';

/// Verimlilik skorunun dört bileşeni (ağırlıkları [CoupleEfficiencyEngine.weights]).
enum EfficiencyFactor {
  rubric(
    label: 'Rubrik Kalitesi',
    emoji: '🎯',
    hint: 'Günlük 1-2-3 puanlarının kalitesi ve kapsamı.',
    weight: 0.40,
  ),
  consistency(
    label: 'Tutarlılık',
    emoji: '📅',
    hint: 'Aktif gün sayısı + tamamlanan görev oranı.',
    weight: 0.35,
  ),
  bonus(
    label: 'Bonus Eylemler',
    emoji: '⚡',
    hint: 'Gelişim sekmesindeki hızlı eylem puanları.',
    weight: 0.15,
  ),
  interaction(
    label: 'Çift Etkileşimi',
    emoji: '💬',
    hint: 'Sohbet, fotoğraf, dürtme ve aşk notu paylaşımı.',
    weight: 0.10,
  );

  const EfficiencyFactor({
    required this.label,
    required this.emoji,
    required this.hint,
    required this.weight,
  });

  final String label;
  final String emoji;
  final String hint;

  /// Toplam skordaki ağırlık (0..1). Dört ağırlığın toplamı 1.0'dır.
  final double weight;
}

/// Tek bir partnerin 7 günlük verimlilik dökümü.
final class PartnerEfficiency {
  const PartnerEfficiency({
    required this.partnerId,
    required this.partnerName,
    required this.score,
    required this.rubric,
    required this.consistency,
    required this.bonus,
    required this.interaction,
    required this.activeDays,
    required this.ratedDays,
    required this.questsDone,
    required this.bonusPoints,
    required this.interactions,
    required this.synergyCount,
    required this.strongestPillar,
    required this.hasData,
    this.weeklyXp = 0,
  });

  final String partnerId;
  final String partnerName;

  /// 0..100 arası ağırlıklı toplam skor (sinerji bonusu dahil).
  final double score;

  /// Bileşen skorları (0..1).
  final double rubric;
  final double consistency;
  final double bonus;
  final double interaction;

  final int activeDays;
  final int ratedDays;
  final int questsDone;
  final int bonusPoints;
  final int interactions;
  final int synergyCount;

  /// Pencerede günlük XP geçmişinden toplanan toplam XP.
  final int weeklyXp;

  /// Penceredeki en güçlü yaşam alanı (rubrik yoksa `null`).
  final StatKey? strongestPillar;

  /// Pencere içinde hiçbir sinyal yok mu? (nötr skor uygulanır)
  final bool hasData;

  int get percent => score.round().clamp(0, 100);

  double factor(EfficiencyFactor component) => switch (component) {
    EfficiencyFactor.rubric => rubric,
    EfficiencyFactor.consistency => consistency,
    EfficiencyFactor.bonus => bonus,
    EfficiencyFactor.interaction => interaction,
  };

  int factorPercent(EfficiencyFactor component) =>
      (factor(component) * 100).round().clamp(0, 100);

  /// En güçlü alanın görünen adı.
  String get strongestLabel => strongestPillar == null
      ? 'Henüz yok'
      : DevelopmentRubric.forStat(strongestPillar!).title;

  @override
  String toString() =>
      'PartnerEfficiency($partnerName · ${score.toStringAsFixed(1)}%)';

  static const PartnerEfficiency empty = PartnerEfficiency(
    partnerId: '',
    partnerName: '',
    score: 0,
    rubric: 0,
    consistency: 0,
    bonus: 0,
    interaction: 0,
    activeDays: 0,
    ratedDays: 0,
    questsDone: 0,
    bonusPoints: 0,
    interactions: 0,
    synergyCount: 0,
    strongestPillar: null,
    hasData: false,
  );
}

/// Haftalık düellonun sonucu.
final class CoupleDuelResult {
  const CoupleDuelResult({
    required this.partners,
    required this.coupleScore,
    required this.synergyCount,
    required this.stake,
    required this.windowStart,
    required this.windowEnd,
  });

  final Map<String, PartnerEfficiency> partners;

  /// İki partnerin ortalaması + sinerji bonusu (0..100).
  final double coupleScore;

  /// Penceredeki toplam sinerji sayısı.
  final int synergyCount;

  final DuelStake stake;
  final DateTime windowStart;
  final DateTime windowEnd;

  PartnerEfficiency forPartner(String partnerId) =>
      partners[partnerId] ?? PartnerEfficiency.empty;

  PartnerEfficiency get yusuf => forPartner(CouplePartner.yusufId);
  PartnerEfficiency get ceyda => forPartner(CouplePartner.ceydaId);

  bool get isTie {
    if (yusuf.hasData != ceyda.hasData) return false;
    return yusuf.percent == ceyda.percent;
  }

  bool get hasAnyData => yusuf.hasData || ceyda.hasData;

  int get gap => (yusuf.score - ceyda.score).abs().round();

  int get couplePercent => coupleScore.round().clamp(0, 100);

  PartnerEfficiency get leader {
    // Veri girmeyen partner, veri giren partneri "geçemez": nötr skor
    // yalnızca karşılaştırma boş kalmasın diye gösterilir.
    if (yusuf.hasData != ceyda.hasData) {
      return yusuf.hasData ? yusuf : ceyda;
    }
    if (isTie) return yusuf;
    return yusuf.percent > ceyda.percent ? yusuf : ceyda;
  }

  /// Berabere veya veri yoksa boş string.
  String get leaderId => isTie || !hasAnyData ? '' : leader.partnerId;

  String get headline {
    if (!hasAnyData) return 'İlk puanlar girildiğinde yarış başlıyor ✨';
    if (yusuf.hasData != ceyda.hasData) {
      final PartnerEfficiency withData = yusuf.hasData ? yusuf : ceyda;
      return '${withData.partnerName} veri girdi · diğer partner bekleniyor';
    }
    if (isTie) return 'Berabere! Bahis hafta sonuna ertelendi 💫';
    if (gap == 0) return '${leader.partnerName} önde';
    return '${leader.partnerName} önde · $gap puan fark';
  }

  @override
  String toString() =>
      'CoupleDuelResult(Yusuf ${yusuf.percent} · Ceyda ${ceyda.percent} · çift $couplePercent)';
}

/// İki partnerin haftalık verimliliğini hesaplayan motor.
///
abstract final class CoupleEfficiencyEngine {
  static const int windowDays = 7;

  /// Sinerji başına çift skoruna eklenen puan.
  static const double synergyBonusPoints = 5;

  /// Sinerji başına **her iki** partnere verilen XP.
  static const int synergyXp = CoupleState.synergyBonusXp;

  /// Veri yoksa gösterilen nötr skor.
  static const double neutralScore = 50;

  /// Haftada 100 bonus puanı hedefi tamamlar.
  static const int bonusTargetPoints = 100;

  /// Haftada 10 etkileşim hedefi tamamlar.
  static const int interactionTarget = 10;

  /// Çift skoruna eklenecek maksimum sinerji sayısı (spam koruması).
  static const int maxSynergyForScore = 3;

  static CoupleDuelResult evaluate({
    required CoupleState couple,
    required Map<String, PartnerData> partners,
    DateTime? now,
  }) {
    final DateTime today = DateX.today(now ?? DateTime.now());
    final DateTime start = DateX.shiftDays(today, -(windowDays - 1));
    final List<DateTime> days = <DateTime>[
      for (int i = 0; i < windowDays; i++) DateX.shiftDays(start, i),
    ];

    int synergyCount = 0;
    for (final DateTime day in days) {
      synergyCount += couple.synergyCountOn(day);
    }

    final Map<String, PartnerEfficiency> results = <String, PartnerEfficiency>{
      for (final String id in CouplePartner.ids)
        id: _evaluatePartner(
          partnerId: id,
          data: partners[id],
          couple: couple,
          days: days,
          start: start,
          today: today,
        ),
    };

    final double average =
        (results[CouplePartner.yusufId]!.score +
            results[CouplePartner.ceydaId]!.score) /
        2;
    final double coupleScore =
        (average +
                math.min(synergyCount, maxSynergyForScore) * synergyBonusPoints)
            .clamp(0, 100)
            .toDouble();

    return CoupleDuelResult(
      partners: results,
      coupleScore: coupleScore,
      synergyCount: synergyCount,
      stake: couple.stake,
      windowStart: start,
      windowEnd: today,
    );
  }

  /// Aynı gün aynı alanda iki taraf da 2+ puan aldı mı?
  static bool isSynergyEligible(
    CoupleState couple,
    StatKey pillar,
    DateTime day,
  ) =>
      couple.rubricScore(CouplePartner.yusufId, pillar, day) >= 2 &&
      couple.rubricScore(CouplePartner.ceydaId, pillar, day) >= 2;

  /// Sinerji daha önce verilmediyse ödüllendirilmeli mi?
  static bool shouldAwardSynergy(
    CoupleState couple,
    StatKey pillar,
    DateTime day,
  ) =>
      isSynergyEligible(couple, pillar, day) && !couple.hasSynergy(pillar, day);

  static PartnerEfficiency _evaluatePartner({
    required String partnerId,
    required CoupleState couple,
    required List<DateTime> days,
    required DateTime start,
    required DateTime today,
    PartnerData? data,
  }) {
    final UserProfile? profile = data?.profile;
    final String name =
        data?.displayName ?? CouplePartner.displayName(partnerId);

    int ratedDays = 0;
    int rubricTotal = 0;
    int activeDays = 0;
    int questsDone = 0;
    int bonusPoints = 0;
    int weeklyXp = 0;
    final Map<StatKey, int> pillarTotals = <StatKey, int>{
      for (final PillarDefinition pillar in DevelopmentRubric.pillars)
        pillar.stat: 0,
    };

    for (final DateTime day in days) {
      final int total = couple.rubricTotalOn(partnerId, day);
      if (total > 0) ratedDays++;
      rubricTotal += total;
      for (final PillarDefinition pillar in DevelopmentRubric.pillars) {
        pillarTotals[pillar.stat] =
            pillarTotals[pillar.stat]! +
            couple.rubricScore(partnerId, pillar.stat, day);
      }
      if ((profile?.xpLog.xpOn(day) ?? 0) > 0) activeDays++;
      weeklyXp += profile?.xpLog.xpOn(day) ?? 0;
      questsDone += couple.questsCompletedOn(partnerId, day);
      bonusPoints += couple.bonusPointsOn(partnerId, day);
    }

    int interactions = 0;
    for (final ChatMessage message in couple.messages) {
      if (message.senderId != partnerId) continue;
      final DateTime day = DateX.dateOnly(message.createdAt);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      interactions++;
      if (message.hasPhoto && message.isLiked) interactions++;
    }

    StatKey? strongest;
    int strongestValue = 0;
    for (final MapEntry<StatKey, int> entry in pillarTotals.entries) {
      if (entry.value > strongestValue) {
        strongest = entry.key;
        strongestValue = entry.value;
      }
    }

    final double rubricCoverage = ratedDays / windowDays;
    final double rubricQuality = ratedDays == 0
        ? 0
        : rubricTotal /
              (ratedDays *
                  DevelopmentRubric.maxScore *
                  DevelopmentRubric.pillarCount);
    final double rubricScore = (rubricCoverage * 0.6 + rubricQuality * 0.4)
        .clamp(0.0, 1.0);

    final int targetQuests = math.max(
      1,
      (profile?.dailyQuestTarget ?? 3) * windowDays,
    );
    final double questRate = (questsDone / targetQuests).clamp(0.0, 1.0);
    final double activeRate = (activeDays / windowDays).clamp(0.0, 1.0);
    final double consistencyScore = (questRate * 0.55 + activeRate * 0.45)
        .clamp(0.0, 1.0);

    final double bonusScore = (bonusPoints / bonusTargetPoints).clamp(0.0, 1.0);
    final double interactionScore = (interactions / interactionTarget).clamp(
      0.0,
      1.0,
    );

    final bool hasData =
        ratedDays > 0 ||
        activeDays > 0 ||
        bonusPoints > 0 ||
        interactions > 0 ||
        questsDone > 0;

    final double weighted =
        EfficiencyFactor.rubric.weight * rubricScore +
        EfficiencyFactor.consistency.weight * consistencyScore +
        EfficiencyFactor.bonus.weight * bonusScore +
        EfficiencyFactor.interaction.weight * interactionScore;

    final double score = hasData
        ? (weighted * 100).clamp(0, 100)
        : neutralScore;

    return PartnerEfficiency(
      partnerId: partnerId,
      partnerName: name,
      score: score.toDouble(),
      rubric: rubricScore,
      consistency: consistencyScore,
      bonus: bonusScore,
      interaction: interactionScore,
      activeDays: activeDays,
      ratedDays: ratedDays,
      questsDone: questsDone,
      bonusPoints: bonusPoints,
      interactions: interactions,
      synergyCount: synergyCountFor(couple, days),
      strongestPillar: strongest,
      hasData: hasData,
      weeklyXp: weeklyXp,
    );
  }

  /// Penceredeki sinerji sayısı (çift seviyesinde ortaktır).
  static int synergyCountFor(CoupleState couple, List<DateTime> days) =>
      days.fold<int>(
        0,
        (int sum, DateTime day) => sum + couple.synergyCountOn(day),
      );
}
