import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';

void main() {
  const UserSetup universityStudent = UserSetup(
    displayName: 'Yusuf',
    role: LifeRole.student,
    studyField: 'Bilgisayar Mühendisliği',
    gradeYear: 3,
    goals: <GoalType>{GoalType.fitness, GoalType.career},
    tempo: DailyTempo.balanced,
  );

  group('türetilmiş değerler', () {
    test('trackLabel bölüm ve sınıfı birleştirir', () {
      expect(
        universityStudent.trackLabel,
        'Bilgisayar Mühendisliği · 3. Sınıf',
      );
    });

    test('çalışan için trackLabel sektörden gelir', () {
      const UserSetup employee = UserSetup(
        role: LifeRole.employee,
        sector: 'Yazılım & Teknoloji',
        workload: Workload.intense,
      );
      expect(employee.isProfessional, isTrue);
      expect(employee.trackLabel, 'Yazılım & Teknoloji');
    });

    test('focusStats hedeflerin birincil + ikincil statlarını toplar', () {
      expect(
        universityStudent.focusStats,
        containsAll(<StatKey>[
          StatKey.strength,
          StatKey.vitality,
          StatKey.productivity,
          StatKey.intelligence,
        ]),
      );
    });

    test('tek hedefli akademik kurulum Bilgin sınıfına gider', () {
      const UserSetup academic = UserSetup(
        displayName: 'Ada',
        role: LifeRole.highSchool,
        studyField: 'Sayısal',
        gradeYear: 2,
        goals: <GoalType>{GoalType.academic},
      );
      expect(academic.archetype, Archetype.scholar);
    });

    test('geniş hedef kümesi Çok Yönlü sınıfına gider', () {
      expect(universityStudent.archetype, Archetype.polymath);
    });

    test('günlük görev hedefi tempodan gelir', () {
      expect(universityStudent.dailyQuestTarget, 4);
      expect(
        universityStudent.copyWith(tempo: DailyTempo.relaxed).dailyQuestTarget,
        2,
      );
      expect(
        universityStudent.copyWith(tempo: DailyTempo.hardcore).dailyQuestTarget,
        6,
      );
    });

    test('yoğun çalışanın görev hedefi yukarı ölçeklenir', () {
      const UserSetup employee = UserSetup(
        role: LifeRole.employee,
        sector: 'Finans',
        workload: Workload.intense,
        tempo: DailyTempo.balanced,
      );
      expect(employee.dailyQuestTarget, 5);
    });

    test('doğrulama alanları role göre çalışır', () {
      expect(UserSetup.empty.isComplete, isFalse);
      expect(universityStudent.isComplete, isTrue);
      expect(
        universityStudent.copyWith(goals: const <GoalType>{}).isComplete,
        isFalse,
      );
      expect(universityStudent.copyWith(studyField: '').hasDetails, isFalse);
    });

    test('startingRadar birincil hedefi daha yüksek gösterir', () {
      final Map<StatKey, double> radar = universityStudent.startingRadar;
      expect(radar[StatKey.strength]!, greaterThan(radar[StatKey.vitality]!));
      expect(
        radar[StatKey.productivity]!,
        greaterThan(radar[StatKey.vitality]!),
      );
      expect(radar[StatKey.intelligence]!, greaterThan(0));
    });

    test('toggleGoal seçimi ekler ve kaldırır, orijinali bozmaz', () {
      final UserSetup added = universityStudent.toggleGoal(GoalType.reading);
      expect(added.goals, contains(GoalType.reading));
      expect(universityStudent.goals, isNot(contains(GoalType.reading)));

      final UserSetup removed = universityStudent.toggleGoal(GoalType.fitness);
      expect(removed.goals, isNot(contains(GoalType.fitness)));
    });
  });

  group('profil üretimi', () {
    test('toProfile onboarding cevaplarını profile taşır', () {
      final DateTime now = DateTime(2026, 11, 15, 10);
      final UserProfile profile = universityStudent.toProfile(now: now);

      expect(profile.displayName, 'Yusuf');
      expect(profile.role, LifeRole.student);
      expect(profile.onboardingCompleted, isTrue);
      expect(profile.dailyQuestTarget, 4);
      expect(profile.archetype, universityStudent.archetype);
      expect(profile.focusStats, containsAll(universityStudent.focusStats));
      expect(profile.totalXp, 0);
      expect(profile.levelNumber, 1);
      expect(profile.createdAt, now);
    });

    test('avatar tohumu isme göre deterministiktir', () {
      final UserProfile a = universityStudent.toProfile();
      final UserProfile b = universityStudent.toProfile();
      expect(a.avatarSeed, b.avatarSeed);
      expect(
        universityStudent.copyWith(displayName: 'Ada').toProfile().avatarSeed,
        isNot(a.avatarSeed),
      );
    });

    test('boş isim Gezgin olarak kaydedilir', () {
      final UserProfile profile = universityStudent
          .copyWith(displayName: '   ')
          .toProfile();
      expect(profile.displayName, 'Gezgin');
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final UserSetup restored = UserSetup.fromJson(universityStudent.toJson());
      expect(restored, universityStudent);
    });

    test('boş JSON güvenli varsayılanlar üretir', () {
      final UserSetup setup = UserSetup.fromJson(const <String, dynamic>{});
      expect(setup.displayName, '');
      expect(setup.role, LifeRole.student);
      expect(setup.goals, isEmpty);
      expect(setup.tempo, DailyTempo.balanced);
      expect(setup.gradeYear, 0);
    });

    test('bilinmeyen hedef kodu sessizce atlanır', () {
      final UserSetup setup = UserSetup.fromJson(<String, dynamic>{
        'goals': <String>['fitness', 'bilinmeyen-hedef'],
      });
      expect(setup.goals, <GoalType>{GoalType.fitness});
    });
  });
}
