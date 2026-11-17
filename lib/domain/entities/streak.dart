import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';

/// Günlük seri (streak) durumu.
///
/// Kurallar:
/// * Aynı gün ikinci kez görev tamamlamak seriyi artırmaz.
/// * Dün aktif olunduysa bugün +1.
/// * 1 gün atlanırsa ve dondurma hakkı varsa seri kurtarılabilir.
/// * 2+ gün atlanırsa seri 1'e döner.
final class Streak {
  const Streak({
    this.currentDays = 0,
    this.longestDays = 0,
    this.lastActiveDay,
    this.freezeTokens = AppConstants.startingFreezeTokens,
    this.totalActiveDays = 0,
  });

  /// Hesabı yeni açılmış karakter.
  static const Streak empty = Streak();

  /// Kesintisiz aktif gün sayısı.
  final int currentDays;

  /// Kariyer rekoru.
  final int longestDays;

  /// Son görev tamamlanan gün (00:00'a normalize edilmiş).
  final DateTime? lastActiveDay;

  /// Kalan seri dondurma hakkı.
  final int freezeTokens;

  /// Toplam aktif gün sayısı (heatmap ve özet için).
  final int totalActiveDays;

  bool get isActive => currentDays > 0;

  /// Verilen gün için seri tamamlanmış mı?
  bool isCompletedOn(DateTime day) =>
      lastActiveDay != null && DateX.isSameDay(lastActiveDay!, day);

  /// Seri hâlâ kurtarılabilir mi (bugün veya dün aktiflik var)?
  bool isAliveOn(DateTime day) {
    final DateTime? last = lastActiveDay;
    if (last == null) return false;
    final int gap = DateX.daysBetween(last, day);
    return gap == 0 || gap == 1;
  }

  /// Bugün henüz görev yapılmadı ve dün aktif olunduysa seri risk altında.
  bool isAtRiskOn(DateTime day) {
    final DateTime? last = lastActiveDay;
    if (last == null || currentDays <= 0) return false;
    return DateX.daysBetween(last, day) == 1;
  }

  /// Dün kaçırıldıysa ve hak varsa seri kurtarılabilir mi?
  bool canFreezeOn(DateTime day) {
    final DateTime? last = lastActiveDay;
    if (last == null || freezeTokens <= 0) return false;
    return DateX.daysBetween(last, day) == 2;
  }

  /// Görev tamamlandığında çağrılır; yeni [Streak] döndürür.
  Streak registerActivity(DateTime when) {
    final DateTime day = DateX.dateOnly(when);
    final DateTime? last = lastActiveDay;

    if (last != null && DateX.isSameDay(last, day)) return this;
    // Geçmişe dönük tamamlama seriyi bozmaz.
    if (last != null && day.isBefore(last)) return this;

    final bool continues = last != null && DateX.isNextDay(last, day);
    final int nextCurrent = continues ? currentDays + 1 : 1;

    return Streak(
      currentDays: nextCurrent,
      longestDays: math.max(longestDays, nextCurrent),
      lastActiveDay: day,
      freezeTokens: freezeTokens,
      totalActiveDays: totalActiveDays + 1,
    );
  }

  /// Kaçırılan günü dondurma hakkı ile kapatır.
  ///
  /// Seri sayısı artmaz; sadece "dün aktifmiş gibi" işaretlenir. Böylece bugün
  /// görev yapan kullanıcı seriyi +1 ile sürdürür.
  Streak freezeMissedDay(DateTime now) {
    if (!canFreezeOn(now)) return this;
    final DateTime bridgedDay = DateX.shiftDays(DateX.dateOnly(now), -1);
    return copyWith(
      lastActiveDay: bridgedDay,
      freezeTokens: freezeTokens - 1,
    );
  }

  Streak addFreezeTokens(int amount) => copyWith(
        freezeTokens: math.min(
          AppConstants.maxFreezeTokens,
          math.max(0, freezeTokens + amount),
        ),
      );

  Streak reset() => Streak(
        currentDays: 0,
        longestDays: longestDays,
        lastActiveDay: lastActiveDay,
        freezeTokens: freezeTokens,
        totalActiveDays: totalActiveDays,
      );

  Streak copyWith({
    int? currentDays,
    int? longestDays,
    DateTime? lastActiveDay,
    int? freezeTokens,
    int? totalActiveDays,
  }) {
    return Streak(
      currentDays: currentDays ?? this.currentDays,
      longestDays: longestDays ?? this.longestDays,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      freezeTokens: freezeTokens ?? this.freezeTokens,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'current_days': currentDays,
        'longest_days': longestDays,
        'last_active_day': lastActiveDay == null ? null : DateX.isoDay(lastActiveDay!),
        'freeze_tokens': freezeTokens,
        'total_active_days': totalActiveDays,
      };

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        currentDays: JsonX.asInt(json['current_days']),
        longestDays: JsonX.asInt(json['longest_days']),
        lastActiveDay: DateX.parseIsoDay(JsonX.asString(json['last_active_day'])),
        freezeTokens: JsonX.asInt(
          json['freeze_tokens'],
          fallback: AppConstants.startingFreezeTokens,
        ),
        totalActiveDays: JsonX.asInt(json['total_active_days']),
      );

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.currentDays == currentDays &&
      other.longestDays == longestDays &&
      other.lastActiveDay == lastActiveDay &&
      other.freezeTokens == freezeTokens &&
      other.totalActiveDays == totalActiveDays;

  @override
  int get hashCode => Object.hash(
        currentDays,
        longestDays,
        lastActiveDay,
        freezeTokens,
        totalActiveDays,
      );

  @override
  String toString() => 'Streak($currentDays gün, rekor $longestDays, '
      '$freezeTokens dondurma)';
}
