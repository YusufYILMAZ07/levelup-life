import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../domain/services/services.dart';
import 'couple_bootstrap.dart';
import 'game_state.dart';

/// Gelişim rubriğinde bir puanlamanın sonucu (kutlama/özet için).
final class RubricOutcome {
  const RubricOutcome({
    required this.partnerId,
    required this.pillar,
    required this.score,
    required this.xpGained,
    required this.leveledUp,
    required this.synergyXp,
    required this.totalToday,
  });

  final String partnerId;
  final StatKey pillar;
  final int score;

  /// Bu dokunuşla kazanılan XP (aynı gün tekrar puanlamada 0).
  final int xpGained;

  final bool leveledUp;

  /// Sinerji tetiklendiyse her iki partnerin kazandığı XP.
  final int synergyXp;

  /// Partnerin bugünkü toplam rubrik puanı (0..15).
  final int totalToday;

  bool get hasSynergy => synergyXp > 0;

  @override
  String toString() =>
      'RubricOutcome($partnerId · ${pillar.code} = $score · +$xpGained XP · '
      'sinerji: $synergyXp)';
}

/// Oyun döngüsünün tek yöneticisi.
///
/// Tüm mutasyonlar burada toplanır: onboarding, görev tamamlama, gelişim
/// rubriği, hızlı eylemler, partner geçişi, sohbet/fotoğraf, bucket list ve
/// haftalık bahis. Her değişiklikten sonra durum diske yazılır.
final class GameController extends Notifier<GameState> {
  @override
  GameState build() {
    final GameStore store = ref.watch(gameStoreProvider);
    return store.load() ?? const GameState();
  }

  // ── Onboarding ───────────────────────────────────────────────────────────

  /// 4 adımlı sihirbazın sonunda çağrılır.
  ///
  /// Profil + ilk günün kişiselleştirilmiş görevleri tek hamlede üretilir.
  /// Çift sürümünde yalnızca **aktif partner** güncellenir.
  void completeOnboarding(UserSetup setup) {
    final DateTime now = DateTime.now();
    final UserProfile profile = setup.toProfile(now: now);
    final List<Quest> quests = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    if (state.partners.isEmpty) {
      state = GameState(
        setup: setup,
        profile: profile,
        quests: quests,
        couple: state.couple,
      );
    } else {
      state = state.copyWith(setup: setup, profile: profile, quests: quests);
    }
    _persist();
  }

  // ── Partner geçişi ───────────────────────────────────────────────────────

  /// Üst bardaki segmentten partner değiştirir.
  void switchPartner(String partnerId) {
    final GameState next = state.activatePartner(partnerId);
    if (identical(next, state)) return;
    state = next;
    _persist();
  }

  /// Yusuf ↔ Ceyda geçişi.
  void toggleActivePartner() =>
      switchPartner(CouplePartner.other(state.activePartnerId));

  /// Üst bardaki canlı durum seçimi.
  void setLiveStatus(LiveStatus status, {String? partnerId}) {
    final String id = partnerId ?? state.activePartnerId;
    if (state.couple.liveStatusOf(id) == status) return;
    state = state.withCouple(state.couple.withLiveStatus(id, status));
    _persist();
  }

  // ── Görev döngüsü ────────────────────────────────────────────────────────

  /// Görevi tamamlar; kutlama/snackbar için [XpAward] döner.
  ///
  /// XP = görevin taban XP'si × (1 + arketip bonusu). Bonus UI'da ayrıca
  /// gösterilir, böylece "+%15" bilgisi şeffaf kalır.
  XpAward? completeQuest(String questId) {
    final UserProfile? profile = state.profile;
    if (profile == null) return null;
    final int index = state.quests.indexWhere(
      (Quest quest) => quest.id == questId,
    );
    if (index < 0) return null;
    final Quest quest = state.quests[index];
    if (quest.isCompleted) return null;

    final DateTime now = DateTime.now();
    final int awarded = xpForQuest(profile, quest);
    final XpAward result = profile.completeQuest(
      stat: quest.stat,
      xp: awarded,
      at: now,
    );
    final List<Quest> quests = <Quest>[...state.quests];
    quests[index] = quest.complete(at: now);

    state = state
        .copyWith(profile: result.profile, quests: quests)
        .withCouple(
          state.couple.recordQuestCompletion(
            partnerId: state.activePartnerId,
            day: now,
          ),
        );
    _persist();
    return result;
  }

  /// Bu görev tamamlandığında gerçekten verilecek XP.
  int xpForQuest(UserProfile profile, Quest quest) => XpEngine.applyBonus(
    quest.effectiveBaseXp,
    profile.archetype.bonusFor(quest.stat),
  );

  /// Modalden eklenen özel görev.
  void addQuest(Quest quest) {
    state = state.copyWith(quests: <Quest>[...state.quests, quest]);
    _persist();
  }

