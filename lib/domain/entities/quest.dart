import '../../core/utils/json_x.dart';
import 'energy_mode.dart';
import 'stat_key.dart';
import 'verification.dart';

/// Görevin hangi yaşam alanına ait olduğu.
enum QuestCategory {
  academic(
    code: 'academic',
    label: 'Akademik',
    defaultStat: StatKey.intelligence,
  ),
  physical(code: 'physical', label: 'Fiziksel', defaultStat: StatKey.strength),
  health(code: 'health', label: 'Sağlık', defaultStat: StatKey.vitality),
  career(code: 'career', label: 'Kariyer', defaultStat: StatKey.productivity),
  mind(code: 'mind', label: 'Zihin', defaultStat: StatKey.willpower);

  const QuestCategory({
    required this.code,
    required this.label,
    required this.defaultStat,
  });

  final String code;
  final String label;
  final StatKey defaultStat;

  static QuestCategory fromCode(String? code) {
    for (final QuestCategory category in values) {
      if (category.code == code || category.name == code) return category;
    }
    return QuestCategory.mind;
  }
}

/// Görevin zorluk derecesi ve XP çarpanı.
enum QuestDifficulty {
  light(code: 'light', label: 'Hafif', xpMultiplier: 1.0, etaLabel: '5-15 dk'),
  moderate(
    code: 'moderate',
    label: 'Orta',
    xpMultiplier: 1.3,
    etaLabel: '20-45 dk',
  ),
  hard(code: 'hard', label: 'Zor', xpMultiplier: 1.6, etaLabel: '45-90 dk'),
  epic(code: 'epic', label: 'Destansı', xpMultiplier: 2.1, etaLabel: '90 dk+');

  const QuestDifficulty({
    required this.code,
    required this.label,
    required this.xpMultiplier,
    required this.etaLabel,
  });

  final String code;
  final String label;
  final double xpMultiplier;
  final String etaLabel;

  static QuestDifficulty fromCode(String? code) {
    for (final QuestDifficulty difficulty in values) {
      if (difficulty.code == code || difficulty.name == code) return difficulty;
    }
    return QuestDifficulty.light;
  }
}

/// Görevin yaşam döngüsü.
enum QuestStatus {
  locked(label: 'Kilitli'),
  active(label: 'Aktif'),
  inProgress(label: 'Devam ediyor'),
  completed(label: 'Tamamlandı'),
  expired(label: 'Süresi doldu'),
  skipped(label: 'Atlandı');

  const QuestStatus({required this.label});

  final String label;

  bool get isOpen =>
      this == QuestStatus.active || this == QuestStatus.inProgress;
  bool get isDone => this == QuestStatus.completed;
}

/// Görevin tekrar periyodu.
enum QuestCadence {
  oneOff(code: 'one_off', label: 'Tek seferlik'),
  daily(code: 'daily', label: 'Günlük'),
  weekly(code: 'weekly', label: 'Haftalık'),
  questline(code: 'questline', label: 'Questline');

  const QuestCadence({required this.code, required this.label});

  final String code;
  final String label;

  static QuestCadence fromCode(String? code) {
    for (final QuestCadence cadence in values) {
      if (cadence.code == code || cadence.name == code) return cadence;
    }
    return QuestCadence.daily;
  }
}

/// Ağır görevin "kötü gün" karşılığı.
///
/// Örn. 45 dk ağırlık antrenmanı → 10 dk esneme. Mikro varyantın kendi XP'si
/// ve gerekirse kendi doğrulaması olur; böylece enerji modu açıldığında görev
/// motoru tek satırla dönüşüm yapar.
final class MicroVariant {
  const MicroVariant({
    required this.title,
    required this.minutes,
    required this.baseXp,
    this.summary,
    this.verification,
  });

  final String title;
  final int minutes;
  final int baseXp;
  final String? summary;

  /// Verilmezse ana görevin doğrulaması kullanılır.
  final QuestVerification? verification;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'minutes': minutes,
    'base_xp': baseXp,
    if (summary != null) 'summary': summary,
    if (verification != null) 'verification': verification!.toJson(),
  };

  factory MicroVariant.fromJson(Map<String, dynamic> json) => MicroVariant(
    title: JsonX.asString(json['title']),
    minutes: JsonX.asInt(json['minutes'], fallback: 10),
    baseXp: JsonX.asInt(json['base_xp'], fallback: 10),
    summary: json['summary'] == null ? null : JsonX.asString(json['summary']),
    verification: json['verification'] == null
        ? null
        : QuestVerification.fromJson(JsonX.asMap(json['verification'])),
  );

  @override
  bool operator ==(Object other) =>
      other is MicroVariant &&
      other.title == title &&
      other.minutes == minutes &&
      other.baseXp == baseXp &&
      other.summary == summary &&
      other.verification == verification;

  @override
  int get hashCode =>
      Object.hash(title, minutes, baseXp, summary, verification);
}

