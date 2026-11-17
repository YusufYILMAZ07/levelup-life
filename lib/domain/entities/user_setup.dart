import 'dart:math' as math;

import '../../core/utils/json_x.dart';
import 'archetype.dart';
import 'goal_type.dart';
import 'stat_key.dart';
import 'user_profile.dart';

/// Günlük tempoya göre görev yükü (Adım 4).
enum DailyTempo {
  relaxed(
    code: 'relaxed',
    label: 'Rahat',
    minutes: 15,
    questTarget: 2,
    description: 'Günde 15 dakika — alışkanlığı kur, gerisini zamanla büyüt.',
  ),
  balanced(
    code: 'balanced',
    label: 'Dengeli',
    minutes: 45,
    questTarget: 4,
    description: 'Günde 45 dakika — okul/iş ile gelişim arasında sağlıklı denge.',
  ),
  hardcore(
    code: 'hardcore',
    label: 'Hardcore',
    minutes: 90,
    questTarget: 6,
    description: 'Günde 90+ dakika — yüksek tempo, hızlı seviye atlama.',
  );

  const DailyTempo({
    required this.code,
    required this.label,
    required this.minutes,
    required this.questTarget,
    required this.description,
  });

  final String code;
  final String label;

  /// Günlük ayrılan süre (dakika).
  final int minutes;

  /// Bu tempoda üretilecek günlük görev sayısı.
  final int questTarget;

  final String description;

  String get labelWithMinutes => '$label · $minutes dk';

  static DailyTempo fromCode(String? code) {
    for (final DailyTempo tempo in values) {
      if (tempo.code == code || tempo.name == code) return tempo;
    }
    return DailyTempo.balanced;
  }
}

/// Çalışanlar için günlük iş yoğunluğu (Adım 2).
enum Workload {
  light(
    code: 'light',
    label: 'Sakin',
    description: 'Günde ~4 saat, akşamlarım boş',
    tempoFactor: 0.85,
  ),
  balanced(
    code: 'balanced',
    label: 'Dengeli',
    description: 'Günde ~6 saat, düzenli akış',
    tempoFactor: 1.0,
  ),
  intense(
    code: 'intense',
    label: 'Yoğun',
    description: 'Günde 8+ saat, kısıtlı zaman',
    tempoFactor: 1.15,
  );

  const Workload({
    required this.code,
    required this.label,
    required this.description,
    required this.tempoFactor,
  });

  final String code;
  final String label;
  final String description;

  /// Görev süresi bütçesini ölçekleyen katsayı (yoğun iş → daha kısa görev).
  final double tempoFactor;

  static Workload fromCode(String? code) {
    for (final Workload workload in values) {
      if (workload.code == code || workload.name == code) return workload;
    }
    return Workload.balanced;
  }
}

/// Onboarding'de toplanan **kişi bilgileri**.
///
/// RPG verisi ([UserProfile]) ile kişisel bağlam (bölüm, sınıf, hedefler) ayrı
/// tutulur: bu nesne görev motorunun girdisidir, profil ise oyunun çıktısıdır.
final class UserSetup {
  const UserSetup({
    this.displayName = '',
    this.role = LifeRole.student,
    this.studyField = '',
    this.gradeYear = 0,
    this.sector = '',
    this.workload = Workload.balanced,
    this.goals = const <GoalType>{},
    this.tempo = DailyTempo.balanced,
  });

  /// Boş taslak — onboarding sihirbazı bu değerle açılır.
  static const UserSetup empty = UserSetup();

  final String displayName;
  final LifeRole role;

  /// Üniversite bölümü / lise alanı / sınav alanı.
  final String studyField;

  /// 1-4 arası sınıf; 0 = uygulanamaz (çalışan, sınav hazırlığı).
  final int gradeYear;

  /// Çalışan / serbest çalışan için sektör.
  final String sector;

  final Workload workload;

  /// Adım 3'te seçilen hedefler.
  final Set<GoalType> goals;

  /// Adım 4'te seçilen günlük tempo.
  final DailyTempo tempo;

  // ── Türetilmiş değerler ──────────────────────────────────────────────────

  bool get isStudent => role.isStudentRole;

  bool get isProfessional => role.isProfessionalRole;

  bool get hasIdentity => displayName.trim().length >= 2;

  /// Adım 2 tamam mı? (role göre dinamik kural)
  bool get hasDetails =>
      isProfessional ? sector.trim().isNotEmpty : studyField.trim().isNotEmpty;

  bool get hasGoals => goals.isNotEmpty;

  bool get isComplete => hasIdentity && hasDetails && hasGoals;

  /// "Bilgisayar Mühendisliği · 3. Sınıf" gibi tek satırlık bağlam.
  String get trackLabel {
    if (isProfessional) {
      return sector.trim().isEmpty ? role.label : sector.trim();
    }
    final String field = studyField.trim();
    if (field.isEmpty) return role.label;
    if (gradeYear >= 1 && gradeYear <= 4) {
      return '$field · $gradeYear. Sınıf';
    }
    return field;
  }

  /// Hedeflerden türeyen odak statları (birincil → ikincil sırası korunur).
  Set<StatKey> get focusStats {
    final Set<StatKey> stats = <StatKey>{};
    for (final GoalType goal in goals) {
      stats.add(goal.primaryStat);
      final StatKey? secondary = goal.secondaryStat;
      if (secondary != null) stats.add(secondary);
    }
    return stats;
  }