  void removeQuest(String questId) {
    state = state.copyWith(
      quests: state.quests
          .where((Quest quest) => quest.id != questId)
          .toList(growable: false),
    );
    _persist();
  }

  /// Günün görevlerini yeniden üretir; kullanıcının kendi ekledikleri korunur.
  void refreshQuests() {
    final UserSetup? setup = state.setup;
    final UserProfile? profile = state.profile;
    if (setup == null || profile == null) return;
    final DateTime now = DateTime.now();
    final List<Quest> daily = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    state = state.copyWith(quests: daily);
    _persist();
  }

  // ── Enerji modu ──────────────────────────────────────────────────────────

  void setEnergyMode(EnergyMode mode) {
    final UserProfile? profile = state.profile;
    if (profile == null || profile.energyMode == mode) return;
    state = state.copyWith(
      profile: profile.withEnergyMode(mode),
      quests: <Quest>[
        for (final Quest quest in state.quests) quest.applyEnergyMode(mode),
      ],
    );
    _persist();
  }

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
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final int previous = state.couple.rubricScore(id, pillar, now);
    final CoupleState nextCouple = state.couple.ratePillar(
      partnerId: id,
      pillar: pillar,
      score: score,
      day: now,
    );

    final int gained = previous > 0 || score <= 0
        ? 0
        : DevelopmentRubric.xpFor(score);
    bool leveledUp = false;
    GameState next = state;

    if (gained > 0) {
      final PartnerData data = state.partnerData(id) ?? state.activePartner;
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

    state = next;
    _persist();
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
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.fromQuickAction(
      action: action,
      partnerId: id,
      at: now,
    );
    return _awardPartner(
      partnerId: id,
      stat: action.stat,
      xp: action.points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  /// Kullanıcının kendi yazdığı bonus eylem.
  XpAward? addCustomBonus({
    required String title,
    required int points,
    required StatKey stat,
    String? partnerId,
  }) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || points <= 0) return null;
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.custom(
      title: trimmed,
      points: points,
      stat: stat,
      partnerId: id,
      at: now,
    );
    return _awardPartner(
      partnerId: id,
      stat: stat,
      xp: points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  // ── Bucket list (ortak hedefler) ─────────────────────────────────────────

  /// Ortak hedefi açar/kapatır. Tamamlanınca iki tarafa Co-Op XP gelir.
  bool toggleBucketGoal(String goalId) {
    BucketGoal? target;
    for (final BucketGoal goal in state.couple.bucketGoals) {
      if (goal.id == goalId) target = goal;
    }
    if (target == null) return false;

    final DateTime now = DateTime.now();
    final bool completing = !target.isDone;
    GameState next = state.withCouple(state.couple.toggleBucketGoal(goalId));
    if (completing) {
      next = next.grantBoth(
        stat: StatKey.willpower,
        xp: target.rewardPoints,
        at: now,
      );
    }
    state = next;
    _persist();
    return completing;
  }

  // ── Sohbet & anı albümü ──────────────────────────────────────────────────

  String _newMessageId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage _appendMessage(ChatMessage message, {bool persist = true}) {
    state = state.withCouple(state.couple.addMessage(message));
    if (persist) _persist();
    return message;
  }

  /// Aktif partner adına metin mesajı gönderir.
  ChatMessage? sendMessage(
    String text, {
    ChatMessageKind kind = ChatMessageKind.text,
  }) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return _appendMessage(
      ChatMessage(
        id: _newMessageId('msg'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        text: trimmed,
        kind: kind,
      ),
    );
  }

  /// Anı albümüne fotoğraf ekler (`preset:…`, `data:image/…` veya `https://`).
  ChatMessage? sendPhoto({
    required String photoDataOrUrl,
    String caption = '',
  }) {
    final String source = photoDataOrUrl.trim();
    if (source.isEmpty) return null;
    return _appendMessage(
      ChatMessage(
        id: _newMessageId('photo'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        photoDataOrUrl: source,
        photoCaption: caption.trim().isEmpty ? null : caption.trim(),
        kind: ChatMessageKind.photo,
      ),
    );
  }

  /// Tamamlanan görevi sohbette paylaşır (rozetli balon).
  ChatMessage? shareQuest(Quest quest, {int earnedPoints = 0}) =>
      _appendMessage(
        ChatMessage(
          id: _newMessageId('quest'),
          senderId: state.activePartnerId,
          createdAt: DateTime.now(),
          text: '${quest.effectiveTitle} görevini tamamladım!',
          questBadgeTitle: quest.effectiveTitle,
          earnedPoints: earnedPoints,
          kind: ChatMessageKind.questShare,
        ),
      );

  /// Fotoğrafı beğenir/beğeniyi kaldırır (galeri kalbi).
  void likeMessage(String messageId) {
    state = state.withCouple(state.couple.toggleMessageLike(messageId));
    _persist();
  }

  /// Partnerine dürtme gönderir ve küçük bir disiplin XP'si kazanır.
  ChatMessage? nudgePartner() {
    final String me = state.activePartnerId;
    final String target = CouplePartner.other(me);
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('nudge'),
        senderId: me,
        createdAt: DateTime.now(),
        text:
            '💫 ${CouplePartner.displayName(me)} → '
            '${CouplePartner.displayName(target)}: hadi bir puan daha!',
        kind: ChatMessageKind.nudge,
      ),
      persist: false,
    );
    _awardPartner(
      partnerId: me,
      stat: StatKey.willpower,
      xp: CoupleState.nudgeXp,
      at: DateTime.now(),
    );
    return message;
  }

  /// Üreticideki aşk notunu gönderip bir sonrakine geçer.
  ChatMessage? sendLoveNote() {
    final String note = state.couple.currentLoveNote;
    if (note.isEmpty) return null;
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('love'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        text: note,
        kind: ChatMessageKind.loveNote,
      ),
      persist: false,
    );
    state = state.withCouple(state.couple.cycleLoveNote());
    _persist();
    return message;
  }

