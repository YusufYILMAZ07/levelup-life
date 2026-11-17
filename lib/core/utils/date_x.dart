/// Tarih işlemleri için yan etkisiz yardımcılar.
///
/// Gün farkı hesabı UTC üzerinden yapılır; böylece yaz saati geçişlerinde
/// streak yanlışlıkla sıfırlanmaz.
abstract final class DateX {
  /// Saat bilgisini atıp yerel günün 00:00'ını döndürür.
  static DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  /// Bugünün 00:00'ı (testlerde [now] enjekte edilebilir).
  static DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `to - from` gün farkı (negatif olabilir).
  static int daysBetween(DateTime from, DateTime to) {
    final DateTime a = DateTime.utc(from.year, from.month, from.day);
    final DateTime b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static bool isNextDay(DateTime previous, DateTime current) =>
      daysBetween(previous, current) == 1;

  /// Gün ekler/çıkarır. Ay ve yıl taşmaları DateTime tarafından normalize edilir.
  static DateTime shiftDays(DateTime value, int days) =>
      DateTime(value.year, value.month, value.day + days);

  /// `2026-11-15` formatında gün anahtarı (heatmap ve cache için).
  static String isoDay(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? parseIsoDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    return parsed == null ? null : dateOnly(parsed);
  }

  /// 0 = Pazartesi … 6 = Pazar.
  static int weekdayIndex(DateTime value) => value.weekday - 1;

  /// Son [count] günü eskiden yeniye sıralı döndürür (ısı haritası ızgarası).
  static List<DateTime> lastNDays(int count, {DateTime? end}) {
    final DateTime last = today(end);
    return <DateTime>[for (int i = count - 1; i >= 0; i--) shiftDays(last, -i)];
  }
}
