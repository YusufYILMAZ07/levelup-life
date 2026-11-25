import '../../domain/entities/entities.dart';
import '../../domain/services/quest_generator.dart';
import '../../domain/services/xp_engine.dart';
import '../game_mutation.dart';
import '../game_state.dart';

/// Onboarding, günlük/özel görevler, enerji modu ve XP/level hesapları.
///
/// v6'da 962 satırlık `GameController` sınıfından ayrıştırıldı. Sınıf durumu
/// kendisi tutmaz; tek gerçek `GameController`'dır ve mutasyonlar
/// [GameStateAccess.commit] üzerinden yapılır.
final class QuestController {
  QuestController(this._game);

  final GameStateAccess _game;

  /// Özel görev başlığının üst sınırı (UI taşmasını ve JSON şişmesini önler).
  static const int maxCustomTitleLength = 120;

  GameState get _state => _game.state;

  // ── Onboarding ───────────────────────────────────────────────────────────

  /// 4 adımlı sihirbazın sonunda çağrılır.
  ///
  /// Profil + ilk günün kişiselleştirilmiş görevleri tek hamlede üretilir.
  /// Çift sürümünde yalnızca **aktif partner** güncellenir.
  void completeOnboarding(UserSetup setup) {
    final DateTime now = DateTime.now();
    final UserProfile profile = setup.toProfile(now: now);
    final List<Quest> generated = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    if (_state.partners.isEmpty) {
      _game.commit(
        GameState(
          setup: setup,
          profile: profile,
          quests: generated,
          couple: _state.couple,
        ),
      );
      return;
    }
    // Çift sürümünde kullanıcının özel görevleri onboarding yenilenirken
    // kaybolmasın: yalnızca üretilen günlük görevler değişir.
    final List<Quest> custom = _customQuests(_state.quests);
    _game.commit(
      _state.copyWith(
        setup: setup,
        profile: profile,
        quests: _dedupe(<Quest>[...generated, ...custom]),
      ),
    );
  }

  // ── Görev döngüsü ────────────────────────────────────────────────────────

  /// Görevi tamamlar; kutlama/snackbar için [XpAward] döner.
  ///
  /// XP = görevin taban XP'si × (1 + arketip bonusu). Bonus UI'da ayrıca
  /// gösterilir, böylece "+%15" bilgisi şeffaf kalır.
  XpAward? completeQuest(String questId) {
    final UserProfile? profile = _state.profile;
    if (profile == null) return null;
    final int index = _state.quests.indexWhere(
      (Quest quest) => quest.id == questId,
    );
    if (index < 0) return null;
    final Quest quest = _state.quests[index];
    if (quest.isCompleted) return null;

    final DateTime now = DateTime.now();
    final int awarded = xpForQuest(profile, quest);
    final XpAward result = profile.completeQuest(
      stat: quest.stat,
      xp: awarded,
      at: now,
    );
    final List<Quest> quests = <Quest>[..._state.quests];
    quests[index] = quest.complete(at: now);

    _game.commit(
      _state
          .copyWith(profile: result.profile, quests: quests)
          .withCouple(
            _state.couple.recordQuestCompletion(
              partnerId: _state.activePartnerId,
              day: now,
            ),
          ),
    );
    return result;
  }

  /// Bu görev tamamlandığında gerçekten verilecek XP.
  int xpForQuest(UserProfile profile, Quest quest) => XpEngine.applyBonus(
    quest.effectiveBaseXp,
    profile.archetype.bonusFor(quest.stat),
  );

  /// Modalden eklenen özel görev.
  ///
  /// Görev otomatik olarak `isCustom: true` işaretlenir; günlük yenileme
  /// ([refreshQuests]) bu kayıtları silmez.
  bool addQuest(Quest quest) {
    final String title = quest.title.trim();
    if (title.isEmpty || title.length > maxCustomTitleLength) return false;
    final Quest custom = quest.copyWith(
      title: title,
      isCustom: true,
      status: quest.isCompleted ? QuestStatus.completed : QuestStatus.active,
    );
    _game.commit(_state.copyWith(quests: <Quest>[..._state.quests, custom]));
    return true;
  }

  void removeQuest(String questId) {
    final List<Quest> next = _state.quests
        .where((Quest quest) => quest.id != questId)
        .toList(growable: false);
    if (next.length == _state.quests.length) return;
    _game.commit(_state.copyWith(quests: next));
  }

  /// Günün görevlerini yeniden üretir.
  ///
  /// **v6 hatası kapatıldı:** v5'te `state = state.copyWith(quests: daily)`
  /// kullanıcının `addQuest` ile eklediği görevleri siliyordu. Artık özel
  /// görevler ([Quest.isCustom]) ayrıştırılır ve üretilen listeye eklenir.
  void refreshQuests() {
    final UserSetup? setup = _state.setup;
    final UserProfile? profile = _state.profile;
    if (setup == null || profile == null) return;
    final DateTime now = DateTime.now();
    final List<Quest> daily = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    final List<Quest> custom = _customQuests(_state.quests);
    _game.commit(
      _state.copyWith(quests: _dedupe(<Quest>[...daily, ...custom])),
    );
  }

  // ── Enerji modu ──────────────────────────────────────────────────────────

  void setEnergyMode(EnergyMode mode) {
    final UserProfile? profile = _state.profile;
    if (profile == null || profile.energyMode == mode) return;
    _game.commit(
      _state.copyWith(
        profile: profile.withEnergyMode(mode),
        quests: <Quest>[
          for (final Quest quest in _state.quests) quest.applyEnergyMode(mode),
        ],
      ),
    );
  }

  static List<Quest> _customQuests(Iterable<Quest> quests) => <Quest>[
    for (final Quest quest in quests)
      if (quest.isCustom) quest,
  ];

  /// Üretilen ve özel görevler aynı kimliğe sahipse ilk kayıt korunur.
  static List<Quest> _dedupe(Iterable<Quest> quests) {
    final Set<String> seen = <String>{};
    return <Quest>[
      for (final Quest quest in quests)
        if (seen.add(quest.id)) quest,
    ];
  }
}
