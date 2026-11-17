import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/domain/entities/entities.dart';

/// Ödül kapsüllerinin puan eşiği mantığı ve [CoupleState] üzerindeki
/// türetilmiş kapsül yardımcıları.
void main() {
  final DateTime day = DateTime(2026, 11, 17);

  CoupleState seeded() => CoupleBootstrap.initialState(now: day).couple;

  RewardCapsule capsule({
    String id = 'capsule-test',
    String title = 'Test Kapsülü',
    int requiredPoints = 50,
    String emoji = '🎁',
    String rewardMessage = 'Açıldı!',
    bool isOpened = false,
  }) => RewardCapsule(
    id: id,
    title: title,
    emoji: emoji,
    description: 'Kilitliyken görünen açıklama',
    requiredPoints: requiredPoints,
    rewardMessage: rewardMessage,
    isOpened: isOpened,
  );

  /// Hiç puanı olmayan çift durumu (puan testlerinde taban çizgisi).
  CoupleState zeroPointsState() => seeded().copyWith(
    rubricScores: <String, int>{},
    bonusActions: <BonusActionLog>[],
  );

  group('RewardCapsule eşik hesabı', () {
    test('eşiğe ulaşınca kilit açılır', () {
      final RewardCapsule item = capsule(requiredPoints: 250);
      expect(item.thresholdLabel, '250 Puan Kapsülü');
      expect(item.isUnlockedFor(249), isFalse);
      expect(item.isUnlockedFor(250), isTrue);
      expect(item.isUnlockedFor(400), isTrue);
    });

    test('ilerleme 0..1 arasına kırpılır', () {
      final RewardCapsule item = capsule(requiredPoints: 200);
      expect(item.progressFor(0), 0);
      expect(item.progressFor(50), closeTo(0.25, 1e-9));
      expect(item.progressFor(200), 1);
      expect(item.progressFor(500), 1);
      expect(capsule(requiredPoints: 0).progressFor(0), 1);
    });

    test('kalan puan asla negatife düşmez', () {
      final RewardCapsule item = capsule(requiredPoints: 200);
      expect(item.remainingFor(0), 200);
      expect(item.remainingFor(120), 80);
      expect(item.remainingFor(200), 0);
      expect(item.remainingFor(900), 0);
    });

    test('open açılış bilgisini işaretler', () {
      final DateTime openedAt = DateTime(2026, 11, 17, 21, 30);
      final RewardCapsule opened = capsule().open(openedAt);
      expect(opened.isOpened, isTrue);
      expect(opened.openedAt, openedAt);
      expect(opened.title, 'Test Kapsülü');
      expect(capsule().isOpened, isFalse);
    });

    test('hazır kapsüller artan eşikli ve tekil', () {
      final List<RewardCapsule> starter = RewardCapsule.starter;
      expect(starter, hasLength(5));
      expect(
        starter.map((RewardCapsule c) => c.id).toSet(),
        hasLength(starter.length),
      );
      for (int i = 0; i < starter.length; i++) {
        expect(starter[i].requiredPoints, greaterThan(0));
        expect(starter[i].rewardMessage, isNotEmpty);
        expect(starter[i].isOpened, isFalse);
        if (i > 0) {
          expect(
            starter[i].requiredPoints,
            greaterThan(starter[i - 1].requiredPoints),
          );
        }
      }
    });

    test('JSON gidiş-dönüşü açılış bilgisini korur', () {
      final RewardCapsule original = RewardCapsule(
        id: 'capsule-custom',
        title: 'Sinema Gecesi',
        emoji: '🍿',
        description: 'Patlamış mısır bizden',
        requiredPoints: 120,
        rewardMessage: 'Biletler hazır!',
        isOpened: true,
        openedAt: DateTime(2026, 11, 17, 20),
        isCustom: true,
      );
      final RewardCapsule restored = RewardCapsule.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.emoji, original.emoji);
      expect(restored.description, original.description);
      expect(restored.requiredPoints, original.requiredPoints);
      expect(restored.rewardMessage, original.rewardMessage);
      expect(restored.isOpened, isTrue);
      expect(restored.openedAt, original.openedAt);
      expect(restored.isCustom, isTrue);
    });

    test('bozuk JSON varsayılan emoji ve eşikle okunur', () {
      final RewardCapsule restored = RewardCapsule.fromJson(
        <String, dynamic>{'id': 'x', 'title': 'Eksik'},
      );
      expect(restored.emoji, '🎁');
      expect(restored.requiredPoints, 250);
      expect(restored.isOpened, isFalse);
      expect(restored.isCustom, isFalse);
    });
  });

  group('CoupleState · kapsül yardımcıları', () {
    CoupleState withCapsules(List<RewardCapsule> capsules) =>
        zeroPointsState().copyWith(rewardCapsules: capsules);

    CoupleState withPoints(int scorePerPillar) {
      final CoupleState base = zeroPointsState();
      return base.copyWith(
        rubricScores: <String, int>{
          for (final String partnerId in CouplePartner.ids)
            for (final PillarDefinition pillar in DevelopmentRubric.pillars)
              CoupleState.rubricKey(partnerId, pillar.stat, day): scorePerPillar,
        },
      );
    }

    test('birleşik puan iki partnerin rubrik XP toplamıdır', () {
      expect(zeroPointsState().combinedPoints, 0);
      // 5 pillar × 2 puan (25 XP) × 2 partner = 250
      expect(withPoints(2).combinedPoints, 250);
      expect(withPoints(3).combinedPoints, 5 * 45 * 2);
      expect(
        withPoints(2).improvementPointsOf(CouplePartner.yusufId),
        125,
      );
      expect(
        withPoints(2).improvementPointsOf(CouplePartner.ceydaId),
        125,
      );
    });

    test('aralık dışı rubrik puanları XP hesabında kırpılır', () {
      final CoupleState broken = zeroPointsState().copyWith(
        rubricScores: <String, int>{
          CoupleState.rubricKey(
            CouplePartner.yusufId,
            StatKey.intelligence,
            day,
          ): 9,
          'bozuk|anahtar': 3,
        },
      );
      // 9 → maxScore (3) → 45 XP; bozuk anahtar sayılmaz.
      expect(broken.combinedPoints, 45);
    });

    test('capsulesByThreshold eşiğe göre sıralar', () {
      final CoupleState state = withCapsules(<RewardCapsule>[
        capsule(id: 'c-yuksek', requiredPoints: 500),
        capsule(id: 'c-dusuk', requiredPoints: 50),
        capsule(id: 'c-orta', requiredPoints: 250),
      ]);
      expect(
        state.capsulesByThreshold.map((RewardCapsule c) => c.id),
        <String>['c-dusuk', 'c-orta', 'c-yuksek'],
      );
      expect(state.capsuleById('c-orta')?.requiredPoints, 250);
      expect(state.capsuleById('yok'), isNull);
    });

    test('kilit açık kapsül sayısı ve sıradaki kapsül puandan türetilir', () {
      final CoupleState locked = withCapsules(<RewardCapsule>[
        capsule(id: 'c-100', requiredPoints: 100),
        capsule(id: 'c-300', requiredPoints: 300),
      ]);
      expect(locked.combinedPoints, 0);
      expect(locked.unlockedCapsuleCount, 0);
      expect(locked.nextUnlockedCapsule, isNull);

      final CoupleState unlocked = withCapsules(<RewardCapsule>[
        capsule(id: 'c-100', requiredPoints: 100),
        capsule(id: 'c-300', requiredPoints: 300),
      ]).copyWith(
        rubricScores: <String, int>{
          ...withPoints(2).rubricScores,
        },
      );
      expect(unlocked.combinedPoints, 250);
      expect(unlocked.unlockedCapsuleCount, 1);
      expect(unlocked.nextUnlockedCapsule?.id, 'c-100');

      final CoupleState opened = unlocked.openCapsule('c-100', now: day);
      expect(opened.capsuleById('c-100')?.isOpened, isTrue);
      expect(opened.nextUnlockedCapsule, isNull);
      expect(opened.unlockedCapsuleCount, 1);
    });

    test('kilitli veya açılmış kapsül açılamaz', () {
      final CoupleState locked = withCapsules(<RewardCapsule>[
        capsule(id: 'c-500', requiredPoints: 500),
      ]);
      expect(identical(locked.openCapsule('c-500'), locked), isTrue);
      expect(identical(locked.openCapsule('yok'), locked), isTrue);

      final CoupleState opened = locked
          .copyWith(
            rubricScores: <String, int>{...withPoints(3).rubricScores},
          )
          .openCapsule('c-500', now: day);
      expect(identical(opened.openCapsule('c-500'), opened), isTrue);
    });

    test('addCapsule listeye ekler', () {
      final CoupleState state = zeroPointsState().copyWith(
        rewardCapsules: <RewardCapsule>[],
      );
      final CoupleState next = state.addCapsule(capsule(id: 'yeni'));
      expect(next.rewardCapsules, hasLength(1));
      expect(next.rewardCapsules.single.id, 'yeni');
      expect(state.rewardCapsules, isEmpty);
    });

    test('CoupleState JSON gidiş-dönüşü plan ve kapsülleri korur', () {
      final CoupleState original = zeroPointsState()
          .copyWith(
            scheduleBlocks: <ScheduleBlock>[],
            rewardCapsules: <RewardCapsule>[],
          )
          .addScheduleBlocks(<ScheduleBlock>[
            ScheduleBlock.create(
              partnerId: CouplePartner.ceydaId,
              weekday: DateTime.tuesday,
              startMinutes: 14 * 60,
              endMinutes: 16 * 60,
              title: 'Judo',
              category: ScheduleCategory.workout,
              id: 'plan-judo',
            ),
          ])
          .addCapsule(capsule(id: 'capsule-json', requiredPoints: 75));
      final CoupleState restored = CoupleState.fromJson(original.toJson());

      expect(restored.scheduleBlocks, hasLength(1));
      expect(restored.scheduleBlocks.single.id, 'plan-judo');
      expect(restored.scheduleBlocks.single.category, ScheduleCategory.workout);
      expect(restored.rewardCapsules, hasLength(1));
      expect(restored.rewardCapsules.single.requiredPoints, 75);
      expect(restored.combinedPoints, original.combinedPoints);
    });
  });

}
