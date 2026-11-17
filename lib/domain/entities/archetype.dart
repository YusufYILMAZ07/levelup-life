import 'stat_key.dart';

/// Onboarding sonucunda atanan RPG sınıfı.
///
/// Her sınıf, belirli statlarda XP bonusu verir:
/// * ana stat → +%15
/// * ikincil stat → +%7
/// * [polymath] her statta dengeli +%9 alır (her yerde iyi, hiçbir yerde uç değil).
enum Archetype {
  scholar(
    code: 'scholar',
    title: 'The Scholar',
    label: 'Bilgin',
    tagline: 'Bilgi senin en keskin silahın.',
    description: 'Uzun vadeli öğrenme ve derin odaklanma üzerine kurulu bir sınıf. '
        'Akademik görevlerde %15, disiplin görevlerinde %7 ek XP kazanırsın.',
    statBonuses: <StatKey, double>{
      StatKey.intelligence: 0.15,
      StatKey.willpower: 0.07,
    },
  ),
  athlete(
    code: 'athlete',
    title: 'The Athlete',
    label: 'Atlet',
    tagline: 'Bedeni bir makine gibi çalıştır.',
    description: 'Performans, toparlanma ve fiziksel dayanıklılık odaklı sınıf. '
        'Fiziksel görevlerde %15, sağlık görevlerinde %7 ek XP kazanırsın.',
    statBonuses: <StatKey, double>{
      StatKey.strength: 0.15,
      StatKey.vitality: 0.07,
    },
  ),
  hustler(
    code: 'hustler',
    title: 'The Hustler',
    label: 'Girişimci',
    tagline: 'Çıktı üretmeyen gün kayıp gündür.',
    description: 'Kariyer, portfolyo ve hızlı teslimat odaklı sınıf. '
        'Kariyer görevlerinde %15, akademik görevlerde %7 ek XP kazanırsın.',
    statBonuses: <StatKey, double>{
      StatKey.productivity: 0.15,
      StatKey.intelligence: 0.07,
    },
  ),
  guardian(
    code: 'guardian',
    title: 'The Guardian',
    label: 'Muhafız',
    tagline: 'Önce sağlık, sonra her şey.',
    description: 'Toparlanma, uyku ve beslenme odaklı sınıf. '
        'Sağlık görevlerinde %15, fiziksel görevlerde %7 ek XP kazanırsın.',
    statBonuses: <StatKey, double>{
      StatKey.vitality: 0.15,
      StatKey.strength: 0.07,
    },
  ),
  monk(
    code: 'monk',
    title: 'The Monk',
    label: 'Münzevi',
    tagline: 'Disiplin, motivasyondan daha güçlüdür.',
    description: 'Alışkanlık, erken kalkma ve zihinsel netlik odaklı sınıf. '
        'Disiplin görevlerinde %15, sağlık görevlerinde %7 ek XP kazanırsın.',
    statBonuses: <StatKey, double>{
      StatKey.willpower: 0.15,
      StatKey.vitality: 0.07,
    },
  ),
  polymath(
    code: 'polymath',
    title: 'The Polymath',
    label: 'Çok Yönlü',
    tagline: 'Hiçbir alan senin dışında kalmasın.',
    description: 'Dengeli gelişim isteyenler için sınıf. '
        'Tüm statlarda %9 ek XP kazanırsın — daha küçük ama her yerde geçerli bir bonus.',
    statBonuses: <StatKey, double>{
      StatKey.intelligence: 0.09,
      StatKey.strength: 0.09,
      StatKey.vitality: 0.09,
      StatKey.productivity: 0.09,
      StatKey.willpower: 0.09,
    },
  );

  const Archetype({
    required this.code,
    required this.title,
    required this.label,
    required this.tagline,
    required this.description,
    required this.statBonuses,
  });

  /// Backend'de saklanan sabit kimlik (`profiles.archetype`).
  final String code;

  /// İngilizce sınıf adı (rozetlerde kullanılır).
  final String title;

  /// Türkçe sınıf adı.
  final String label;

  /// Karakter kartındaki tek cümlelik motto.
  final String tagline;

  /// Sınıf seçim ekranındaki uzun açıklama.
  final String description;

  /// Stat başına XP bonus oranı (0.15 = +%15).
  final Map<StatKey, double> statBonuses;

  double bonusFor(StatKey stat) => statBonuses[stat] ?? 0;

  /// En yüksek bonusu alan stat.
  StatKey get primaryStat {
    StatKey best = StatKey.values.first;
    double bestBonus = -1;
    for (final StatKey stat in StatKey.values) {
      final double bonus = bonusFor(stat);
      if (bonus > bestBonus) {
        best = stat;
        bestBonus = bonus;
      }
    }
    return best;
  }

  /// Bonusu olan tüm statlar (sıralı).
  List<StatKey> get boostedStats =>
      StatKey.values.where((StatKey stat) => bonusFor(stat) > 0).toList(growable: false);

  /// Odak alanlarına göre en uygun sınıfı öner (onboarding'de kullanılır).
  ///
  /// Skor = odak statlarındaki bonusların **ortalaması**. Toplam yerine
  /// ortalama kullanılır çünkü [polymath] her statta bonus aldığı için geniş
  /// odak kümelerinde toplam skoru haksız biçimde şişirirdi. Eşitlik
  /// durumunda ilk odak statına daha yüksek bonus veren sınıf kazanır; bu
  /// sayede seçim deterministtir.
  static Archetype recommend(Set<StatKey> focusStats) {
    if (focusStats.isEmpty) return Archetype.polymath;

    final StatKey primaryFocus = focusStats.first;
    Archetype best = Archetype.values.first;
    double bestScore = -1;
    double bestPrimaryScore = -1;

    for (final Archetype archetype in values) {
      double total = 0;
      for (final StatKey stat in focusStats) {
        total += archetype.bonusFor(stat);
      }
      final double score = total / focusStats.length;
      final double primaryScore = archetype.bonusFor(primaryFocus);

      final bool better = score > bestScore + 1e-9 ||
          (score >= bestScore - 1e-9 && primaryScore > bestPrimaryScore);
      if (better) {
        best = archetype;
        bestScore = score;
        bestPrimaryScore = primaryScore;
      }
    }
    return best;
  }

  static Archetype fromCode(String? code) {
    for (final Archetype archetype in values) {
      if (archetype.code == code || archetype.name == code) return archetype;
    }
    return Archetype.polymath;
  }
}
