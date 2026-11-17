import '../../core/utils/json_x.dart';
import 'archetype.dart';

/// Haftalık lig kademeleri — 10 kişilik gruplarda ilk 3 bir üst lige çıkar.
enum LeagueTier {
  bronze(code: 'bronze', label: 'Bronz', minWeeklyXp: 0),
  silver(code: 'silver', label: 'Gümüş', minWeeklyXp: 300),
  gold(code: 'gold', label: 'Altın', minWeeklyXp: 700),
  platinum(code: 'platinum', label: 'Platin', minWeeklyXp: 1200),
  diamond(code: 'diamond', label: 'Elmas', minWeeklyXp: 1800);

  const LeagueTier({
    required this.code,
    required this.label,
    required this.minWeeklyXp,
  });

  final String code;
  final String label;

  /// Bu lige girmek için gereken minimum haftalık XP.
  final int minWeeklyXp;

  LeagueTier? get next => index + 1 < values.length ? values[index + 1] : null;

  /// Haftalık XP'ye göre hak edilen lig.
  static LeagueTier forWeeklyXp(int xp) {
    LeagueTier result = LeagueTier.bronze;
    for (final LeagueTier tier in values) {
      if (xp >= tier.minWeeklyXp) result = tier;
    }
    return result;
  }

  static LeagueTier fromCode(String? code) {
    for (final LeagueTier tier in values) {
      if (tier.code == code || tier.name == code) return tier;
    }
    return LeagueTier.bronze;
  }
}

