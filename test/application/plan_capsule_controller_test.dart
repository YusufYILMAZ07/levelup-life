import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';

/// Haftalık plan blokları ve ödül kapsüllerinin denetleyici davranışları:
/// ekleme/silme, tamamlama XP'si, kanıt mesajı, kilit kontrolü ve kalıcılık.
void main() {
  late MemoryGameStore store;
  late ProviderContainer container;
  final DateTime today = DateTime.now();

  ScheduleBlock block({
    String id = 'plan-test',
    String partnerId = CouplePartner.yusufId,
    String title = 'Sabah Sporu',
    ScheduleCategory category = ScheduleCategory.workout,
  }) => ScheduleBlock(
    id: id,
    partnerId: partnerId,
    weekday: today.weekday,
    startMinutes: 9 * 60,
    endMinutes: 10 * 60,
    title: title,
    category: category,
  );

  void boot(GameState initial) {
    store = MemoryGameStore(initial);
    container = ProviderContainer(
      overrides: [gameStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  }

  GameController controller() => container.read(gameProvider.notifier);
  GameState state() => container.read(gameProvider);
  int xpOf(String partnerId) => state().partnerData(partnerId)?.totalXp ?? 0;

  setUp(() => boot(CoupleBootstrap.initialState()));

  group('plan blokları', () {
    test('addScheduleBlocks geçersizleri atlar, geçerlileri diske yazar', () {
      final int added = controller().addScheduleBlocks(<ScheduleBlock>[
        block(id: 'plan-ok'),
        block(id: 'plan-bos-baslik', title: '   '),
        ScheduleBlock(
          id: 'plan-ters',
          partnerId: CouplePartner.yusufId,
          weekday: today.weekday,
          startMinutes: 600,
          endMinutes: 600,
          title: 'Ters saat',
          category: ScheduleCategory.study,
        ),
      ]);

      expect(added, 1);
      expect(state().couple.blockById('plan-ok'), isNotNull);
      expect(state().couple.blockById('plan-bos-baslik'), isNull);
      expect(state().couple.blockById('plan-ters'), isNull);
    });

    test('removeScheduleBlock bloğu kaldırır', () {
      controller().addScheduleBlocks(<ScheduleBlock>[block(id: 'plan-sil')]);
      expect(state().couple.blockById('plan-sil'), isNotNull);

      controller().removeScheduleBlock('plan-sil');
      expect(state().couple.blockById('plan-sil'), isNull);
    });

    test('completeScheduleBlock +25 XP verir ve sohbete rozet düşer', () {
      controller().addScheduleBlocks(<ScheduleBlock>[
        block(id: 'plan-spor', title: 'Sabah Sporu'),
      ]);
      final int before = xpOf(CouplePartner.yusufId);
      final int strengthBefore = state()
          .partnerData(CouplePartner.yusufId)!
          .profile!
          .rpgStats[StatKey.strength]
          .xp;

      final ScheduleOutcome? outcome = controller().completeScheduleBlock(
        'plan-spor',
      );

      expect(outcome, isNotNull);
      expect(outcome!.xpGained, SchedulePlanner.completionXp);
      expect(outcome.alreadyCompleted, isFalse);
      expect(outcome.partnerId, CouplePartner.yusufId);
      expect(
        xpOf(CouplePartner.yusufId),
        before + SchedulePlanner.completionXp,
      );
      expect(
        state()
            .partnerData(CouplePartner.yusufId)!
            .profile!
            .rpgStats[StatKey.strength]
            .xp,
        strengthBefore + SchedulePlanner.completionXp,
      );

      final ChatMessage badge = state().couple.messages.last;
      expect(badge.kind, ChatMessageKind.questShare);
      expect(badge.questBadgeTitle, 'Sabah Sporu');
      expect(badge.earnedPoints, SchedulePlanner.completionXp);
      expect(
        state().couple.blockById('plan-spor')!.isCompletedOn(today),
        isTrue,
      );
    });

    test(
      'aynı blok ikinci kez tamamlanınca XP verilmez, işareti geri alır',
      () {
        controller().addScheduleBlocks(<ScheduleBlock>[
          block(id: 'plan-tekrar'),
        ]);
        controller().completeScheduleBlock('plan-tekrar');
        final int afterFirst = xpOf(CouplePartner.yusufId);

        final ScheduleOutcome? second = controller().completeScheduleBlock(
          'plan-tekrar',
        );

        expect(second, isNotNull);
        expect(second!.alreadyCompleted, isTrue);
        expect(second.xpGained, 0);
        expect(xpOf(CouplePartner.yusufId), afterFirst);
        expect(
          state().couple.blockById('plan-tekrar')!.isCompletedOn(today),
          isFalse,
        );
      },
    );

    test('bilinmeyen blok tamamlanamaz', () {
      final GameState before = state();
      expect(controller().completeScheduleBlock('yok-boyle-blok'), isNull);
      expect(identical(state(), before), isTrue);
    });
  });

  group('kanıt fotoğrafı', () {
    test('blok kimliğiyle gönderilen kanıt proof mesajı üretir', () {
      controller().addScheduleBlocks(<ScheduleBlock>[
        block(id: 'plan-kanit', title: 'Kütüphane Sprinti'),
      ]);
      final int before = state().couple.messages.length;

      final ChatMessage? message = controller().sendScheduleProof(
        blockId: 'plan-kanit',
      );

      expect(message, isNotNull);
      expect(state().couple.messages, hasLength(before + 1));
      expect(state().couple.messages.last.id, message!.id);
      expect(message.kind, ChatMessageKind.proof);
      expect(message.senderId, CouplePartner.yusufId);
      expect(message.questBadgeTitle, 'Kütüphane Sprinti');
      expect(message.photoDataOrUrl, ScheduleCategory.workout.presetSource);
      expect(message.photoCaption, contains('Kanıtı'));
      expect(message.hasPhoto, isTrue);
    });

    test('blok verilmezse partnerin aktif veya sıradaki bloğunu kullanır', () {
      final ChatMessage? message = controller().sendScheduleProof(
        partnerId: CouplePartner.ceydaId,
      );

      expect(message, isNotNull);
      expect(message!.kind, ChatMessageKind.proof);
      expect(message.senderId, CouplePartner.ceydaId);
      expect(message.photoDataOrUrl, isNotNull);
      expect(state().couple.photoMessages, isNotEmpty);
    });

    test('bilinmeyen blok kimliği mesaj üretmez', () {
      final int before = state().couple.messages.length;
      final ChatMessage? message = controller().sendScheduleProof(
        blockId: 'yok-boyle-blok',
        partnerId: CouplePartner.yusufId,
      );

      expect(message, isNull);
      expect(state().couple.messages, hasLength(before));
    });
  });

  group('ödül kapsülleri', () {
    final RewardCapsule lowCapsule = const RewardCapsule(
      id: 'capsule-low',
      title: 'Küçük Ödül',
      emoji: '🍫',
      description: 'Çikolata molası',
      requiredPoints: 25,
      rewardMessage: 'Çikolata senin!',
    );
    const RewardCapsule highCapsule = RewardCapsule(
      id: 'capsule-high',
      title: 'Büyük Ödül',
      emoji: '🎬',
      description: 'Sinema gecesi',
      requiredPoints: 500,
    );

    void bootWithCapsules() {
      final GameState base = CoupleBootstrap.initialState();
      boot(
        base.withCouple(
          base.couple.copyWith(
            rubricScores: <String, int>{},
            bonusActions: <BonusActionLog>[],
            rewardCapsules: <RewardCapsule>[lowCapsule, highCapsule],
          ),
        ),
      );
    }

    test(
      'kilitli kapsül açılmaz, puan dolunca açılır ve kalıcı olur',
      () async {
        bootWithCapsules();
        expect(state().couple.combinedPoints, 0);
        expect(controller().openRewardCapsule('capsule-low'), isFalse);
        expect(state().couple.capsuleById('capsule-low')!.isOpened, isFalse);

        controller().ratePillar(pillar: StatKey.intelligence, score: 2);
        expect(state().couple.combinedPoints, 25);
        expect(state().couple.unlockedCapsuleCount, 1);
        expect(state().couple.nextUnlockedCapsule?.id, 'capsule-low');

        expect(controller().openRewardCapsule('capsule-low'), isTrue);
        expect(state().couple.capsuleById('capsule-low')!.isOpened, isTrue);
        expect(state().couple.nextUnlockedCapsule, isNull);
        expect(controller().openRewardCapsule('capsule-low'), isFalse);
        expect(controller().openRewardCapsule('capsule-high'), isFalse);
        expect(controller().openRewardCapsule('yok'), isFalse);

        await Future<void>.delayed(Duration.zero);
        expect(
          store.load()!.couple.capsuleById('capsule-low')!.isOpened,
          isTrue,
        );
      },
    );

    test('addRewardCapsule doğrulama yapar ve kapsülü diske yazar', () async {
      bootWithCapsules();
      expect(
        controller().addRewardCapsule(title: '   ', requiredPoints: 100),
        isNull,
      );
      expect(
        controller().addRewardCapsule(title: 'Kahve', requiredPoints: 0),
        isNull,
      );

      final RewardCapsule? added = controller().addRewardCapsule(
        title: '  Kahve Keyfi  ',
        requiredPoints: 60,
      );

      expect(added, isNotNull);
      expect(added!.title, 'Kahve Keyfi');
      expect(added.emoji, '🎁');
      expect(added.isCustom, isTrue);
      expect(added.isOpened, isFalse);
      expect(added.rewardMessage, 'Kahve Keyfi');
      expect(state().couple.capsuleById(added.id), isNotNull);

      final RewardCapsule? custom = controller().addRewardCapsule(
        title: 'Piknik',
        requiredPoints: 90,
        emoji: '🧺',
        description: 'Sahilde',
        rewardMessage: 'Battaniye hazır!',
      );
      expect(custom!.emoji, '🧺');
      expect(custom.description, 'Sahilde');
      expect(custom.rewardMessage, 'Battaniye hazır!');

      await Future<void>.delayed(Duration.zero);
      expect(store.load()!.couple.capsuleById(custom.id), isNotNull);
    });
  });
}
