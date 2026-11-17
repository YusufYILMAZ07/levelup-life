import 'dart:math' as math;

/// Bir statın olgunluk kuşağı (radar değerine göre).
enum StatRank {
  raw(label: 'Ham', threshold: 0),
  novice(label: 'Acemi', threshold: 10),
  developing(label: 'Gelişen', threshold: 25),
  competent(label: 'Yetkin', threshold: 40),
  advanced(label: 'İleri', threshold: 55),
  master(label: 'Usta', threshold: 70),
  legend(label: 'Efsane', threshold: 85);

  const StatRank({required this.label, required this.threshold});

  final String label;

  /// Bu kuşağa girmek için gereken minimum radar değeri (0-100).
  final double threshold;

  StatRank? get next => index + 1 < values.length ? values[index + 1] : null;

  static StatRank forValue(double radarValue) {
    StatRank result = StatRank.raw;
    for (final StatRank rank in values) {
      if (radarValue >= rank.threshold) result = rank;
    }
    return result;
  }
}

/// Stat XP'sini radar grafiğinin 0-100 eksenine çeviren matematik.
///
/// Doğrusal bir eşleme yerine yarım ömür (half-life) eğrisi kullanılır:
/// * ilk 1.200 XP → radar değeri 50
/// * 2.400 XP → 75, 3.600 XP → 87.5 …
///
/// Bu sayede grafik hiçbir zaman "tavan" yapmaz; ileri seviyede ilerleme
/// yavaşlar ama durmaz (RPG hissi için kritik).
abstract final class StatScale {
  /// Radar değerinin 50'ye ulaştığı XP miktarı.
  static const double halfLifeXp = 1200;

  static double radarValue(int xp) {
    if (xp <= 0) return 0;
    final num raw = 100 * (1 - math.pow(0.5, xp / halfLifeXp));
    return raw.clamp(0, 100).toDouble();
  }

  static StatRank rankFor(int xp) => StatRank.forValue(radarValue(xp));

  /// Mevcut kuşak içindeki ilerleme (0.0 → 1.0). Efsane'de 1.0.
  static double progressToNextRank(int xp) {
    final double value = radarValue(xp);
    final StatRank rank = StatRank.forValue(value);
    final StatRank? next = rank.next;
    if (next == null) return 1;
    final double span = next.threshold - rank.threshold;
    if (span <= 0) return 1;
    return ((value - rank.threshold) / span).clamp(0.0, 1.0);
  }

  /// Tersine çözüm: hedef radar değeri için gereken XP (test ve simülasyon).
  static int xpForRadarValue(double value) {
    final double target = value.clamp(0, 99.9);
    if (target <= 0) return 0;
    final double ratio = 100 / (100 - target);
    return (halfLifeXp * (math.log(ratio) / math.ln2)).round();
  }
}