/// Lig tablosundaki tek satır (kullanıcı veya rakip).
final class LeagueEntry {
  const LeagueEntry({
    required this.userId,
    required this.displayName,
    required this.weeklyXp,
    required this.level,
    required this.archetype,
    this.streakDays = 0,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final int weeklyXp;

  /// Lig tablosu son bilinen seviyeyi gösterir (XP arttıkça kayabilir).
  final int level;

  final Archetype archetype;
  final int streakDays;
  final bool isCurrentUser;

  LeagueEntry addXp(int amount) =>
      amount <= 0 ? this : copyWith(weeklyXp: weeklyXp + amount);

  LeagueEntry copyWith({
    String? displayName,
    int? weeklyXp,
    int? level,
    Archetype? archetype,
    int? streakDays,
    bool? isCurrentUser,
  }) =>
      LeagueEntry(
        userId: userId,
        displayName: displayName ?? this.displayName,
        weeklyXp: weeklyXp ?? this.weeklyXp,
        level: level ?? this.level,
        archetype: archetype ?? this.archetype,
        streakDays: streakDays ?? this.streakDays,
        isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'display_name': displayName,
        'weekly_xp': weeklyXp,
        'level': level,
        'archetype': archetype.code,
        'streak_days': streakDays,
        'is_current_user': isCurrentUser,
      };

  factory LeagueEntry.fromJson(Map<String, dynamic> json) => LeagueEntry(
        userId: JsonX.asString(json['user_id']),
        displayName: JsonX.asString(json['display_name'], fallback: 'Gezgin'),
        weeklyXp: JsonX.asInt(json['weekly_xp']),
        level: JsonX.asInt(json['level'], fallback: 1),
        archetype: Archetype.fromCode(JsonX.asString(json['archetype'])),
        streakDays: JsonX.asInt(json['streak_days']),
        isCurrentUser: JsonX.asBool(json['is_current_user']),
      );

  @override
  bool operator ==(Object other) =>
      other is LeagueEntry &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.weeklyXp == weeklyXp &&
      other.level == level &&
      other.archetype == archetype &&
      other.streakDays == streakDays &&
      other.isCurrentUser == isCurrentUser;

  @override
  int get hashCode => Object.hash(
      userId, displayName, weeklyXp, level, archetype, streakDays, isCurrentUser);

  @override
  String toString() => 'LeagueEntry($displayName · $weeklyXp XP · Lv$level)';
}

/// 10 kişilik haftalık lig grubu.
///
/// Sıralama her zaman [weeklyXp]'ye göre azalan; eşitlikte `userId` alfabetik
/// (deterministik — testlerde ve animasyonlarda titreme olmaz).
final class League {
  const League({
    required this.id,
    required this.tier,
    required this.weekStart,
    required this.entries,
    this.promotionSlots = 3,
    this.relegationSlots = 2,
  });

  final String id;
  final LeagueTier tier;

  /// Haftanın ilk günü (Pazartesi 00:00).
  final DateTime weekStart;
  final List<LeagueEntry> entries;

  /// Üst lige çıkan kişi sayısı.
  final int promotionSlots;

  /// Alt lige düşen kişi sayısı.
  final int relegationSlots;

  List<LeagueEntry> get ranking {
    final List<LeagueEntry> sorted = List<LeagueEntry>.of(entries);
    sorted.sort((LeagueEntry a, LeagueEntry b) {
      final int byXp = b.weeklyXp.compareTo(a.weeklyXp);
      return byXp != 0 ? byXp : a.userId.compareTo(b.userId);
    });
    return List<LeagueEntry>.unmodifiable(sorted);
  }

  LeagueEntry? get leader => ranking.isEmpty ? null : ranking.first;

  LeagueEntry? get currentUser {
    for (final LeagueEntry entry in entries) {
      if (entry.isCurrentUser) return entry;
    }
    return null;
  }

  /// 1 tabanlı sıra; kullanıcı ligde değilse 0.
  int get currentUserRank {
    final LeagueEntry? me = currentUser;
    if (me == null) return 0;
    return ranking.indexWhere((LeagueEntry e) => e.userId == me.userId) + 1;
  }

  bool get isCurrentUserPromoted =>
      currentUserRank > 0 && currentUserRank <= promotionSlots;

  bool get isCurrentUserRelegated =>
      currentUserRank > 0 && currentUserRank > entries.length - relegationSlots;

  List<LeagueEntry> get promotionZone =>
      ranking.take(promotionSlots).toList(growable: false);

  List<LeagueEntry> get relegationZone => ranking.length <= relegationSlots
      ? const <LeagueEntry>[]
      : ranking.sublist(ranking.length - relegationSlots);

  int get averageWeeklyXp => entries.isEmpty
      ? 0
      : (entries.fold<int>(0, (int sum, LeagueEntry e) => sum + e.weeklyXp) /
              entries.length)
          .round();

  /// Ligi yeniden kurmadan XP ekler (haftalık güncelleme için).
  League applyXp(String userId, int amount) {
    if (amount <= 0) return this;
    return League(
      id: id,
      tier: tier,
      weekStart: weekStart,
      entries: <LeagueEntry>[
        for (final LeagueEntry entry in entries)
          entry.userId == userId ? entry.addXp(amount) : entry,
      ],
      promotionSlots: promotionSlots,
      relegationSlots: relegationSlots,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tier': tier.code,
        'week_start': weekStart.toIso8601String(),
        'entries': <Map<String, dynamic>>[
          for (final LeagueEntry entry in entries) entry.toJson(),
        ],
        'promotion_slots': promotionSlots,
        'relegation_slots': relegationSlots,
      };

  factory League.fromJson(Map<String, dynamic> json) {
    final Object? rawEntries = json['entries'];
    return League(
      id: JsonX.asString(json['id']),
      tier: LeagueTier.fromCode(JsonX.asString(json['tier'])),
      weekStart: JsonX.asDate(json['week_start']) ?? DateTime.now(),
      entries: <LeagueEntry>[
        if (rawEntries is Iterable)
          for (final Object? item in rawEntries)
            LeagueEntry.fromJson(JsonX.asMap(item)),
      ],
      promotionSlots: JsonX.asInt(json['promotion_slots'], fallback: 3),
      relegationSlots: JsonX.asInt(json['relegation_slots'], fallback: 2),
    );
  }

  static bool _sameRanking(List<LeagueEntry> a, List<LeagueEntry> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is League &&
      other.id == id &&
      other.tier == tier &&
      other.weekStart == weekStart &&
      other.promotionSlots == promotionSlots &&
      other.relegationSlots == relegationSlots &&
      _sameRanking(ranking, other.ranking);

  @override
  int get hashCode => Object.hash(id, tier, weekStart, promotionSlots,
      relegationSlots, Object.hashAll(ranking));

  @override
  String toString() => 'League(${tier.label} · ${entries.length} kişi · '
      'sıram: $currentUserRank)';
}
