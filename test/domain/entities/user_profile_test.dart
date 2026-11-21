import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/archetype.dart';
import 'package:levelup_life/domain/entities/energy_mode.dart';
import 'package:levelup_life/domain/entities/rank_tier.dart';
import 'package:levelup_life/domain/entities/rpg_stats.dart';
import 'package:levelup_life/domain/entities/stat_key.dart';
import 'package:levelup_life/domain/entities/streak.dart';
import 'package:levelup_life/domain/entities/user_profile.dart';
import 'package:levelup_life/domain/services/xp_engine.dart';

UserProfile buildProfile() => UserProfile.starter(
  id: 'user-1',
  displayName: 'Yusuf Kaya',
  role: LifeRole.student,
  focusStats: <StatKey>{StatKey.intelligence, StatKey.willpower},
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  group('starter', () {
    test('yeni karakter Lv1, 0 XP ve onboarding bekliyor', () {
      final UserProfile profile = buildProfile();

      expect(profile.levelNumber, 1);
      expect(profile.totalXp, 0);
      expect(profile.level.fraction, 0);
      expect(profile.tier, RankTier.rookie);
      expect(profile.needsOnboarding, isTrue);
      expect(profile.isNewPlayer, isTrue);
      expect(profile.streak, Streak.empty);
      expect(profile.rpgStats, RpgStats.initial);
    });

    test('odak statlarına göre arketip önerilir', () {
      expect(buildProfile().archetype, Archetype.scholar);
      expect(buildProfile().titleLabel, 'Çaylak Bilgin');
      expect(buildProfile().firstName, 'Yusuf');
    });

    test('boş isim Gezgin olur', () {
      final UserProfile profile = UserProfile.starter(
        id: 'x',
        displayName: '   ',
      );

      expect(profile.displayName, 'Gezgin');
      expect(profile.firstName, 'Gezgin');
    });
  });

  group('seviye türetimi', () {
    test('seviye totalXp\'den hesaplanır (saklanmaz)', () {
      final UserProfile profile = buildProfile().copyWith(totalXp: 100);

      expect(profile.levelNumber, 2);
      expect(profile.level, XpEngine.progressForTotalXp(100));
      expect(profile.level.xpIntoLevel, 0);
    });

    test('momentum 0-1 arasında ve seriyle artar', () {
      final UserProfile withXp = buildProfile().copyWith(totalXp: 400);
      final UserProfile withStreak = withXp.copyWith(
        streak: const Streak(currentDays: 30, longestDays: 30),
      );

      expect(withXp.momentum, inInclusiveRange(0, 1));
      expect(withStreak.momentum, greaterThan(withXp.momentum));
    });
  });

  group('completeQuest (oyun döngüsü)', () {
    test('XP, stat ve seriyi tek hamlede günceller', () {
      final DateTime at = DateTime(2026, 11, 15, 10);
      final XpAward award = buildProfile().completeQuest(
        stat: StatKey.intelligence,
        xp: 60,
        at: at,
      );

      expect(award.xpGained, 60);
      expect(award.profile.totalXp, 60);
      expect(award.profile.rpgStats[StatKey.intelligence].xp, 60);
      expect(award.profile.rpgStats[StatKey.intelligence].questsCompleted, 1);
      expect(award.profile.streak.currentDays, 1);
      expect(award.profile.lastActiveAt, at);
      expect(award.leveledUp, isFalse);
      expect(award.profile, isNot(buildProfile()));
    });

    test('eşik aşılınca seviye atlar', () {
      final XpAward award = buildProfile().completeQuest(
        stat: StatKey.willpower,
        xp: 100,
        at: DateTime(2026, 11, 15),
      );

      expect(award.before.level, 1);
      expect(award.after.level, 2);
      expect(award.leveledUp, isTrue);
      expect(award.levelsGained, 1);
      expect(award.tierChanged, isFalse);
    });

    test('kuşak değişimi tierChanged ile bildirilir', () {
      final UserProfile almostJourneyman = buildProfile().copyWith(
        totalXp: XpEngine.totalXpForLevel(15) - 1,
      );
      final XpAward award = almostJourneyman.completeQuest(
        stat: StatKey.intelligence,
        xp: 5,
        at: DateTime(2026, 11, 15),
      );

      expect(award.before.tier, RankTier.rookie);
      expect(award.after.tier, RankTier.journeyman);
      expect(award.tierChanged, isTrue);
    });

    test('aynı gün ikinci görev seriyi artırmaz', () {
      final DateTime at = DateTime(2026, 11, 15, 10);
      final UserProfile profile = buildProfile()
          .completeQuest(stat: StatKey.strength, xp: 30, at: at)
          .profile
          .completeQuest(
            stat: StatKey.strength,
            xp: 30,
            at: at.add(const Duration(hours: 3)),
          )
          .profile;

      expect(profile.totalXp, 60);
      expect(profile.streak.currentDays, 1);
      expect(profile.rpgStats[StatKey.strength].questsCompleted, 2);
    });

    test('kazanılan XP günlük XP kaydına yazılır', () {
      final DateTime at = DateTime(2026, 11, 15, 8);
      final XpAward award = buildProfile().completeQuest(
        stat: StatKey.willpower,
        xp: 25,
        at: at,
      );

      expect(award.profile.xpLog.xpOn(at), 25);
      expect(award.profile.xpLog.activeDays, 1);
      expect(award.profile.xpLog.xpOn(DateTime(2026, 11, 14)), 0);
    });
  });

  group('mod ve onboarding güncellemeleri', () {
    test('withEnergyMode sadece modu değiştirir', () {
      final UserProfile profile = buildProfile();

      expect(
        profile.withEnergyMode(EnergyMode.lowEnergy).energyMode,
        EnergyMode.lowEnergy,
      );
      expect(profile.energyMode, EnergyMode.balanced);
    });

    test('withFocusStats arketipi yeniden önerir', () {
      final UserProfile profile = buildProfile().withFocusStats(<StatKey>{
        StatKey.strength,
      });

      expect(profile.archetype, Archetype.athlete);
      expect(profile.focusStats, <StatKey>{StatKey.strength});
    });

    test('completeOnboarding bayrağı ve hedefi ayarlar', () {
      final UserProfile profile = buildProfile().completeOnboarding(
        role: LifeRole.employee,
        focusStats: <StatKey>{StatKey.productivity},
        dailyQuestTarget: 4,
      );

      expect(profile.onboardingCompleted, isTrue);
      expect(profile.needsOnboarding, isFalse);
      expect(profile.role, LifeRole.employee);
      expect(profile.archetype, Archetype.hustler);
      expect(profile.dailyQuestTarget, 4);
      expect(profile.createdAt, DateTime(2026, 11, 1));
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final UserProfile profile = buildProfile()
          .completeQuest(
            stat: StatKey.intelligence,
            xp: 240,
            at: DateTime(2026, 11, 15, 9),
          )
          .profile
          .withEnergyMode(EnergyMode.examWeek)
          .copyWith(avatarSeed: 42, remindersEnabled: false);

      expect(UserProfile.fromJson(profile.toJson()), profile);
    });

    test('günlük XP geçmişi JSON ile korunur', () {
      final UserProfile profile = buildProfile()
          .completeQuest(
            stat: StatKey.intelligence,
            xp: 40,
            at: DateTime(2026, 11, 14, 9),
          )
          .profile
          .completeQuest(
            stat: StatKey.intelligence,
            xp: 60,
            at: DateTime(2026, 11, 15, 9),
          )
          .profile;

      expect(profile.toJson()['xp_log'], isA<Map<String, dynamic>>());

      final UserProfile restored = UserProfile.fromJson(profile.toJson());

      expect(restored.xpLog, profile.xpLog);
      expect(restored.xpLog.xpOn(DateTime(2026, 11, 14)), 40);
      expect(restored.xpLog.xpOn(DateTime(2026, 11, 15)), 60);
      expect(restored.xpLog.activeDays, 2);
    });

    test('boş JSON güvenli varsayılanlar üretir', () {
      final UserProfile profile = UserProfile.fromJson(
        const <String, dynamic>{},
      );

      expect(profile.displayName, 'Gezgin');
      expect(profile.role, LifeRole.student);
      expect(profile.archetype, Archetype.polymath);
      expect(profile.levelNumber, 1);
      expect(profile.dailyQuestTarget, UserProfile.defaultDailyQuestTarget);
      expect(profile.onboardingCompleted, isFalse);
      expect(profile.rpgStats.ordered.length, StatKey.values.length);
    });

    test('günlük hedef aralığa kırpılır', () {
      expect(
        UserProfile.fromJson(<String, dynamic>{
          'daily_quest_target': 99,
        }).dailyQuestTarget,
        UserProfile.maxDailyQuestTarget,
      );
      expect(
        UserProfile.fromJson(<String, dynamic>{
          'daily_quest_target': 0,
        }).dailyQuestTarget,
        UserProfile.minDailyQuestTarget,
      );
    });
  });
}