  /// Odak kümesine göre atanan RPG sınıfı.
  Archetype get archetype => Archetype.recommend(focusStats);

  /// Günlük üretilecek görev sayısı (tempo + iş yükü).
  int get dailyQuestTarget {
    final int base = tempo.questTarget;
    if (!isProfessional) return base;
    final int adjusted = (base * workload.tempoFactor).round();
    return adjusted.clamp(2, 7);
  }

  /// Görev şablonlarında `{field}` yerine geçen metin.
  String get personalizationLabel {
    if (isProfessional) {
      return sector.trim().isEmpty ? role.label : sector.trim();
    }
    return studyField.trim().isEmpty ? role.label : studyField.trim();
  }

  /// Onboarding özetindeki radar grafiği: hedeflerin stat ağırlıkları.
  ///
  /// Henüz XP yok; bu yüzden grafik "başlangıç eğilimini" gösterir (0-100).
  Map<StatKey, double> get startingRadar {
    final Map<StatKey, double> weights = <StatKey, double>{
      for (final StatKey stat in StatKey.values) stat: 0,
    };
    for (final GoalType goal in goals) {
      weights[goal.primaryStat] = weights[goal.primaryStat]! + 70;
      final StatKey? secondary = goal.secondaryStat;
      if (secondary != null) {
        weights[secondary] = weights[secondary]! + 40;
      }
    }
    final double max = weights.values.fold<double>(0, math.max);
    if (max <= 0) {
      return <StatKey, double>{
        for (final StatKey stat in StatKey.values) stat: 10,
      };
    }
    return <StatKey, double>{
      for (final MapEntry<StatKey, double> entry in weights.entries)
        entry.key: 14 + (entry.value / max) * 78,
    };
  }

  /// Bu cevaplardan oyun profilini üretir.
  ///
  /// Deterministik avatar tohumu isimden türetilir → aynı isim her zaman aynı
  /// avatarı alır (cihazlar arası tutarlılık, backend gerekmeden).
  UserProfile toProfile({DateTime? now, String id = 'local-player'}) {
    final DateTime timestamp = now ?? DateTime.now();
    final String name = displayName.trim().isEmpty ? 'Gezgin' : displayName.trim();
    int seed = 7;
    for (final int rune in name.runes) {
      seed = (seed * 31 + rune) & 0x7FFFFFFF;
    }
    return UserProfile.starter(
      id: id,
      displayName: name,
      role: role,
      focusStats: focusStats,
      archetype: archetype,
      createdAt: timestamp,
    ).completeOnboarding(
      role: role,
      focusStats: focusStats,
      archetype: archetype,
      dailyQuestTarget: dailyQuestTarget,
    ).copyWith(
      avatarSeed: seed % 1000,
      lastActiveAt: timestamp,
    );
  }

  UserSetup copyWith({
    String? displayName,
    LifeRole? role,
    String? studyField,
    int? gradeYear,
    String? sector,
    Workload? workload,
    Set<GoalType>? goals,
    DailyTempo? tempo,
  }) {
    return UserSetup(
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      studyField: studyField ?? this.studyField,
      gradeYear: gradeYear ?? this.gradeYear,
      sector: sector ?? this.sector,
      workload: workload ?? this.workload,
      goals: goals ?? this.goals,
      tempo: tempo ?? this.tempo,
    );
  }

  /// Bir hedefi seçer / seçimi kaldırır (Adım 3 kartları için).
  UserSetup toggleGoal(GoalType goal) {
    final Set<GoalType> next = <GoalType>{...goals};
    if (!next.remove(goal)) next.add(goal);
    return copyWith(goals: next);
  }

  // ── Serileştirme ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
        'display_name': displayName,
        'role': role.code,
        'study_field': studyField,
        'grade_year': gradeYear,
        'sector': sector,
        'workload': workload.code,
        'goals': <String>[for (final GoalType goal in goals) goal.code],
        'tempo': tempo.code,
      };

  factory UserSetup.fromJson(Map<String, dynamic> json) {
    final Set<GoalType> goals = <GoalType>{};
    for (final String code in JsonX.asStringList(json['goals'])) {
      final GoalType? goal = GoalType.tryFromCode(code);
      if (goal != null) goals.add(goal);
    }
    return UserSetup(
      displayName: JsonX.asString(json['display_name']),
      role: LifeRole.fromCode(JsonX.asString(json['role'])),
      studyField: JsonX.asString(json['study_field']),
      gradeYear: JsonX.asInt(json['grade_year']).clamp(0, 4),
      sector: JsonX.asString(json['sector']),
      workload: Workload.fromCode(JsonX.asString(json['workload'])),
      goals: goals,
      tempo: DailyTempo.fromCode(JsonX.asString(json['tempo'])),
    );
  }

  static bool _sameGoals(Set<GoalType> a, Set<GoalType> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      other is UserSetup &&
      other.displayName == displayName &&
      other.role == role &&
      other.studyField == studyField &&
      other.gradeYear == gradeYear &&
      other.sector == sector &&
      other.workload == workload &&
      _sameGoals(other.goals, goals) &&
      other.tempo == tempo;

  @override
  int get hashCode => Object.hash(
        displayName,
        role,
        studyField,
        gradeYear,
        sector,
        workload,
        Object.hashAllUnordered(goals),
        tempo,
      );

  @override
  String toString() => 'UserSetup($displayName · ${role.label} · $trackLabel · '
      '${goals.length} hedef · ${tempo.label})';
}
