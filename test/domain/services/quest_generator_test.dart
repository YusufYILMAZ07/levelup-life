import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/domain/services/services.dart';

void main() {
  const UserSetup softwareStudent = UserSetup(
    displayName: 'Yusuf',
    role: LifeRole.student,
    studyField: 'Bilgisayar Mühendisliği',
    gradeYear: 3,
    goals: <GoalType>{GoalType.fitness, GoalType.career},
    tempo: DailyTempo.balanced,
  );

  final DateTime now = DateTime(2026, 11, 15, 9);

  group('dailyQuests', () {
    test('günlük hedef kadar görev üretir ve id\'ler benzersizdir', () {
      final List<Quest> quests =
          QuestGenerator.dailyQuests(setup: softwareStudent, now: now);

      expect(quests, hasLength(softwareStudent.dailyQuestTarget));
      expect(
        quests.map((Quest quest) => quest.id).toSet(),
        hasLength(quests.length),
      );
      expect(quests.every((Quest quest) => quest.baseXp > 0), isTrue);
    });

    test('yalnızca seçilen hedeflere ve evrensel şablonlara ait görevler', () {
      final List<Quest> quests =
          QuestGenerator.dailyQuests(setup: softwareStudent, now: now);
      final Set<String> allowed = <String>{'fitness', 'career', 'core'};

      for (final Quest quest in quests) {
        expect(quest.tags, isNotEmpty);
        expect(allowed, contains(quest.tags.first));
      }
    });

    test('seçilmeyen hedefler görev havuzuna girmez', () {
      const UserSetup academicOnly = UserSetup(
        displayName: 'Ada',
        role: LifeRole.highSchool,
        studyField: 'Sayısal',
        gradeYear: 2,
        goals: <GoalType>{GoalType.academic},
        tempo: DailyTempo.hardcore,
      );
      final List<Quest> quests = QuestGenerator.dailyQuests(
        setup: academicOnly,
        now: now,
        count: 20,
      );
      final Set<String> allowed = <String>{'academic', 'core'};

      expect(quests.length, greaterThan(0));
      for (final Quest quest in quests) {
        expect(allowed, contains(quest.tags.first));
      }
    });

    test('her seçilen hedef en az bir görevle temsil edilir', () {
      final List<Quest> quests = QuestGenerator.dailyQuests(
        setup: softwareStudent,
        now: now,
        count: 2,
      );
      final Set<String> goals =
          quests.map((Quest quest) => quest.tags.first).toSet();
      expect(goals, containsAll(<String>['fitness', 'career']));
    });

    test('görev başlıkları kişiselleştirilir, yer tutucu kalmaz', () {
      const UserSetup academic = UserSetup(
        displayName: 'Ada',
        role: LifeRole.student,
        studyField: 'Tıp',
        gradeYear: 4,
        goals: <GoalType>{GoalType.academic, GoalType.career},
        tempo: DailyTempo.hardcore,
      );
      final List<Quest> quests = QuestGenerator.dailyQuests(
        setup: academic,
        now: now,
        count: 20,
      );

      expect(quests.any((Quest quest) => quest.title.contains('Tıp')), isTrue);
      for (final Quest quest in quests) {
        expect(quest.title.contains('{'), isFalse);
        expect(quest.summary.contains('{'), isFalse);
      }
    });

    test('aynı gün için deterministik, farklı gün için döner', () {
      final List<Quest> first =
          QuestGenerator.dailyQuests(setup: softwareStudent, now: now);
      final List<Quest> second = QuestGenerator.dailyQuests(
        setup: softwareStudent,
        now: now.add(const Duration(hours: 3)),
      );
      final List<Quest> nextDay = QuestGenerator.dailyQuests(
        setup: softwareStudent,
        now: now.add(const Duration(days: 1)),
      );

      expect(
        first.map((Quest quest) => quest.id),
        second.map((Quest quest) => quest.id),
      );
      expect(
        first.map((Quest quest) => quest.title).toList(),
        isNot(nextDay.map((Quest quest) => quest.title).toList()),
      );
    });

    test('enerji modu mikro varyantları devreye alır', () {
      final List<Quest> quests = QuestGenerator.dailyQuests(
        setup: softwareStudent.copyWith(tempo: DailyTempo.hardcore),
        now: now,
        energyMode: EnergyMode.lowEnergy,
      );

      expect(
        quests.every((Quest quest) => quest.energyMode == EnergyMode.lowEnergy),
        isTrue,
      );
      final Iterable<Quest> withMicro =
          quests.where((Quest quest) => quest.microVariant != null);
      expect(withMicro, isNotEmpty);
      expect(withMicro.every((Quest quest) => quest.isMicro), isTrue);
      expect(withMicro.first.effectiveMinutes, 10);
    });

    test('hedefsiz kullanıcı evrensel görevler alır', () {
      const UserSetup emptyGoals = UserSetup(
        displayName: 'Gezgin',
        tempo: DailyTempo.relaxed,
      );
      final List<Quest> quests =
          QuestGenerator.dailyQuests(setup: emptyGoals, now: now);

      expect(quests, hasLength(2));
      expect(quests.every((Quest quest) => quest.tags.first == 'core'), isTrue);
    });
  });

  group('custom / estimateXp', () {
    test('özel görev doğru alanlarla kurulur', () {
      final Quest quest = QuestGenerator.custom(
        title: '  20 dk İngilizce pratiği  ',
        stat: StatKey.intelligence,
        minutes: 30,
        difficulty: QuestDifficulty.moderate,
        now: now,
      );

      expect(quest.title, '20 dk İngilizce pratiği');
      expect(quest.stat, StatKey.intelligence);
      expect(
        quest.baseXp,
        QuestGenerator.estimateXp(30, QuestDifficulty.moderate),
      );
      expect(quest.cadence, QuestCadence.oneOff);
      expect(quest.verification.type, VerificationType.manual);
      expect(quest.tags, contains('custom'));
      expect(quest.microVariant, isNotNull);
      expect(quest.id.startsWith('custom-'), isTrue);
    });

    test('estimateXp 5\'in katı ve 10-300 aralığında kalır', () {
      for (final int minutes in <int>[1, 10, 30, 90, 240]) {
        for (final QuestDifficulty difficulty in QuestDifficulty.values) {
          final int xp = QuestGenerator.estimateXp(minutes, difficulty);
          expect(xp % 5, 0);
          expect(xp, inInclusiveRange(10, 300));
        }
      }
    });
  });
}
