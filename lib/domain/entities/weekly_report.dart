import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';
import 'stat_key.dart';

/// Pazar akşamı gösterilen haftalık özet.
///
/// Rapor; geçmişi yargılamak yerine **gelecek haftanın odağını** önerir
/// ([focusStat]). Tüm metrikler saf getter: rapor kaydı değişmez (immutable).
final class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.xpEarned,
    required this.questsCompleted,
    required this.targetQuests,
    required this.activeDays,
    required this.streakAtEnd,
    this.strongestStat,
    this.weakestStat,
    this.questlineId,
    this.questlineDaysCompleted = 0,
    this.insight,
  });

  /// Haftanın ilk günü (Pazartesi).
  final DateTime weekStart;

  final int xpEarned;
  final int questsCompleted;

  /// Haftalık hedef (günlük hedef × 7).
  final int targetQuests;

  /// En az 1 görev tamamlanan gün sayısı (0-7).
  final int activeDays;

  /// Hafta sonundaki seri uzunluğu.
  final int streakAtEnd;

  final StatKey? strongestStat;
  final StatKey? weakestStat;
  final String? questlineId;
  final int questlineDaysCompleted;

  /// AI koçun tek paragraflık yorumu (v1'de kural tabanlı, sonra LLM).
  final String? insight;

  // ── Türetilmiş metrikler ─────────────────────────────────────────────────

  DateTime get weekEnd => DateX.shiftDays(DateX.dateOnly(weekStart), 6);

  /// Hedefin ne kadarı tamamlandı (0.0 → 1.0).
  double get completionRate => targetQuests <= 0
      ? 0
      : (questsCompleted / targetQuests).clamp(0.0, 1.0);

  int get completionPercent => (completionRate * 100).round();

  /// Haftanın kaçta kaçında aktifti (0.0 → 1.0).
  double get activeDayRate => (activeDays / 7).clamp(0.0, 1.0);

  /// Güçlü hafta: 5+ aktif gün ve hedefin %70'i.
  bool get isStrongWeek => activeDays >= 5 && completionRate >= 0.7;

  /// Toparlanma haftası: en fazla 2 aktif gün.
  bool get isRebuildWeek => activeDays <= 2;

  /// Gelecek haftanın önerilen odağı.
  StatKey? get focusStat => weakestStat ?? strongestStat;

  String get headline {
    if (isStrongWeek) return 'Muhteşem bir haftaydı!';
    if (isRebuildWeek) return 'Yeni bir başlangıç haftası.';
    if (activeDays >= 4) return 'İstikrar oturuyor.';
    return 'Toparlanma haftası.';
  }

  WeeklyReport copyWith({
    int? xpEarned,
    int? questsCompleted,
    int? targetQuests,
    int? activeDays,
    int? streakAtEnd,
    StatKey? strongestStat,
    StatKey? weakestStat,
    String? questlineId,
    int? questlineDaysCompleted,
    String? insight,
  }) =>
      WeeklyReport(
        weekStart: weekStart,
        xpEarned: xpEarned ?? this.xpEarned,
        questsCompleted: questsCompleted ?? this.questsCompleted,
        targetQuests: targetQuests ?? this.targetQuests,
        activeDays: activeDays ?? this.activeDays,
        streakAtEnd: streakAtEnd ?? this.streakAtEnd,
        strongestStat: strongestStat ?? this.strongestStat,
        weakestStat: weakestStat ?? this.weakestStat,
        questlineId: questlineId ?? this.questlineId,
        questlineDaysCompleted:
            questlineDaysCompleted ?? this.questlineDaysCompleted,
        insight: insight ?? this.insight,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'week_start': DateX.isoDay(weekStart),
        'xp_earned': xpEarned,
        'quests_completed': questsCompleted,
        'target_quests': targetQuests,
        'active_days': activeDays,
        'streak_at_end': streakAtEnd,
        'strongest_stat': strongestStat?.code,
        'weakest_stat': weakestStat?.code,
        'questline_id': questlineId,
        'questline_days_completed': questlineDaysCompleted,
        'insight': insight,
      };

  factory WeeklyReport.fromJson(Map<String, dynamic> json) => WeeklyReport(
        weekStart: DateX.parseIsoDay(JsonX.asString(json['week_start'])) ??
            DateX.today(),
        xpEarned: JsonX.asInt(json['xp_earned']),
        questsCompleted: JsonX.asInt(json['quests_completed']),
        targetQuests: JsonX.asInt(json['target_quests'], fallback: 21),
        activeDays: JsonX.asInt(json['active_days']).clamp(0, 7),
        streakAtEnd: JsonX.asInt(json['streak_at_end']),
        strongestStat:
            StatKey.tryFromCode(JsonX.asString(json['strongest_stat'])),
        weakestStat: StatKey.tryFromCode(JsonX.asString(json['weakest_stat'])),
        questlineId: json['questline_id'] == null
            ? null
            : JsonX.asString(json['questline_id']),
        questlineDaysCompleted: JsonX.asInt(json['questline_days_completed']),
        insight: json['insight'] == null ? null : JsonX.asString(json['insight']),
      );

  @override
  bool operator ==(Object other) =>
      other is WeeklyReport &&
      other.weekStart == weekStart &&
      other.xpEarned == xpEarned &&
      other.questsCompleted == questsCompleted &&
      other.targetQuests == targetQuests &&
      other.activeDays == activeDays &&
      other.streakAtEnd == streakAtEnd &&
      other.strongestStat == strongestStat &&
      other.weakestStat == weakestStat &&
      other.questlineId == questlineId &&
      other.questlineDaysCompleted == questlineDaysCompleted &&
      other.insight == insight;

  @override
  int get hashCode => Object.hash(
        weekStart,
        xpEarned,
        questsCompleted,
        targetQuests,
        activeDays,
        streakAtEnd,
        strongestStat,
        weakestStat,
        questlineId,
        questlineDaysCompleted,
        insight,
      );

  @override
  String toString() => 'WeeklyReport(${DateX.isoDay(weekStart)} · $xpEarned XP · '
      '$questsCompleted/$targetQuests görev · $activeDays/7 gün)';
}
