import 'dart:math' as math;

import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';

/// Tek bir günün XP kaydı — grafik ve takvim için okunabilir ara model.
final class DailyXp {
  const DailyXp({required this.day, required this.xp});

  /// 00:00'a normalize edilmiş gün.
  final DateTime day;

  /// O gün kazanılan toplam XP.
  final int xp;

  bool get isActive => xp > 0;

  @override
  bool operator ==(Object other) =>
      other is DailyXp && other.day == day && other.xp == xp;

  @override
  int get hashCode => Object.hash(day, xp);

  @override
  String toString() => 'DailyXp(${DateX.isoDay(day)} · $xp XP)';
}

/// Günlük XP geçmişi — İlerleme sekmesinin tek veri kaynağı.
///
/// * [UserProfile] içinde saklanır; JSON'u düz bir `gün → XP` haritasıdır,
///   böylece şema değişse bile eski cache dosyaları okunabilir kalır.
/// * Kayıtlar [maxStoredDays] günden eskiye gidince budanır: cihaz deposu
///   sınırsız büyümez, son 13 ay grafik/takvim için yeterlidir.
/// * Tüm sorgular yan etkisizdir; seri hesabı da buradan türetilir, böylece
///   takvim ile `Streak.currentDays` çelişmez.
final class DailyXpLog {
  const DailyXpLog([this.byDay = const <DateTime, int>{}]);

  /// Hiç görev tamamlanmamış karakter.
  static const DailyXpLog empty = DailyXpLog();

  /// Saklanan en uzun geçmiş — 400 gün ≈ 13 ay.
  static const int maxStoredDays = 400;

  /// `00:00` normalize gün → o günün XP toplamı.
  final Map<DateTime, int> byDay;

  bool get isEmpty => byDay.isEmpty;

  bool get isNotEmpty => byDay.isNotEmpty;

  /// En az bir görev tamamlanmış gün sayısı.
  int get activeDays => byDay.values.where((int xp) => xp > 0).length;

  /// Kayıtlı tüm XP'lerin toplamı.
  int get totalXp => byDay.values.fold<int>(0, (int sum, int xp) => sum + xp);

  /// Bir günde kazanılan XP (kayıt yoksa 0).
  int xpOn(DateTime day) => byDay[DateX.dateOnly(day)] ?? 0;

  bool isActiveOn(DateTime day) => xpOn(day) > 0;

  /// Son kayıtlı aktif gün (geçmişe dönük kayıtlar için güvenli).
  DateTime? get lastActiveDay {
    DateTime? last;
    for (final MapEntry<DateTime, int> entry in byDay.entries) {
      if (entry.value <= 0) continue;
      if (last == null || entry.key.isAfter(last)) last = entry.key;
    }
    return last;
  }

  /// XP kazancını kaydeder; aynı gündeki görevler toplanır.
  DailyXpLog record({required DateTime at, required int xp}) {
    if (xp <= 0) return this;
    final DateTime day = DateX.dateOnly(at);
    final Map<DateTime, int> next = Map<DateTime, int>.of(byDay);
    next[day] = (next[day] ?? 0) + xp;
    return DailyXpLog(_prune(next));
  }

  /// [end] gününde biten son [days] günü eskiden yeniye döndürür.
  ///
  /// Kaydı olmayan günler `0 XP` olarak gelir; grafik her zaman sabit
  /// genişlikte kalır, boş gün ekseni kaydırmaz.
  List<DailyXp> series({required DateTime end, required int days}) {
    final DateTime last = DateX.dateOnly(end);
    final int span = math.max(1, days);
    final List<DailyXp> points = <DailyXp>[];
    for (int offset = span - 1; offset >= 0; offset--) {
      final DateTime day = DateX.shiftDays(last, -offset);
      points.add(DailyXp(day: day, xp: xpOn(day)));
    }
    return points;
  }

  /// [day] itibarıyla kesintisiz aktif gün sayısı (gün aktif değilse 0).
  int streakEndingOn(DateTime day) {
    int count = 0;
    DateTime cursor = DateX.dateOnly(day);
    while (isActiveOn(cursor)) {
      count++;
      cursor = DateX.shiftDays(cursor, -1);
    }
    return count;
  }

  /// Bugünkü seri: bugün henüz görev yapılmadıysa dünkü seri korunur.
  int currentStreakOn(DateTime now) {
    final DateTime today = DateX.dateOnly(now);
    if (isActiveOn(today)) return streakEndingOn(today);
    return streakEndingOn(DateX.shiftDays(today, -1));
  }

  /// Kayıtlı en uzun kesintisiz seri.
  int get longestStreak {
    final List<DateTime> active = <DateTime>[
      for (final MapEntry<DateTime, int> entry in byDay.entries)
        if (entry.value > 0) entry.key,
    ]..sort();
    int best = 0;
    int run = 0;
    DateTime? previous;
    for (final DateTime day in active) {
      run = previous != null && DateX.isNextDay(previous, day) ? run + 1 : 1;
      best = math.max(best, run);
      previous = day;
    }
    return best;
  }

  /// Son [days] günlük penceredeki aktif gün sayısı (istatistik kartları).
  int activeDaysIn(DateTime end, int days) => series(
    end: end,
    days: days,
  ).where((DailyXp point) => point.isActive).length;

  static Map<DateTime, int> _prune(Map<DateTime, int> source) {
    if (source.length <= maxStoredDays) return source;
    final List<DateTime> days = source.keys.toList()..sort();
    final List<DateTime> kept = days.sublist(days.length - maxStoredDays);
    return <DateTime, int>{for (final DateTime day in kept) day: source[day]!};
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    for (final MapEntry<DateTime, int> entry in byDay.entries)
      DateX.isoDay(entry.key): entry.value,
  };

  factory DailyXpLog.fromJson(Map<String, dynamic> json) {
    final Map<DateTime, int> byDay = <DateTime, int>{};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final DateTime? day = DateX.parseIsoDay(entry.key);
      final int xp = JsonX.asInt(entry.value);
      if (day == null || xp <= 0) continue;
      byDay[day] = (byDay[day] ?? 0) + xp;
    }
    return DailyXpLog(_prune(byDay));
  }

  @override
  bool operator ==(Object other) {
    if (other is! DailyXpLog || other.byDay.length != byDay.length) {
      return false;
    }
    for (final MapEntry<DateTime, int> entry in byDay.entries) {
      if (other.byDay[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<DateTime, int> entry in byDay.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'DailyXpLog($activeDays gün · $totalXp XP)';
}
