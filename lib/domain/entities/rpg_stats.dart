import 'dart:math' as math;

import '../../core/utils/json_x.dart';
import '../services/stat_scale.dart';
import 'stat_key.dart';

/// Tek bir statın anlık durumu.
final class StatProgress {
  const StatProgress({
    required this.stat,
    this.xp = 0,
    this.questsCompleted = 0,
  });

  final StatKey stat;
  final int xp;
  final int questsCompleted;

  /// Radar grafiğinde kullanılan 0-100 değeri.
  double get radarValue => StatScale.radarValue(xp);

  StatRank get rank => StatScale.rankFor(xp);

  /// Mevcut stat kuşağı içindeki ilerleme (0.0 → 1.0).
  double get rankProgress => StatScale.progressToNextRank(xp);

  StatProgress gainXp(int amount) => copyWith(xp: xp + math.max(0, amount));

  /// Görev tamamlandığında XP'yi ekler ve sayaçyı artırır.
  StatProgress recordQuest(int amount) => StatProgress(
        stat: stat,
        xp: xp + math.max(0, amount),
        questsCompleted: questsCompleted + 1,
      );

  StatProgress copyWith({int? xp, int? questsCompleted}) => StatProgress(
        stat: stat,
        xp: xp ?? this.xp,
        questsCompleted: questsCompleted ?? this.questsCompleted,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stat': stat.code,
        'xp': xp,
        'quests_completed': questsCompleted,
      };

  factory StatProgress.fromJson(Map<String, dynamic> json) => StatProgress(
        stat: StatKey.tryFromCode(JsonX.asString(json['stat'])) ?? StatKey.intelligence,
        xp: JsonX.asInt(json['xp']),
        questsCompleted: JsonX.asInt(json['quests_completed']),
      );

  @override
  bool operator ==(Object other) =>
      other is StatProgress &&
      other.stat == stat &&
      other.xp == xp &&
      other.questsCompleted == questsCompleted;

  @override
  int get hashCode => Object.hash(stat, xp, questsCompleted);

  @override
  String toString() => 'StatProgress(${stat.code}: $xp XP, $questsCompleted görev)';
}

/// Karakterin 5 eksenli XP tablosu.
///
/// Harita her zaman 5 statın tamamını içerir; eksik stat `0 XP` olarak okunur.
/// Böylece UI tarafında null kontrolü gerekmez.
final class RpgStats {
  const RpgStats._(this._byStat);

  final Map<StatKey, StatProgress> _byStat;

  /// Yeni karakter: her stat 0 XP.
  static const RpgStats initial = RpgStats._(<StatKey, StatProgress>{
    StatKey.intelligence: StatProgress(stat: StatKey.intelligence),
    StatKey.strength: StatProgress(stat: StatKey.strength),
    StatKey.vitality: StatProgress(stat: StatKey.vitality),
    StatKey.productivity: StatProgress(stat: StatKey.productivity),
    StatKey.willpower: StatProgress(stat: StatKey.willpower),
  });

  factory RpgStats.fromProgress(Iterable<StatProgress> progress) {
    final Map<StatKey, StatProgress> map = <StatKey, StatProgress>{
      for (final StatKey stat in StatKey.values) stat: StatProgress(stat: stat),
    };
    for (final StatProgress item in progress) {
      map[item.stat] = item;
    }
    return RpgStats._(Map<StatKey, StatProgress>.unmodifiable(map));
  }

  /// `{ "INT": {"xp": 320}, ... }` formatını okur.
  factory RpgStats.fromJson(Map<String, dynamic> json) {
    final List<StatProgress> progress = <StatProgress>[];
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final StatKey? stat = StatKey.tryFromCode(entry.key);
      if (stat == null) continue;
      final Map<String, dynamic> map = JsonX.asMap(entry.value);
      progress.add(
        StatProgress(
          stat: stat,
          xp: JsonX.asInt(map['xp']),
          questsCompleted: JsonX.asInt(map['quests_completed']),
        ),
      );
    }
    return RpgStats.fromProgress(progress);
  }

  StatProgress operator [](StatKey stat) => _byStat[stat] ?? StatProgress(stat: stat);

  /// Radar çizimi için sabit sırada (INT → WIL) liste.
  List<StatProgress> get ordered =>
      <StatProgress>[for (final StatKey stat in StatKey.values) this[stat]];

  Map<StatKey, StatProgress> get all => Map<StatKey, StatProgress>.unmodifiable(_byStat);

  int get totalXp =>
      ordered.fold<int>(0, (int sum, StatProgress item) => sum + item.xp);

  int get totalQuests =>
      ordered.fold<int>(0, (int sum, StatProgress item) => sum + item.questsCompleted);

  /// Radar grafiğinin 5 köşesi (0-100).
  List<double> get radarValues =>
      <double>[for (final StatProgress item in ordered) item.radarValue];

  double get averageRadarValue =>
      radarValues.fold<double>(0, (double sum, double value) => sum + value) /
      StatKey.values.length;

  /// En yüksek XP'li stat (tümü 0 ise INT).
  StatProgress get strongest {
    StatProgress best = ordered.first;
    for (final StatProgress item in ordered) {
      if (item.xp > best.xp) best = item;
    }
    return best;
  }

  /// Geliştirilmesi en çok gereken stat — AI koç raporunun temel girdisi.
  StatProgress get weakest {
    StatProgress low = ordered.first;
    for (final StatProgress item in ordered) {
      if (item.xp < low.xp) low = item;
    }
    return low;
  }

  /// Statlar arası maksimum fark (dengesizlik göstergesi, 0-100).
  double get imbalance {
    final List<double> values = radarValues;
    return values.reduce(math.max) - values.reduce(math.min);
  }

  RpgStats gainXp(StatKey stat, int amount) =>
      _replace(stat, this[stat].gainXp(amount));

  RpgStats recordQuest(StatKey stat, int amount) =>
      _replace(stat, this[stat].recordQuest(amount));

  RpgStats _replace(StatKey stat, StatProgress next) => RpgStats._(
        Map<StatKey, StatProgress>.unmodifiable(<StatKey, StatProgress>{
          ..._byStat,
          stat: next,
        }),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final StatProgress item in ordered) item.stat.code: item.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (other is! RpgStats) return false;
    for (final StatKey stat in StatKey.values) {
      if (this[stat] != other[stat]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(<StatProgress>[
        for (final StatKey stat in StatKey.values) this[stat],
      ]);

  @override
  String toString() => 'RpgStats(totalXp: $totalXp, radar: $radarValues)';
}
