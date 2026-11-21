import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/domain/services/services.dart';

void main() {
  const UserSetup setup = UserSetup(
    displayName: 'Ada',
    role: LifeRole.student,
    studyField: 'Tıp',
    gradeYear: 2,
    goals: <GoalType>{GoalType.academic},
    tempo: DailyTempo.balanced,
  );

  late MemoryGameStore store;
  late ProviderContainer container;

  setUp(() {
    store = MemoryGameStore();
    container = ProviderContainer(
      overrides: [gameStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  GameController controller() => container.read(gameProvider.notifier);

  test('başlangıç durumu onboarding bekler', () {
    final GameState state = container.read(gameProvider);
    expect(state.isOnboarded, isFalse);
    expect(container.read(isOnboardedProvider), isFalse);
    expect(container.read(profileProvider), isNull);
  });

  test('completeOnboarding profil ve kişisel görevleri üretir', () async {
    controller().completeOnboarding(setup);
    await Future<void>.delayed(Duration.zero);

    final GameState state = container.read(gameProvider);
    expect(state.isOnboarded, isTrue);
    expect(state.profile?.displayName, 'Ada');
    expect(state.profile?.archetype, Archetype.scholar);
    expect(state.quests, hasLength(setup.dailyQuestTarget));
    expect(container.read(isOnboardedProvider), isTrue);

    // Diske yazıldı mı? Store'dan yeniden okuyup doğrula.
    final GameState? persisted = store.load();
    expect(persisted?.isOnboarded, isTrue);
    expect(persisted?.quests, hasLength(state.quests.length));
  });

  test('completeQuest arketip bonusuyla XP ekler ve görevi kapatır', () async {
    controller().completeOnboarding(setup);
    final GameState initial = container.read(gameProvider);
    final Quest quest = initial.quests.firstWhere(
      (Quest item) => item.stat == StatKey.intelligence,
    );

    final int expected = XpEngine.applyBonus(quest.baseXp, 0.15);
    expect(controller().xpForQuest(initial.profile!, quest), expected);

    final XpAward? award = controller().completeQuest(quest.id);
    await Future<void>.delayed(Duration.zero);

    expect(award, isNotNull);
    expect(award!.xpGained, expected);
    expect(award.profile.totalXp, expected);
    expect(
      container
          .read(gameProvider)
          .quests
          .firstWhere((Quest item) => item.id == quest.id)
          .isCompleted,
      isTrue,
    );
    expect(store.load()?.profile?.totalXp, expected);

    // Aynı görev ikinci kez XP kazandırmaz.
    expect(controller().completeQuest(quest.id), isNull);
    expect(container.read(gameProvider).profile?.totalXp, expected);
  });

  test('completeQuest XP\'yi günlük geçmişe de işler', () async {
    controller().completeOnboarding(setup);
    final Quest quest = container.read(gameProvider).quests.first;
    controller().completeQuest(quest.id);
    await Future<void>.delayed(Duration.zero);

    final GameState state = container.read(gameProvider);
    final int awarded = state.profile!.totalXp;

    expect(awarded, greaterThan(0));
    expect(state.xpLog.xpOn(DateTime.now()), awarded);
    expect(state.xpLog.activeDays, 1);
    expect(store.load()?.profile?.xpLog.xpOn(DateTime.now()), awarded);
  });

  test('setEnergyMode görevleri mikro varyantlara uyarlar', () async {
    controller().completeOnboarding(setup);
    controller().setEnergyMode(EnergyMode.lowEnergy);

    final GameState state = container.read(gameProvider);
    expect(state.profile?.energyMode, EnergyMode.lowEnergy);
    expect(
      state.quests.every(
        (Quest quest) => quest.energyMode == EnergyMode.lowEnergy,
      ),
      isTrue,
    );
  });

  test('addQuest özel görevi listeye ekler', () {
    controller().completeOnboarding(setup);
    final int before = container.read(gameProvider).quests.length;
    controller().addQuest(
      QuestGenerator.custom(
        title: 'Akşam yürüyüşü',
        stat: StatKey.strength,
        minutes: 25,
        difficulty: QuestDifficulty.light,
        now: DateTime(2026, 11, 15, 18),
      ),
    );

    final GameState state = container.read(gameProvider);
    expect(state.quests, hasLength(before + 1));
    expect(
      state.quests.any((Quest quest) => quest.title == 'Akşam yürüyüşü'),
      isTrue,
    );
  });

  test('resetJourney her şeyi siler ve store temizlenir', () async {
    controller().completeOnboarding(setup);
    await controller().resetJourney();

    final GameState state = container.read(gameProvider);
    expect(state.profile, isNull);
    expect(state.setup, isNull);
    expect(state.quests, isEmpty);
    expect(store.load(), isNull);
  });

  test('GameState JSON round-trip profil ve görevleri korur', () {
    controller().completeOnboarding(setup);
    final GameState original = container.read(gameProvider);

    final GameState restored = GameState.fromJson(original.toJson());
    expect(restored.isOnboarded, isTrue);
    expect(restored.profile, original.profile);
    expect(restored.setup, original.setup);
    expect(restored.quests, original.quests);
  });
}
