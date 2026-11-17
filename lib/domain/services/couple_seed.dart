import '../../core/utils/date_x.dart';
import '../entities/entities.dart';
import 'quest_generator.dart';

/// İki kişilik sürümün başlangıç verisi (Yusuf & Ceyda).
///
/// Depoda kayıt yoksa uygulama bu tohumla açılır: iki partnerin tanışma
/// cevapları, birkaç günlük gerçekçi ilerleme geçmişi, bugünün görevleri ve
/// ortak sohbet/bucket list içeriği. Tüm zaman damgaları "şimdi"ye göre
/// üretilir → uygulama her açılışta taze görünür, eski cache'e bağlı kalmaz.
abstract final class CoupleSeeder {
  static const UserSetup yusufSetup = UserSetup(
    displayName: 'Yusuf',
    role: LifeRole.student,
    studyField: 'Bilgisayar Mühendisliği',
    gradeYear: 3,
    goals: <GoalType>{GoalType.career, GoalType.academic, GoalType.discipline},
    tempo: DailyTempo.balanced,
  );

  static const UserSetup ceydaSetup = UserSetup(
    displayName: 'Ceyda',
    role: LifeRole.student,
    studyField: 'Psikoloji',
    gradeYear: 2,
    goals: <GoalType>{GoalType.academic, GoalType.reading, GoalType.nutrition},
    tempo: DailyTempo.balanced,
  );

  /// Geçmiş günlerin XP eğrisi (dünden geriye doğru değil, eskiden yeniye).
  static const List<int> yusufDailyXp = <int>[80, 120, 95, 140, 110, 130];
  static const List<int> ceydaDailyXp = <int>[70, 90, 110, 85, 120, 105];

  static const List<StatKey> _yusufRotation = <StatKey>[
    StatKey.intelligence,
    StatKey.productivity,
    StatKey.vitality,
    StatKey.strength,
    StatKey.intelligence,
    StatKey.productivity,
  ];

  static const List<StatKey> _ceydaRotation = <StatKey>[
    StatKey.intelligence,
    StatKey.vitality,
    StatKey.willpower,
    StatKey.vitality,
    StatKey.productivity,
    StatKey.intelligence,
  ];

  static PartnerData yusuf({DateTime? now}) => _partner(
    setup: yusufSetup,
    id: CouplePartner.yusufId,
    archetype: Archetype.scholar,
    now: now ?? DateTime.now(),
    dailyXp: yusufDailyXp,
    rotation: _yusufRotation,
    energyMode: EnergyMode.balanced,
  );

  static PartnerData ceyda({DateTime? now}) => _partner(
    setup: ceydaSetup,
    id: CouplePartner.ceydaId,
    archetype: Archetype.polymath,
    now: now ?? DateTime.now(),
    dailyXp: ceydaDailyXp,
    rotation: _ceydaRotation,
    energyMode: EnergyMode.balanced,
  );

  /// Partner haritası (aktif partner: Yusuf).
  static Map<String, PartnerData> partners({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return <String, PartnerData>{
      CouplePartner.yusufId: yusuf(now: at),
      CouplePartner.ceydaId: ceyda(now: at),
    };
  }

  /// Sohbet + bucket list + rubrik geçmişi ile ortak durum.
  static CoupleState couple({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    final DateTime today = DateX.today(at);
    final DateTime yesterday = DateX.shiftDays(today, -1);
    final DateTime twoDaysAgo = DateX.shiftDays(today, -2);

    CoupleState state = CoupleState.demo(now: at);
    state =
        _rate(state, CouplePartner.yusufId, twoDaysAgo, const <StatKey, int>{
          StatKey.intelligence: 2,
          StatKey.productivity: 1,
          StatKey.strength: 1,
          StatKey.vitality: 2,
          StatKey.willpower: 1,
        });
    state = _rate(state, CouplePartner.yusufId, yesterday, const <StatKey, int>{
      StatKey.intelligence: 3,
      StatKey.productivity: 2,
      StatKey.strength: 2,
      StatKey.vitality: 2,
      StatKey.willpower: 1,
    });
    state = _rate(state, CouplePartner.yusufId, today, const <StatKey, int>{
      StatKey.intelligence: 2,
    });
    state =
        _rate(state, CouplePartner.ceydaId, twoDaysAgo, const <StatKey, int>{
          StatKey.intelligence: 2,
          StatKey.productivity: 2,
          StatKey.strength: 1,
          StatKey.vitality: 2,
          StatKey.willpower: 2,
        });
    state = _rate(state, CouplePartner.ceydaId, yesterday, const <StatKey, int>{
      StatKey.intelligence: 2,
      StatKey.productivity: 3,
      StatKey.strength: 1,
      StatKey.vitality: 3,
      StatKey.willpower: 2,
    });
    state = state
        .markSynergy(pillar: StatKey.intelligence, day: yesterday)
        .markSynergy(pillar: StatKey.vitality, day: yesterday)
        .recordQuestCompletion(
          partnerId: CouplePartner.yusufId,
          day: yesterday,
          count: 3,
        )
        .recordQuestCompletion(
          partnerId: CouplePartner.ceydaId,
          day: yesterday,
          count: 4,
        )
        .recordQuestCompletion(partnerId: CouplePartner.yusufId, day: today)
        .addBonusAction(
          BonusActionLog.fromQuickAction(
            action: QuickAction.pomodoro,
            partnerId: CouplePartner.yusufId,
            at: yesterday.add(const Duration(hours: 19)),
          ),
        )
        .addBonusAction(
          BonusActionLog.fromQuickAction(
            action: QuickAction.water,
            partnerId: CouplePartner.ceydaId,
            at: yesterday.add(const Duration(hours: 18)),
          ),
        );
    return state;
  }

  static CoupleState _rate(
    CoupleState state,
    String partnerId,
    DateTime day,
    Map<StatKey, int> scores,
  ) {
    CoupleState next = state;
    for (final MapEntry<StatKey, int> entry in scores.entries) {
      next = next.ratePillar(
        partnerId: partnerId,
        pillar: entry.key,
        score: entry.value,
        day: day,
      );
    }
    return next;
  }

  static PartnerData _partner({
    required UserSetup setup,
    required String id,
    required Archetype archetype,
    required DateTime now,
    required List<int> dailyXp,
    required List<StatKey> rotation,
    required EnergyMode energyMode,
  }) {
    final DateTime today = DateX.today(now);
    UserProfile profile = setup
        .toProfile(now: DateX.shiftDays(today, -30), id: id)
        .copyWith(archetype: archetype, energyMode: energyMode);

    for (int i = 0; i < dailyXp.length; i++) {
      final int daysAgo = dailyXp.length - 1 - i;
      final DateTime day = DateX.shiftDays(today, -daysAgo);
      final DateTime stamp = daysAgo == 0
          ? now
          : day.add(const Duration(hours: 20));
      profile = profile
          .completeQuest(
            stat: rotation[i % rotation.length],
            xp: dailyXp[i],
            at: stamp,
          )
          .profile;
    }

    final List<Quest> quests = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );

    return PartnerData(setup: setup, profile: profile, quests: quests);
  }
}
