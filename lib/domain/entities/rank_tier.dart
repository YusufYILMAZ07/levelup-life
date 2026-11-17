/// Level 1 → 99 yolculuğundaki unvan kuşakları.
///
/// Unvan; seviyeye göre profil çerçevesini, rozet rengini ve lig eşleşmesini
/// belirler. Renkler UI katmanındadır (`RankTierPalette`), domain sadece
/// eşikleri bilir.
enum RankTier {
  rookie(code: 'rookie', label: 'Çaylak', minLevel: 1, maxLevel: 14),
  journeyman(code: 'journeyman', label: 'Kalfa', minLevel: 15, maxLevel: 29),
  expert(code: 'expert', label: 'Uzman', minLevel: 30, maxLevel: 49),
  master(code: 'master', label: 'Üstat', minLevel: 50, maxLevel: 74),
  legend(code: 'legend', label: 'Efsane', minLevel: 75, maxLevel: 99);

  const RankTier({
    required this.code,
    required this.label,
    required this.minLevel,
    required this.maxLevel,
  });

  final String code;
  final String label;
  final int minLevel;
  final int maxLevel;

  /// Kuşağın kapsadığı seviye sayısı.
  int get levelSpan => maxLevel - minLevel + 1;

  /// Kuşak içindeki ilerleme (0.0 → 1.0).
  double progressForLevel(int level) {
    final int clamped = level.clamp(minLevel, maxLevel);
    return ((clamped - minLevel) / levelSpan).clamp(0.0, 1.0);
  }

  /// Bir sonraki kuşak; Efsane'de null.
  RankTier? get next => index + 1 < values.length ? values[index + 1] : null;

  static RankTier forLevel(int level) {
    for (final RankTier tier in values) {
      if (level <= tier.maxLevel) return tier;
    }
    return RankTier.legend;
  }

  static RankTier fromCode(String? code) {
    for (final RankTier tier in values) {
      if (tier.code == code || tier.name == code) return tier;
    }
    return RankTier.rookie;
  }
}
