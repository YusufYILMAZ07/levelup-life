import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../domain/services/services.dart';
import 'game_state.dart';

/// Oyun döngüsünün tek yöneticisi.
///
/// Tüm mutasyonlar burada toplanır: onboarding, görev tamamlama, yeni görev,
/// enerji modu ve sıfırlama. Her değişiklikten sonra durum diske yazılır.
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
  void completeOnboarding(UserSetup setup) {
    final DateTime now = DateTime.now();
    final UserProfile profile = setup.toProfile(now: now);
    final List<Quest> quests = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    state = GameState(setup: setup, profile: profile, quests: quests);
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
    final int index =
        state.quests.indexWhere((Quest quest) => quest.id == questId);
    if (index < 0) return null;
    final Quest quest = state.quests[index];
    if (quest.isCompleted) return null;

    final DateTime now = DateTime.now();
    final int awarded = xpForQuest(profile, quest);
    final XpAward result =
        profile.completeQuest(stat: quest.stat, xp: awarded, at: now);
    final List<Quest> quests = <Quest>[...state.quests];
    quests[index] = quest.complete(at: now);

    state = state.copyWith(profile: result.profile, quests: quests);
    _persist();
    return result;
  }

  /// Bu görev tamamlandığında gerçekten verilecek XP.
  int xpForQuest(UserProfile profile, Quest quest) =>
      XpEngine.applyBonus(quest.effectiveBaseXp, profile.archetype.bonusFor(quest.stat));

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

  // ── Sıfırlama ────────────────────────────────────────────────────────────

  /// "Hedeflerimi sıfırla" — onboarding'e geri döner ve tüm ilerlemeyi siler.
  Future<void> resetJourney() async {
    state = const GameState();
    await ref.read(gameStoreProvider).clear();
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

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
