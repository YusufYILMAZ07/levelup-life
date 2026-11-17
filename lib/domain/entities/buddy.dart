import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';
import 'archetype.dart';

/// Hesap verebilirlik ortağı (co-op buddy).
///
/// Amaç rekabet değil **birlikte sürdürme**: haftada en fazla 3 "dürtme"
/// (nudge) gönderilir, ortak bir questline paylaşılabilir. Sınır bilinçli:
/// bildirim yorgunluğu seriyi kırar.
final class Buddy {
  const Buddy({
    required this.id,
    required this.displayName,
    required this.archetype,
    required this.level,
    this.weeklyXp = 0,
    this.streakDays = 0,
    this.sharedQuestlineId,
    this.lastNudgeSentAt,
    this.nudgesSentThisWeek = 0,
  });

  /// Haftalık dürtme üst sınırı.
  static const int weeklyNudgeLimit = 3;

  /// 7+ gün seri "ateş" olarak gösterilir.
  static const int onFireThreshold = 7;

  final String id;
  final String displayName;
  final Archetype archetype;
  final int level;
  final int weeklyXp;
  final int streakDays;

  /// Ortak devam edilen questline (varsa).
  final String? sharedQuestlineId;

  final DateTime? lastNudgeSentAt;
  final int nudgesSentThisWeek;

  bool get canNudge => nudgesSentThisWeek < weeklyNudgeLimit;

  bool get hasSharedQuestline => sharedQuestlineId != null;

  bool get isOnFire => streakDays >= onFireThreshold;

  bool nudgedOn(DateTime day) =>
      lastNudgeSentAt != null && DateX.isSameDay(lastNudgeSentAt!, day);

  /// Bugün dürtme gönderildiyse tekrar gönderilemez.
  bool canNudgeOn(DateTime day) => canNudge && !nudgedOn(day);

  Buddy nudge(DateTime at) => canNudgeOn(at)
      ? copyWith(
          lastNudgeSentAt: at,
          nudgesSentThisWeek: nudgesSentThisWeek + 1,
        )
      : this;

  /// Haftalık sayaç sıfırlaması (her Pazartesi).
  Buddy resetWeeklyNudges() => copyWith(nudgesSentThisWeek: 0);

  Buddy copyWith({
    String? displayName,
    Archetype? archetype,
    int? level,
    int? weeklyXp,
    int? streakDays,
    String? sharedQuestlineId,
    DateTime? lastNudgeSentAt,
    int? nudgesSentThisWeek,
  }) =>
      Buddy(
        id: id,
        displayName: displayName ?? this.displayName,
        archetype: archetype ?? this.archetype,
        level: level ?? this.level,
        weeklyXp: weeklyXp ?? this.weeklyXp,
        streakDays: streakDays ?? this.streakDays,
        sharedQuestlineId: sharedQuestlineId ?? this.sharedQuestlineId,
        lastNudgeSentAt: lastNudgeSentAt ?? this.lastNudgeSentAt,
        nudgesSentThisWeek: nudgesSentThisWeek ?? this.nudgesSentThisWeek,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
        'archetype': archetype.code,
        'level': level,
        'weekly_xp': weeklyXp,
        'streak_days': streakDays,
        'shared_questline_id': sharedQuestlineId,
        'last_nudge_sent_at': lastNudgeSentAt?.toIso8601String(),
        'nudges_sent_this_week': nudgesSentThisWeek,
      };

  factory Buddy.fromJson(Map<String, dynamic> json) => Buddy(
        id: JsonX.asString(json['id']),
        displayName: JsonX.asString(json['display_name'], fallback: 'Gezgin'),
        archetype: Archetype.fromCode(JsonX.asString(json['archetype'])),
        level: JsonX.asInt(json['level'], fallback: 1),
        weeklyXp: JsonX.asInt(json['weekly_xp']),
        streakDays: JsonX.asInt(json['streak_days']),
        sharedQuestlineId: json['shared_questline_id'] == null
            ? null
            : JsonX.asString(json['shared_questline_id']),
        lastNudgeSentAt: JsonX.asDate(json['last_nudge_sent_at']),
        nudgesSentThisWeek: JsonX.asInt(json['nudges_sent_this_week']),
      );

  @override
  bool operator ==(Object other) =>
      other is Buddy &&
      other.id == id &&
      other.displayName == displayName &&
      other.archetype == archetype &&
      other.level == level &&
      other.weeklyXp == weeklyXp &&
      other.streakDays == streakDays &&
      other.sharedQuestlineId == sharedQuestlineId &&
      other.lastNudgeSentAt == lastNudgeSentAt &&
      other.nudgesSentThisWeek == nudgesSentThisWeek;

  @override
  int get hashCode => Object.hash(id, displayName, archetype, level, weeklyXp,
      streakDays, sharedQuestlineId, lastNudgeSentAt, nudgesSentThisWeek);

  @override
  String toString() =>
      'Buddy($displayName · Lv$level · ${streakDays}g seri · $weeklyXp XP)';
}
