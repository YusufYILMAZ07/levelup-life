import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';
import 'stat_key.dart';

/// 7 veya 30 günlük tematik meydan okuma.
///
/// Questline'lar tek seferlik görevlerden farklı olarak **bir seriyi** temsil
/// eder: katılım bir kez ödenir, her gün bir görev tamamlanır, sonunda rozet ve
/// toplu XP verilir. 1 gün kaçırmak affedilir (tolerans), 2 gün kaçırmak
/// questline'ı bozar — böylece "her şey ya da hiç" baskısı kırılır.
final class Questline {
  const Questline({
    required this.id,
    required this.title,
    required this.summary,
    required this.stat,
    required this.totalDays,
    required this.dailyXp,
    required this.startedOn,
    this.completedDays = 0,
    this.missedDays = 0,
    this.isPremium = false,
    this.badgeCode,
  })  : assert(totalDays > 0, 'Questline en az 1 gün olmalı'),
        assert(dailyXp >= 0, 'Günlük XP negatif olamaz');

  /// Kaçırılabilecek gün sayısı (questline'ı bozmadan).
  static const int toleranceMisses = 1;

  final String id;
  final String title;
  final String summary;

  /// Questline'ın beslediği ana stat.
  final StatKey stat;

  final int totalDays;
  final int dailyXp;
  final DateTime startedOn;
  final int completedDays;
  final int missedDays;

  /// Ücretli içerik mi? (Free kullanıcıya kilitli gösterilir.)
  final bool isPremium;

  /// Tamamlanınca kazanılacak rozetin kodu.
  final String? badgeCode;

  // ── Türetilmiş değerler ──────────────────────────────────────────────────

  /// 0.0 → 1.0 arası ilerleme.
  double get progress =>
      totalDays == 0 ? 0 : (completedDays / totalDays).clamp(0.0, 1.0);

  int get percent => (progress * 100).round();

  bool get isComplete => completedDays >= totalDays;

  bool get isFailed => missedDays > toleranceMisses;

  bool get isActive => !isComplete && !isFailed;

  /// Sıradaki gün numarası (1 tabanlı); tamamlandıysa [totalDays].
  int get currentDay => (completedDays + 1).clamp(1, totalDays);

  int get remainingDays => (totalDays - completedDays).clamp(0, totalDays);

  /// Toplam ödül havuzu (günlük XP + tamamlama bonusu).
  int get totalXp => dailyXp * totalDays + completionBonusXp;

  /// Questline'ı bitiren kullanıcıya verilen ekstra XP (%50 bonus).
  int get completionBonusXp => (dailyXp * totalDays * 0.5).round();

  /// Bugüne kadar kazanılmış XP.
  int get earnedXp => dailyXp * completedDays;

  /// Tahmini bitiş günü (bugünkü hızla).
  DateTime get estimatedFinishDay =>
      DateX.shiftDays(DateX.dateOnly(startedOn), totalDays - 1);

  // ── Güncellemeler ────────────────────────────────────────────────────────

  /// Bir günü tamamlar. Zaten bitmişse aynı örneği döndürür.
  Questline completeDay() {
    if (isComplete) return this;
    return copyWith(completedDays: completedDays + 1);
  }

  /// Kaçırılan günü kaydeder.
  Questline recordMiss() =>
      isComplete ? this : copyWith(missedDays: missedDays + 1);

  Questline copyWith({
    String? title,
    String? summary,
    StatKey? stat,
    int? totalDays,
    int? dailyXp,
    DateTime? startedOn,
    int? completedDays,
    int? missedDays,
    bool? isPremium,
    String? badgeCode,
  }) {
    return Questline(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      stat: stat ?? this.stat,
      totalDays: totalDays ?? this.totalDays,
      dailyXp: dailyXp ?? this.dailyXp,
      startedOn: startedOn ?? this.startedOn,
      completedDays: completedDays ?? this.completedDays,
      missedDays: missedDays ?? this.missedDays,
      isPremium: isPremium ?? this.isPremium,
      badgeCode: badgeCode ?? this.badgeCode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'summary': summary,
        'stat': stat.code,
        'total_days': totalDays,
        'daily_xp': dailyXp,
        'started_on': DateX.isoDay(startedOn),
        'completed_days': completedDays,
        'missed_days': missedDays,
        'is_premium': isPremium,
        'badge_code': badgeCode,
      };

  factory Questline.fromJson(Map<String, dynamic> json) {
    final int days = JsonX.asInt(json['total_days'], fallback: 7);
    return Questline(
      id: JsonX.asString(json['id']),
      title: JsonX.asString(json['title']),
      summary: JsonX.asString(json['summary']),
      stat: StatKey.tryFromCode(JsonX.asString(json['stat'])) ??
          StatKey.willpower,
      totalDays: days <= 0 ? 7 : days,
      dailyXp: JsonX.asInt(json['daily_xp'], fallback: 20),
      startedOn: DateX.parseIsoDay(JsonX.asString(json['started_on'])) ??
          DateTime.now(),
      completedDays: JsonX.asInt(json['completed_days']),
      missedDays: JsonX.asInt(json['missed_days']),
      isPremium: JsonX.asBool(json['is_premium']),
      badgeCode: json['badge_code'] == null
          ? null
          : JsonX.asString(json['badge_code']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Questline &&
      other.id == id &&
      other.title == title &&
      other.summary == summary &&
      other.stat == stat &&
      other.totalDays == totalDays &&
      other.dailyXp == dailyXp &&
      other.startedOn == startedOn &&
      other.completedDays == completedDays &&
      other.missedDays == missedDays &&
      other.isPremium == isPremium &&
      other.badgeCode == badgeCode;

  @override
  int get hashCode => Object.hash(id, title, stat, totalDays, dailyXp,
      startedOn, completedDays, missedDays, isPremium, badgeCode);

  @override
  String toString() => 'Questline($id · $title · $completedDays/$totalDays gün · '
      '$percent%)';
}
