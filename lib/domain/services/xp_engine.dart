import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../entities/rank_tier.dart';

/// Bir seviyenin anlık ilerleme durumu.
///
/// UI'ın ihtiyaç duyduğu her şey burada hazır: `fraction` (progress bar),
/// `xpRemaining` ("120 XP kaldı"), `tier` (rozet rengi) ve `percent`.
final class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.totalXp,
    this.isMaxLevel = false,
  });

  /// Mevcut seviye (1-99).
  final int level;

  /// Bu seviyede toplanan XP.
  final int xpIntoLevel;

  /// Bir sonraki seviye için gereken toplam XP.
  final int xpForNextLevel;

  /// Toplam (kümülatif) XP.
  final int totalXp;

  /// 99. seviyeye ulaşıldı mı?
  final bool isMaxLevel;

  /// Seviye içi ilerleme (0.0 → 1.0). Max seviyede her zaman 1.0.
  double get fraction {
    if (isMaxLevel || xpForNextLevel <= 0) return 1;
    return (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);
  }

  /// UI'da gösterilecek yüzde (0-100).
  int get percent => (fraction * 100).round();

  /// Bir sonraki seviye için kalan XP.
  int get xpRemaining =>
      isMaxLevel ? 0 : math.max(0, xpForNextLevel - xpIntoLevel);

  /// Mevcut unvan kuşağı.
  RankTier get tier => RankTier.forLevel(level);

  /// Kuşak içindeki ilerleme (0.0 → 1.0).
  double get tierProgress => tier.progressForLevel(level);

  @override
  bool operator ==(Object other) =>
      other is LevelProgress &&
      other.level == level &&
      other.xpIntoLevel == xpIntoLevel &&
      other.xpForNextLevel == xpForNextLevel &&
      other.totalXp == totalXp &&
      other.isMaxLevel == isMaxLevel;

  @override
  int get hashCode =>
      Object.hash(level, xpIntoLevel, xpForNextLevel, totalXp, isMaxLevel);

  @override
  String toString() => isMaxLevel
      ? 'LevelProgress(max level $level, ${totalXp}XP)'
      : 'LevelProgress(Lv$level · $xpIntoLevel/$xpForNextLevel XP '
          '($percent%) · $tierProgress kuşak)';
}

/// XP → seviye dönüşüm motoru.
///
/// Eğri bilinçli olarak **hafif artan** tasarlandı:
/// * Lv 1→2 = 100 XP (ilk gün 1 seviye atlanır, motivasyon kancası)
/// * Lv 10 ≈ 180 XP/seviye
/// * Lv 50 ≈ 1.200 XP/seviye
/// * Lv 60'tan sonra kuadratik terim yumuşar (soft cap) — 99 ulaşılabilir kalır.
///
/// Formül: `xp(n) = 100 + 6·(n-1) + 0.35·k²`, burada 60. seviyeden sonra
/// `k = 60 + (n-61)·0.45` (soft cap). Tüm fonksiyonlar saf (pure): aynı girdi
/// her zaman aynı çıktıyı verir, yan etkisi yoktur → kolay test edilir.
abstract final class XpEngine {
  /// Seviye 1 → 2 için gereken XP. Eğrinin başlangıç noktası.
  static const int baseXp = 100;

  /// Her seviyede eklenen doğrusal XP.
  static const double linearStep = 6;

  /// Kuadratik büyüme katsayısı ("sonraki seviyeler daha pahalı").
  static const double quadraticStep = 0.35;

  /// Bu seviyeden sonra eğri yumuşamaya başlar.
  static const int softCapLevel = 60;

  /// Soft cap sonrası kuadratik terimin büyüme hızı çarpanı.
  static const double softCapFactor = 0.45;

  /// Verilen seviyeden **bir sonraki** seviyeye geçmek için gereken XP.
  ///
  /// [level] 1-99 aralığına kırpılır; 99 için de "hayali" bir gereksinim
  /// döner (UI max seviyede bunu göstermez).
  static int xpForLevel(int level) {
    final int n = level
        .clamp(AppConstants.minLevel, AppConstants.maxLevel)
        .toInt();
    final double progress = (n - 1).toDouble();
    final double effective = progress <= softCapLevel
        ? progress
        : softCapLevel + (progress - softCapLevel) * softCapFactor;
    final double curve =
        baseXp + linearStep * progress + quadraticStep * effective * effective;
    return (curve / 5).round() * 5; // 5'in katlarına yuvarla (temiz sayılar)
  }