  /// Üretici imlecini kaydırmadan sonraki notu gösterir.
  void cycleLoveNote() {
    state = state.withCouple(state.couple.cycleLoveNote());
    _persist();
  }

  /// Doğum günü için kişisel not ekler.
  void addLoveNote(String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) return;
    state = state.withCouple(state.couple.addLoveNote(trimmed));
    _persist();
  }

  // ── Haftalık bahis ───────────────────────────────────────────────────────

  void setStake(DuelStake stake) {
    if (state.couple.stake == stake) return;
    state = state.withCouple(state.couple.withStake(stake));
    _persist();
  }

  // ── Sıfırlama ────────────────────────────────────────────────────────────

  /// "Hedeflerimi sıfırla" — onboarding'e geri döner ve tüm ilerlemeyi siler.
  Future<void> resetJourney() async {
    state = const GameState();
    await ref.read(gameStoreProvider).clear();
  }

  /// Çift sürümünü tohum verisiyle yeniden başlatır (demo/hediye modu).
  Future<void> restartCoupleJourney() async {
    final GameState seeded = CoupleBootstrap.initialState();
    state = seeded;
    await ref.read(gameStoreProvider).save(seeded);
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  /// Partnerin profilini XP ile ödüller ve isteğe bağlı ek mutasyon uygular.
  XpAward? _awardPartner({
    required String partnerId,
    required StatKey stat,
    required int xp,
    required DateTime at,
    GameState Function(GameState current)? then,
  }) {
    final PartnerData data =
        state.partnerData(partnerId) ??
        (partnerId == state.activePartnerId
            ? state.activePartner
            : const PartnerData());
    final UserProfile? profile = data.profile;
    if (profile == null || xp <= 0) return null;

    final XpAward award = profile.completeQuest(stat: stat, xp: xp, at: at);
    GameState next = state.withPartner(
      partnerId,
      data.copyWith(profile: award.profile),
    );
    if (then != null) next = then(next);
    state = next;
    _persist();
    return award;
  }

  void _persist() {
    unawaited(ref.read(gameStoreProvider).save(state));
  }
}

/// Tüm ekranların dinlediği tek provider.
final NotifierProvider<GameController, GameState> gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Kısayol: onboarding tamamlandı mı?
final Provider<bool> isOnboardedProvider = Provider<bool>(
  (Ref ref) => ref.watch(gameProvider).isOnboarded,
);

/// Kısayol: aktif profil (onboarding öncesi `null`).
final Provider<UserProfile?> profileProvider = Provider<UserProfile?>(
  (Ref ref) => ref.watch(gameProvider).profile,
);

/// Aktif partnerin tam verisi (görevler dahil).
final Provider<PartnerData> activePartnerProvider = Provider<PartnerData>(
  (Ref ref) => ref.watch(gameProvider).activePartner,
);

/// Ekranda olmayan partnerin profili (üst bar / karşılaştırma kartları).
final Provider<UserProfile?> partnerProfileProvider = Provider<UserProfile?>((
  Ref ref,
) {
  final GameState state = ref.watch(gameProvider);
  return state.partnerData(CouplePartner.other(state.activePartnerId))?.profile;
});

/// Ortak çift durumu (sohbet, rubrik, bucket list).
final Provider<CoupleState> coupleStateProvider = Provider<CoupleState>(
  (Ref ref) => ref.watch(gameProvider).couple,
);

/// Haftalık verimlilik düellosu — durum değiştikçe yeniden hesaplanır.
final Provider<CoupleDuelResult> duelProvider = Provider<CoupleDuelResult>((
  Ref ref,
) {
  final GameState state = ref.watch(gameProvider);
  return CoupleEfficiencyEngine.evaluate(
    couple: state.couple,
    partners: state.partners,
  );
});

/// Sıradaki aşk notu (doğum günü üreticisi).
final Provider<String> loveNoteProvider = Provider<String>(
  (Ref ref) => ref.watch(gameProvider).couple.currentLoveNote,
);
