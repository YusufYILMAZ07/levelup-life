import '../../domain/entities/entities.dart';
import '../../domain/services/couple_efficiency_engine.dart';
import '../game_mutation.dart';
import '../game_state.dart';
import '../game_outcomes.dart';

/// 5 alanlı gelişim rubriği (1-2-3), sinerji ve bonus eylemler.
final class DevelopmentController {
  DevelopmentController(this._game);

  final GameStateAccess _game;

  /// Özel bonus başlığı için üst sınır.
  static const int maxBonusTitleLength = 80;

  /// Tek dokunuşta verilebilecek en yüksek bonus puanı (XP istismarını önler).
  static const int maxBonusPoints = 500;

  static const int maxCapsuleTitleLength = 120;
  static const int maxCapsulePoints = 10000;

  GameState get _state => _game.state;

  // ── Gelişim rubriği (1-2-3) ──────────────────────────────────────────────

  /// Bir yaşam alanına 1-2-3 puanı verir.
  ///
  /// Aynı gün ilk puanlamada XP kazanılır; düzeltmeler XP üretmez
  /// (puan avcılığını engeller). İki taraf da aynı alanda 2+ puana ulaşırsa
  /// sinerji bonusu **her iki** partnere verilir.
  RubricOutcome ratePillar({
    required StatKey pillar,
    required int score,
    String? partnerId,
  }) {
    final String id = partnerId ?? _state.activePartnerId;
    final DateTime now = DateTime.now();
    final int previous = _state.couple.rubricScore(id, pillar, now);
    final CoupleState nextCouple = _state.couple.ratePillar(
      partnerId: id,
      pillar: pillar,
      score: score,
      day: now,
    );

    final int gained = previous > 0 || score <= 0
        ? 0
        : DevelopmentRubric.xpFor(score);
    bool leveledUp = false;
    GameState next = _state;

    if (gained > 0) {
      final PartnerData data = _game.partnerDataOr(id);
      final UserProfile? profile = data.profile;
      if (profile != null) {
        final XpAward award = profile.completeQuest(
          stat: pillar,
          xp: gained,
          at: now,
        );
        leveledUp = award.leveledUp;
        next = next.withPartner(id, data.copyWith(profile: award.profile));
      }
    }

    next = next.withCouple(nextCouple);

    int synergyXp = 0;
    if (score >= 2 &&
        CoupleEfficiencyEngine.shouldAwardSynergy(next.couple, pillar, now)) {
      next = next
          .withCouple(next.couple.markSynergy(pillar: pillar, day: now))
          .grantBoth(
            stat: pillar,
            xp: CoupleEfficiencyEngine.synergyXp,
            at: now,
          );
      synergyXp = CoupleEfficiencyEngine.synergyXp;
    }

    _game.commit(next);
    return RubricOutcome(
      partnerId: id,
      pillar: pillar,
      score: score,
      xpGained: gained,
      leveledUp: leveledUp,
      synergyXp: synergyXp,
      totalToday: next.couple.rubricTotalOn(id, now),
    );
  }

  // ── Hızlı bonus eylemler ─────────────────────────────────────────────────

  /// Gelişim sekmesindeki tek dokunuşluk eylem.
  XpAward? quickAction(QuickAction action, {String? partnerId}) {
    final String id = partnerId ?? _state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.fromQuickAction(
      action: action,
      partnerId: id,
      at: now,
    );
    return _game.awardPartner(
      partnerId: id,
      stat: action.stat,
      xp: action.points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  /// Kullanıcının kendi yazdığı bonus eylem.
  ///
  /// **v6:** başlık boş olamaz ve [maxBonusTitleLength] karakteri geçemez;
  /// puan `1..maxBonusPoints` aralığında olmalıdır. v5'te yalnızca `> 0`
  /// kontrolü vardı; tek istekle milyonlarca XP yazılabiliyordu.
  XpAward? addCustomBonus({
    required String title,
    required int points,
    required StatKey stat,
    String? partnerId,
  }) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > maxBonusTitleLength) return null;
    if (points <= 0 || points > maxBonusPoints) return null;
    final String id = partnerId ?? _state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.custom(
      title: trimmed,
      points: points,
      stat: stat,
      partnerId: id,
      at: now,
    );
    return _game.awardPartner(
      partnerId: id,
      stat: stat,
      xp: points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  // ── Ödül kapsülleri ──────────────────────────────────────────────────────

  /// Eşiği dolmuş kapsülü açar. Kilitliyse `false` döner.
  bool openRewardCapsule(String capsuleId) {
    final CoupleState next = _state.couple.openCapsule(capsuleId);
    if (identical(next, _state.couple)) return false;
    _game.commit(_state.withCouple(next));
    return true;
  }

  /// Yusuf & Ceyda'nın kendi ödül kapsülünü ekler.
  RewardCapsule? addRewardCapsule({
    required String title,
    required int requiredPoints,
    String emoji = '🎁',
    String description = '',
    String rewardMessage = '',
  }) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > maxCapsuleTitleLength) return null;
    if (requiredPoints <= 0 || requiredPoints > maxCapsulePoints) return null;
    final String cleanEmoji = emoji.trim().isEmpty ? '🎁' : emoji.trim();
    final RewardCapsule capsule = RewardCapsule(
      id: 'capsule-${DateTime.now().microsecondsSinceEpoch}',
      title: trimmed,
      emoji: cleanEmoji,
      description: description.trim(),
      requiredPoints: requiredPoints,
      rewardMessage: rewardMessage.trim().isEmpty
          ? trimmed
          : rewardMessage.trim(),
      isCustom: true,
    );
    _game.commit(_state.withCouple(_state.couple.addCapsule(capsule)));
    return capsule;
  }
}