  /// [level] seviyesine **ulaşmak** için gereken toplam XP.
  ///
  /// `totalXpForLevel(1) == 0`.
  static int totalXpForLevel(int level) {
    final int index = (level - 1).clamp(0, AppConstants.maxLevel - 1).toInt();
    return _cumulativeXp[index];
  }

  /// Kümülatif XP tablosu: `_cumulativeXp[i]` = `i+1`. seviyeye ulaşmak için XP.
  static final List<int> _cumulativeXp = _buildCumulativeXp();

  static List<int> _buildCumulativeXp() {
    final List<int> table = List<int>.filled(AppConstants.maxLevel, 0);
    int running = 0;
    for (int level = AppConstants.minLevel; level < AppConstants.maxLevel; level++) {
      running += xpForLevel(level);
      table[level] = running; // index 0 = Lv2'ye ulaşmak için gereken XP
    }
    return List<int>.unmodifiable(table);
  }

  // ── Sorgular ─────────────────────────────────────────────────────────────

  /// Toplam XP'den seviye bulur (ikili arama, O(log n)).
  static int levelForTotalXp(int totalXp) {
    final int safe = math.max(0, totalXp);
    int low = 0;
    int high = _cumulativeXp.length - 1;
    while (low < high) {
      final int mid = (low + high + 1) >> 1;
      if (_cumulativeXp[mid] <= safe) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + AppConstants.minLevel;
  }

  /// Toplam XP → tam [LevelProgress] (seviye + iç XP + yüzde).
  static LevelProgress progressForTotalXp(int totalXp) {
    final int safe = math.max(0, totalXp);
    final int level = levelForTotalXp(safe);
    final bool isMax = level >= AppConstants.maxLevel;
    final int levelStart = _cumulativeXp[level - AppConstants.minLevel];
    final int into = safe - levelStart;
    final int nextCost = xpForLevel(level);

    return LevelProgress(
      level: level,
      xpIntoLevel: isMax ? math.min(into, nextCost) : into,
      xpForNextLevel: nextCost,
      totalXp: safe,
      isMaxLevel: isMax,
    );
  }

  /// Seviye + seviye içi XP'yi normalize ederek ilerleme üretir.
  ///
  /// `progressFrom(3, 500)` toplamı hesaplayıp seviye atlamalarını otomatik
  /// uygular; taşan XP kaybolmaz.
  static LevelProgress progressFrom(int level, int xpIntoLevel) =>
      progressForTotalXp(totalXpForLevel(level) + math.max(0, xpIntoLevel));

  /// 99. seviyeye ulaşmak için gereken toplam XP (oyunun "tavan"ı).
  static int get maxTotalXp => _cumulativeXp[AppConstants.maxLevel - 1];

  /// Kullanıcının bir sonraki seviyeye ne kadar uzak olduğu.
  static int xpToNextLevel(int totalXp) => progressForTotalXp(totalXp).xpRemaining;

  // ── Ödül hesaplama ───────────────────────────────────────────────────────

  /// Çarpanları sırayla uygular (zorluk × arketip × streak…).
  ///
  /// [baseXp] 0 veya negatifse 0 döner; aksi halde sonuç en az 1 XP'dir, yani
  /// bir görev asla "boşa" gitmez.
  static int applyMultipliers(int baseXp, Iterable<double> multipliers) {
    if (baseXp <= 0) return 0;
    double value = baseXp.toDouble();
    for (final double multiplier in multipliers) {
      value *= multiplier;
    }
    return math.max(1, value.round());
  }

  /// Tek bir bonus çarpanını uygular (`1 + bonus`).
  static int applyBonus(int baseXp, double bonus) =>
      applyMultipliers(baseXp, <double>[1 + bonus]);
}
