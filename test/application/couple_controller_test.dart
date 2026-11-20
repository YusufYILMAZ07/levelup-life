import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/domain/services/services.dart';

/// Çift sürümü: iki partnerli durum, partner geçişi, rubrik/sinerji, sohbet ve
/// kalıcılık davranışlarını doğrular.
void main() {
  late MemoryGameStore store;
  late ProviderContainer container;

  setUp(() {
    store = MemoryGameStore(CoupleBootstrap.initialState());
    container = ProviderContainer(
      overrides: [gameStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  GameController controller() => container.read(gameProvider.notifier);
  GameState state() => container.read(gameProvider);

  int xpOf(String partnerId) => state().partnerData(partnerId)?.totalXp ?? 0;

  test('tohum iki partneri, görevleri ve sohbeti hazırlar', () {
    expect(state().isCoupleEdition, isTrue);
    expect(state().activePartnerId, CouplePartner.yusufId);
    expect(state().partnerData(CouplePartner.ceydaId)?.profile, isNotNull);
    expect(state().quests, isNotEmpty);
    expect(state().couple.messages, isNotEmpty);
    expect(state().couple.bucketGoals, isNotEmpty);
    expect(state().profile?.firstName, 'Yusuf');
  });

  test('bir partnerde tamamlanan görev diğerine sızmaz', () async {
    final Quest quest = state().quests.first;
    controller().completeQuest(quest.id);
    await Future<void>.delayed(Duration.zero);

    expect(state().activePartnerId, CouplePartner.yusufId);
    expect(state().completedCount, 1);

    controller().switchPartner(CouplePartner.ceydaId);
    expect(state().profile?.firstName, 'Ceyda');
    expect(state().completedCount, 0);
    expect(
      state().quests
          .where((Quest item) => item.id == quest.id)
          .every((Quest item) => !item.isCompleted),
      isTrue,
    );

    controller().switchPartner(CouplePartner.yusufId);
    expect(state().completedCount, 1);
  });

  test('rubrik puanı aktif partnere XP yazar, ikinci puanlama XP üretmez', () {
    final int before = state().profile!.totalXp;

    final RubricOutcome first = controller().ratePillar(
      pillar: StatKey.willpower,
      score: 2,
    );
    expect(first.xpGained, DevelopmentRubric.xpFor(2));
    expect(state().profile!.totalXp, before + first.xpGained);
    expect(first.totalToday, greaterThan(0));

    final RubricOutcome second = controller().ratePillar(
      pillar: StatKey.willpower,
      score: 3,
    );
    expect(second.xpGained, 0);
    expect(state().profile!.totalXp, before + first.xpGained);
    expect(
      state().couple.rubricScore(
        CouplePartner.yusufId,
        StatKey.willpower,
        DateTime.now(),
      ),
      3,
    );
  });

  test(
    'iki taraf aynı alanda 2+ puana ulaşınca sinerji iki tarafa XP verir',
    () {
      // Tohumda Yusuf'un bugünkü zekâ puanı 2'dir; Ceyda da 2 verince sinerji.
      final int yusufBefore = xpOf(CouplePartner.yusufId);
      final int ceydaBefore = xpOf(CouplePartner.ceydaId);

      final RubricOutcome outcome = controller().ratePillar(
        pillar: StatKey.intelligence,
        score: 2,
        partnerId: CouplePartner.ceydaId,
      );

      expect(outcome.hasSynergy, isTrue);
      expect(outcome.synergyXp, CoupleEfficiencyEngine.synergyXp);
      expect(
        xpOf(CouplePartner.yusufId),
        yusufBefore + CoupleEfficiencyEngine.synergyXp,
      );
      expect(
        xpOf(CouplePartner.ceydaId),
        ceydaBefore +
            DevelopmentRubric.xpFor(2) +
            CoupleEfficiencyEngine.synergyXp,
      );
      expect(
        state().couple.hasSynergy(StatKey.intelligence, DateTime.now()),
        isTrue,
      );
    },
  );

  test('hızlı eylem hem XP hem gelişim ledgerına yazar', () {
    final int before = state().profile!.totalXp;
    final XpAward? award = controller().quickAction(QuickAction.pomodoro);

    expect(award?.xpGained, QuickAction.pomodoro.points);
    expect(state().profile!.totalXp, before + QuickAction.pomodoro.points);
    expect(
      state().couple.bonusPointsOn(CouplePartner.yusufId, DateTime.now()),
      greaterThanOrEqualTo(QuickAction.pomodoro.points),
    );
    expect(
      state().couple.improvementPointsOf(CouplePartner.yusufId),
      greaterThan(0),
    );
  });

  test('ortak hedef tamamlanınca iki tarafa da Co-Op XP gelir', () {
    final BucketGoal goal = state().couple.bucketGoals.first;
    final int yusufBefore = xpOf(CouplePartner.yusufId);
    final int ceydaBefore = xpOf(CouplePartner.ceydaId);

    final bool completed = controller().toggleBucketGoal(goal.id);
    expect(completed, isTrue);
    expect(xpOf(CouplePartner.yusufId), yusufBefore + goal.rewardPoints);
    expect(xpOf(CouplePartner.ceydaId), ceydaBefore + goal.rewardPoints);
    expect(
      state().couple.bucketGoals
          .firstWhere((BucketGoal g) => g.id == goal.id)
          .isDone,
      isTrue,
    );

    // Geri almak XP'yi iki kez vermez.
    controller().toggleBucketGoal(goal.id);
    expect(xpOf(CouplePartner.yusufId), yusufBefore + goal.rewardPoints);
  });

  test('mesaj, fotoğraf ve beğeni durumda saklanır', () {
    final int count = state().couple.messages.length;

    final ChatMessage? message = controller().sendMessage(
      'Bugün harikaydın 💖',
    );
    expect(message?.senderId, CouplePartner.yusufId);
    expect(state().couple.messages.length, count + 1);

    final ChatMessage? photo = controller().sendPhoto(
      photoDataOrUrl: 'preset:coffee',
      caption: 'Kahve molası',
    );
    expect(photo?.hasPhoto, isTrue);
    expect(photo?.photoDataOrUrl, 'preset:coffee');
    expect(state().couple.photoMessages, isNotEmpty);

    controller().likeMessage(photo!.id);
    expect(
      state().couple.messages
          .firstWhere((ChatMessage m) => m.id == photo.id)
          .isLiked,
      isTrue,
    );
    expect(state().couple.likedPhotoCount, greaterThan(0));
  });

  test('canlı durum, bahis ve aşk notu güncellenir', () {
    controller().setLiveStatus(
      LiveStatus.gym,
      partnerId: CouplePartner.ceydaId,
    );
    expect(state().couple.liveStatusOf(CouplePartner.ceydaId), LiveStatus.gym);
    expect(
      state().couple.liveStatusOf(CouplePartner.yusufId),
      isNot(LiveStatus.gym),
    );

    controller().setStake(DuelStake.movie);
    expect(state().couple.stake, DuelStake.movie);

    final String first = state().couple.currentLoveNote;
    controller().cycleLoveNote();
    expect(state().couple.currentLoveNote, isNot(first));

    controller().addLoveNote('Kendi notum');
    expect(state().couple.allLoveNotes.last, 'Kendi notum');
  });

  test('JSON round-trip iki partneri, sohbeti ve tercihleri korur', () {
    controller().switchPartner(CouplePartner.ceydaId);
    controller().sendMessage('Kalıcı mı?');
    controller().setStake(DuelStake.dinner);

    final GameState saved = state();
    final GameState restored = GameState.fromJson(saved.toJson());

    expect(restored.isCoupleEdition, isTrue);
    expect(restored.activePartnerId, CouplePartner.ceydaId);
    expect(restored.profile?.totalXp, saved.profile?.totalXp);
    expect(
      restored.partnerData(CouplePartner.yusufId)?.totalXp,
      saved.partnerData(CouplePartner.yusufId)?.totalXp,
    );
    expect(restored.couple.messages.length, saved.couple.messages.length);
    expect(restored.couple.messages.last.text, 'Kalıcı mı?');
    expect(restored.couple.stake, DuelStake.dinner);
    expect(restored.couple.bucketGoals.length, saved.couple.bucketGoals.length);
  });

  test('doğum günü mektubu kaydedilir, boş metin varsayılana döner', () async {
    const String custom = 'Ceyda, her gün seninle daha güçlüyüm. 💙';
    controller().setBirthdayMessage(custom);
    await Future<void>.delayed(Duration.zero);

    expect(state().couple.birthdayMessage, custom);
    expect(store.load()?.couple.birthdayMessage, custom);

    controller().setBirthdayMessage('   ');
    await Future<void>.delayed(Duration.zero);

    expect(state().couple.birthdayMessage, CoupleState.defaultBirthdayMessage);
    expect(
      store.load()?.couple.birthdayMessage,
      CoupleState.defaultBirthdayMessage,
    );
  });

  test('aynı doğum günü mektubu durumu yeniden yazmaz', () {
    final CoupleState before = state().couple;
    controller().setBirthdayMessage(CoupleState.defaultBirthdayMessage);

    expect(identical(state().couple, before), isTrue);
    expect(
      state().couple.withBirthdayMessage(''),
      same(state().couple),
    );
  });

  test('store yeniden yüklenince aynı çift durumu gelir', () async {
    controller().sendMessage('Store testi');
    await Future<void>.delayed(Duration.zero);

    final GameState? loaded = store.load();
    expect(loaded?.isCoupleEdition, isTrue);
    expect(loaded?.couple.messages.last.text, 'Store testi');
  });

  test('restartCoupleJourney tohumu yeniden yazar', () async {
    controller().sendMessage('Silinecek');
    await controller().restartCoupleJourney();

    expect(
      state().couple.messages.any((ChatMessage m) => m.text == 'Silinecek'),
      isFalse,
    );
    expect(state().isCoupleEdition, isTrue);
  });
}
