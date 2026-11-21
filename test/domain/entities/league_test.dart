import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/archetype.dart';
import 'package:levelup_life/domain/entities/league.dart';

LeagueEntry entry(
  String id,
  int xp, {
  bool isMe = false,
  Archetype archetype = Archetype.scholar,
}) => LeagueEntry(
  userId: id,
  displayName: 'Oyuncu $id',
  weeklyXp: xp,
  level: 10,
  archetype: archetype,
  isCurrentUser: isMe,
);

void main() {
  final DateTime weekStart = DateTime(2026, 11, 9);

  League buildLeague() => League(
    id: 'league-1',
    tier: LeagueTier.silver,
    weekStart: weekStart,
    entries: <LeagueEntry>[
      entry('u1', 400),
      entry('u2', 900),
      entry('u3', 650, isMe: true),
      entry('u4', 100),
      entry('u5', 650),
    ],
  );

  group('ranking', () {
    test('XP azalan sıralanır, eşitlikte userId alfabetik', () {
      final List<String> order = buildLeague().ranking
          .map((LeagueEntry e) => e.userId)
          .toList();

      expect(order, <String>['u2', 'u3', 'u5', 'u1', 'u4']);
    });

    test('leader ve currentUser doğru bulunur', () {
      final League league = buildLeague();

      expect(league.leader?.userId, 'u2');
      expect(league.currentUser?.userId, 'u3');
      expect(league.currentUserRank, 2);
    });

    test('kullanıcı ligde değilse sıra 0 ve promosyon yok', () {
      final League league = League(
        id: 'league-2',
        tier: LeagueTier.bronze,
        weekStart: weekStart,
        entries: <LeagueEntry>[entry('a', 10), entry('b', 20)],
      );

      expect(league.currentUser, isNull);
      expect(league.currentUserRank, 0);
      expect(league.isCurrentUserPromoted, isFalse);
      expect(league.isCurrentUserRelegated, isFalse);
    });

    test('ilk 3 promosyon, son 2 küme düşme bölgesi', () {
      final League league = buildLeague();

      expect(league.promotionZone.length, 3);
      expect(league.relegationZone.length, 2);
      expect(league.isCurrentUserPromoted, isTrue);
      expect(league.isCurrentUserRelegated, isFalse);
    });

    test('ortalama haftalık XP hesaplanır', () {
      expect(buildLeague().averageWeeklyXp, 540);
    });
  });

  group('applyXp', () {
    test('sadece hedef kullanıcıyı günceller ve sıralamayı yeniden kurar', () {
      final League league = buildLeague().applyXp('u4', 700);
      final List<String> order = league.ranking
          .map((LeagueEntry e) => e.userId)
          .toList();

      expect(order.first, 'u2');
      expect(order, contains('u4'));
      expect(
        league.entries.firstWhere((LeagueEntry e) => e.userId == 'u4').weeklyXp,
        800,
      );
      expect(
        league.entries.firstWhere((LeagueEntry e) => e.userId == 'u1').weeklyXp,
        400,
      );
    });

    test('negatif veya sıfır XP yok sayılır', () {
      final League league = buildLeague();

      expect(league.applyXp('u1', 0), league);
      expect(league.applyXp('u1', -50), league);
    });

    test('bilinmeyen kullanıcı için değişiklik olmaz', () {
      final League league = buildLeague();

      expect(league.applyXp('yok', 500).ranking, league.ranking);
    });
  });

  group('LeagueTier', () {
    test('haftalık XP eşikleri doğru ligi verir', () {
      expect(LeagueTier.forWeeklyXp(0), LeagueTier.bronze);
      expect(LeagueTier.forWeeklyXp(299), LeagueTier.bronze);
      expect(LeagueTier.forWeeklyXp(300), LeagueTier.silver);
      expect(LeagueTier.forWeeklyXp(700), LeagueTier.gold);
      expect(LeagueTier.forWeeklyXp(1200), LeagueTier.platinum);
      expect(LeagueTier.forWeeklyXp(9999), LeagueTier.diamond);
      expect(LeagueTier.diamond.next, isNull);
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final League league = buildLeague();

      expect(League.fromJson(league.toJson()), league);
    });

    test('bozuk JSON boş lig üretir', () {
      final League league = League.fromJson(<String, dynamic>{'tier': 'yok'});

      expect(league.tier, LeagueTier.bronze);
      expect(league.entries, isEmpty);
      expect(league.leader, isNull);
      expect(league.promotionSlots, 3);
      expect(league.relegationSlots, 2);
    });
  });
}
