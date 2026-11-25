import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_mutation.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';

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

  group('refreshQuests özel görev koruması', () {
    test('addQuest isCustom işaretler ve refreshQuests silmez', () {
      final Map<String, dynamic> json = state().quests.first.toJson()
        ..['id'] = 'custom-1';
      final Quest custom = Quest.fromJson(
        json,
      ).copyWith(title: 'Kendi görevim', isCustom: true);
      expect(controller().addQuest(custom), isTrue);
      expect(
        state().quests.firstWhere((Quest q) => q.id == 'custom-1').isCustom,
        isTrue,
      );

      controller().refreshQuests();

      final Quest? kept = state().quests.cast<Quest?>().firstWhere(
        (Quest? q) => q?.id == 'custom-1',
        orElse: () => null,
      );
      expect(kept, isNotNull);
      expect(kept!.isCustom, isTrue);
      expect(kept.title, 'Kendi görevim');
      // Günlük görevler yeniden üretildi.
      expect(state().quests.where((Quest q) => !q.isCustom), isNotEmpty);
    });

    test('boş veya aşırı uzun başlıklı özel görev reddedilir', () {
      final Quest base = state().quests.first;
      expect(controller().addQuest(base.copyWith(title: '   ')), isFalse);
      expect(controller().addQuest(base.copyWith(title: 'a' * 200)), isFalse);
    });
  });

  group('toggleBucketGoal XP istismarı', () {
    test('Co-Op XP hedef başına yalnızca bir kez verilir', () {
      final BucketGoal goal = state().couple.bucketGoals.first;
      int xpOf(String id) => state().partnerData(id)?.profile?.totalXp ?? 0;

      final int yusufBefore = xpOf(CouplePartner.yusufId);
      final int ceydaBefore = xpOf(CouplePartner.ceydaId);

      expect(controller().toggleBucketGoal(goal.id), isTrue);
      expect(xpOf(CouplePartner.yusufId), yusufBefore + goal.rewardPoints);
      expect(xpOf(CouplePartner.ceydaId), ceydaBefore + goal.rewardPoints);
      expect(
        state().couple.bucketGoals
            .firstWhere((BucketGoal g) => g.id == goal.id)
            .rewardClaimed,
        isTrue,
      );

      // Geri al: XP silinmez (seviye geçmişi bozulmaz).
      expect(controller().toggleBucketGoal(goal.id), isFalse);
      expect(xpOf(CouplePartner.yusufId), yusufBefore + goal.rewardPoints);

      // Yeniden tamamla: ikinci kez XP verilmez.
      expect(controller().toggleBucketGoal(goal.id), isTrue);
      expect(xpOf(CouplePartner.yusufId), yusufBefore + goal.rewardPoints);
      expect(xpOf(CouplePartner.ceydaId), ceydaBefore + goal.rewardPoints);
    });
  });

  group('addCustomBonus doğrulaması', () {
    test('puan 1..500 ve başlık 1..80 karakter aralığında olmalı', () {
      expect(
        controller().addCustomBonus(
          title: 'Kahve',
          points: 0,
          stat: StatKey.vitality,
        ),
        isNull,
      );
      expect(
        controller().addCustomBonus(
          title: 'Kahve',
          points: -5,
          stat: StatKey.vitality,
        ),
        isNull,
      );
      expect(
        controller().addCustomBonus(
          title: 'Kahve',
          points: 501,
          stat: StatKey.vitality,
        ),
        isNull,
      );
      expect(
        controller().addCustomBonus(
          title: '   ',
          points: 10,
          stat: StatKey.vitality,
        ),
        isNull,
      );
      expect(
        controller().addCustomBonus(
          title: 'a' * 81,
          points: 10,
          stat: StatKey.vitality,
        ),
        isNull,
      );

      final XpAward? ok = controller().addCustomBonus(
        title: 'Sabah yürüyüşü',
        points: 500,
        stat: StatKey.vitality,
      );
      expect(ok, isNotNull);
      expect(ok!.xpGained, 500);
    });
  });

  group('tombstone ve uzak durum birleştirmesi', () {
    test('silinen mesaj geçmişten veya uzak durumdan geri dirilmez', () {
      final ChatMessage message = controller().sendMessage('Silinecek')!;
      expect(state().couple.messageById(message.id), isNotNull);

      expect(controller().deleteMessage(message.id), isTrue);
      expect(state().couple.messageById(message.id), isNull);
      expect(
        state().couple.deletedMessageTombstones.containsKey(message.id),
        isTrue,
      );

      // Uzak geçmiş aynı mesajı tekrar gönderse bile eklenmez.
      expect(controller().mergeRemoteMessages(<ChatMessage>[message]), 0);
      expect(state().couple.messageById(message.id), isNull);

      // Uzak tam durum da diriltemez.
      final GameState remote = state().withCouple(
        state().couple.copyWith(messages: <ChatMessage>[message]),
      );
      controller().applyRemoteState(remote);
      expect(state().couple.messageById(message.id), isNull);
      expect(
        state().couple.deletedMessageTombstones.containsKey(message.id),
        isTrue,
      );
    });

    test('tombstone JSON gidiş-dönüşünde korunur', () {
      final ChatMessage message = controller().sendMessage('Kalıcı silme')!;
      controller().deleteMessage(message.id);

      final GameState restored = GameState.fromJson(state().toJson());

      expect(
        restored.couple.deletedMessageTombstones.containsKey(message.id),
        isTrue,
      );
      expect(restored.couple.messageById(message.id), isNull);
    });

    test('silinen özel aşk notu uzak birleştirmede geri gelmez', () {
      controller().addLoveNote('Silinecek not');
      expect(state().couple.allLoveNotes.contains('Silinecek not'), isTrue);
      expect(controller().deleteLoveNote('Silinecek not'), isTrue);
      expect(state().couple.allLoveNotes.contains('Silinecek not'), isFalse);

      final CoupleState merged = state().couple.mergeLoveNotes(<String>[
        'Silinecek not',
        'Yeni not',
      ]);
      expect(merged.allLoveNotes.contains('Silinecek not'), isFalse);
      expect(merged.allLoveNotes.contains('Yeni not'), isTrue);
    });

    test('uzak durum cihaz sahibinin aktif profilini değiştirmez', () {
      final GameState remote = CoupleBootstrap.initialState().activatePartner(
        CouplePartner.ceydaId,
      );

      controller().applyRemoteState(remote, deviceRole: CouplePartner.yusufId);

      expect(state().activePartnerId, CouplePartner.yusufId);
      expect(state().isCoupleEdition, isTrue);
    });

    test('uzak mutasyon yerel revizyonu artırmaz (echo yok)', () {
      final int before = controller().localRevision;
      final GameState remote = CoupleBootstrap.initialState().withCouple(
        CoupleState(rubricScores: <String, int>{'x': 1}),
      );

      controller().applyRemoteState(remote);

      expect(controller().lastOrigin, MutationOrigin.remote);
      expect(controller().localRevision, before);

      controller().setStake(DuelStake.dinner);
      expect(controller().lastOrigin, MutationOrigin.local);
      expect(controller().localRevision, before + 1);
    });
  });

  group('mesaj etkileşimleri', () {
    test('tepki ekleme/kaldırma ve düzenleme kalıcıdır', () {
      final ChatMessage message = controller().sendMessage('İlk metin')!;

      expect(controller().reactToMessage(message.id, '❤️'), isTrue);
      ChatMessage current = state().couple.messageById(message.id)!;
      expect(current.reactorsOf('❤️'), contains(CouplePartner.yusufId));
      expect(current.reactionCount, 1);

      // Aynı partner tekrar dokunursa tepki kalkar.
      expect(controller().reactToMessage(message.id, '❤️'), isTrue);
      current = state().couple.messageById(message.id)!;
      expect(current.reactions, isEmpty);

      expect(controller().editMessage(message.id, 'Düzenlendi'), isTrue);
      current = state().couple.messageById(message.id)!;
      expect(current.text, 'Düzenlendi');
      expect(current.isEdited, isTrue);
      expect(
        GameState.fromJson(
          state().toJson(),
        ).couple.messageById(message.id)!.text,
        'Düzenlendi',
      );
    });

    test('silinen mesaja tepki veya düzenleme uygulanamaz', () {
      final ChatMessage message = controller().sendMessage('Silinir')!;
      controller().deleteMessage(message.id);
      expect(controller().reactToMessage(message.id, '🔥'), isFalse);
      expect(controller().editMessage(message.id, 'Yeni'), isFalse);
    });
  });
}