/// Kullanıcıya sunulan tek bir görev (quest).
///
/// [baseXp] ve [estimatedMinutes] her zaman **dengeli moddaki** değerlerdir;
/// enerji modu açıldığında [microVariant] devreye girer ve `effectiveX`
/// getter'ları UI'a doğru değerleri verir. Böylece XP iki kez çarpılmaz.
final class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.summary,
    required this.stat,
    required this.category,
    required this.difficulty,
    required this.baseXp,
    required this.estimatedMinutes,
    required this.verification,
    required this.createdAt,
    this.status = QuestStatus.active,
    this.cadence = QuestCadence.daily,
    this.energyMode = EnergyMode.balanced,
    this.microVariant,
    this.questlineId,
    this.tags = const <String>{},
    this.streakCritical = true,
    this.dueAt,
    this.completedAt,
    this.reflection,
  }) : assert(baseXp >= 0, 'XP negatif olamaz'),
       assert(estimatedMinutes > 0, 'Süre 0 olamaz');

  final String id;
  final String title;
  final String summary;

  /// Görevin beslediği stat.
  final StatKey stat;

  final QuestCategory category;
  final QuestDifficulty difficulty;

  /// Dengeli moddaki ham XP.
  final int baseXp;

  /// Dengeli moddaki tahmini süre (dakika).
  final int estimatedMinutes;

  /// Tamamlama kanıtı (anti-cheat).
  final QuestVerification verification;

  final DateTime createdAt;
  final QuestStatus status;
  final QuestCadence cadence;

  /// Kullanıcının seçtiği enerji modu.
  final EnergyMode energyMode;

  /// Enerji modu açıldığında kullanılacak hafif varyant.
  final MicroVariant? microVariant;

  /// Bağlı olduğu questline (7/30 günlük meydan okuma).
  final String? questlineId;

  final Set<String> tags;

  /// Seriyi koruyan kritik görev mi? (Enerji modunda asla tamamen kaldırılmaz.)
  final bool streakCritical;

  final DateTime? dueAt;
  final DateTime? completedAt;

  /// Mikro yansıma metni (reflection doğrulaması).
  final String? reflection;

  // ── Türetilmiş değerler ──────────────────────────────────────────────────

  bool get isEnergyAdapted => energyMode.convertsToMicro;

  bool get isMicro => isEnergyAdapted && microVariant != null;

  String get effectiveTitle => isMicro ? microVariant!.title : title;

  String get effectiveSummary =>
      isMicro ? (microVariant!.summary ?? summary) : summary;

  int get effectiveMinutes =>
      isMicro ? microVariant!.minutes : estimatedMinutes;

  int get effectiveBaseXp => isMicro ? microVariant!.baseXp : baseXp;

  QuestVerification get effectiveVerification =>
      isMicro ? (microVariant!.verification ?? verification) : verification;

  bool get isCompleted => status == QuestStatus.completed;

  bool get isOpen => status.isOpen;

  bool get requiresProof => effectiveVerification.type.requiresProof;

  bool get isQuestline => questlineId != null;

  /// Dakika başına verim — görev motoru dengelemesinde kullanılır.
  double get xpPerMinute =>
      effectiveMinutes == 0 ? 0 : effectiveBaseXp / effectiveMinutes;

  /// Enerji modu değiştiğinde yeni görev örneği üretir.
  Quest applyEnergyMode(EnergyMode mode) => copyWith(energyMode: mode);

  Quest start() => copyWith(status: QuestStatus.inProgress);

  Quest complete({required DateTime at, String? reflection}) => copyWith(
    status: QuestStatus.completed,
    completedAt: at,
    reflection: reflection,
  );

  Quest expire() => copyWith(status: QuestStatus.expired);

  /// Nullable alanlar `null` verilerek temizlenemez (bilinçli tercih: kazara
  /// veri kaybını önlemek için). Temizlik gereken yerlerde yeni örnek kurulur.
  Quest copyWith({
    String? title,
    String? summary,
    StatKey? stat,
    QuestCategory? category,
    QuestDifficulty? difficulty,
    int? baseXp,
    int? estimatedMinutes,
    QuestVerification? verification,
    QuestStatus? status,
    QuestCadence? cadence,
    EnergyMode? energyMode,
    MicroVariant? microVariant,
    String? questlineId,
    Set<String>? tags,
    bool? streakCritical,
    DateTime? dueAt,
    DateTime? completedAt,
    String? reflection,
  }) {
    return Quest(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      stat: stat ?? this.stat,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      baseXp: baseXp ?? this.baseXp,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      verification: verification ?? this.verification,
      createdAt: createdAt,
      status: status ?? this.status,
      cadence: cadence ?? this.cadence,
      energyMode: energyMode ?? this.energyMode,
      microVariant: microVariant ?? this.microVariant,
      questlineId: questlineId ?? this.questlineId,
      tags: tags ?? this.tags,
      streakCritical: streakCritical ?? this.streakCritical,
      dueAt: dueAt ?? this.dueAt,
      completedAt: completedAt ?? this.completedAt,
      reflection: reflection ?? this.reflection,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'summary': summary,
    'stat': stat.code,
    'category': category.code,
    'difficulty': difficulty.code,
    'base_xp': baseXp,
    'estimated_minutes': estimatedMinutes,
    'verification': verification.toJson(),
    'created_at': createdAt.toIso8601String(),
    'status': status.name,
    'cadence': cadence.code,
    'energy_mode': energyMode.code,
    'micro_variant': microVariant?.toJson(),
    'questline_id': questlineId,
    'tags': tags.toList(growable: false),
    'streak_critical': streakCritical,
    'due_at': dueAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'reflection': reflection,
  };

  factory Quest.fromJson(Map<String, dynamic> json) {
    final QuestCategory category = QuestCategory.fromCode(
      JsonX.asString(json['category']),
    );
    final int minutes = JsonX.asInt(json['estimated_minutes'], fallback: 15);

    return Quest(
      id: JsonX.asString(json['id']),
      title: JsonX.asString(json['title']),
      summary: JsonX.asString(json['summary']),
      stat:
          StatKey.tryFromCode(JsonX.asString(json['stat'])) ??
          category.defaultStat,
      category: category,
      difficulty: QuestDifficulty.fromCode(JsonX.asString(json['difficulty'])),
      baseXp: JsonX.asInt(json['base_xp']),
      estimatedMinutes: minutes <= 0 ? 15 : minutes,
      verification: QuestVerification.fromJson(
        JsonX.asMap(json['verification']),
      ),
      createdAt: JsonX.asDate(json['created_at']) ?? DateTime.now(),
      status: JsonX.asEnum<QuestStatus>(
        QuestStatus.values,
        json['status'],
        fallback: QuestStatus.active,
      ),
      cadence: QuestCadence.fromCode(JsonX.asString(json['cadence'])),
      energyMode: EnergyMode.fromCode(JsonX.asString(json['energy_mode'])),
      microVariant: json['micro_variant'] == null
          ? null
          : MicroVariant.fromJson(JsonX.asMap(json['micro_variant'])),
      questlineId: json['questline_id'] == null
          ? null
          : JsonX.asString(json['questline_id']),
      tags: JsonX.asStringList(json['tags']).toSet(),
      streakCritical: JsonX.asBool(json['streak_critical'], fallback: true),
      dueAt: JsonX.asDate(json['due_at']),
      completedAt: JsonX.asDate(json['completed_at']),
      reflection: json['reflection'] == null
          ? null
          : JsonX.asString(json['reflection']),
    );
  }

  static bool _sameTags(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      other is Quest &&
      other.id == id &&
      other.title == title &&
      other.summary == summary &&
      other.stat == stat &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.baseXp == baseXp &&
      other.estimatedMinutes == estimatedMinutes &&
      other.verification == verification &&
      other.createdAt == createdAt &&
      other.status == status &&
      other.cadence == cadence &&
      other.energyMode == energyMode &&
      other.microVariant == microVariant &&
      other.questlineId == questlineId &&
      _sameTags(other.tags, tags) &&
      other.streakCritical == streakCritical &&
      other.dueAt == dueAt &&
      other.completedAt == completedAt &&
      other.reflection == reflection;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    stat,
    category,
    difficulty,
    baseXp,
    estimatedMinutes,
    verification,
    createdAt,
    status,
    cadence,
    energyMode,
    microVariant,
    questlineId,
    Object.hashAllUnordered(tags),
    streakCritical,
    dueAt,
    completedAt,
    reflection,
  );

  @override
  String toString() =>
      'Quest($id · $effectiveTitle · ${stat.code} · '
      '$effectiveBaseXp XP · $effectiveMinutes dk · ${status.name})';
}
