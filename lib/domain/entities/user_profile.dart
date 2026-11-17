import 'dart:math' as math;

import '../../core/utils/json_x.dart';
import '../services/xp_engine.dart';
import 'archetype.dart';
import 'daily_xp_log.dart';
import 'energy_mode.dart';
import 'rank_tier.dart';
import 'rpg_stats.dart';
import 'stat_key.dart';
import 'streak.dart';

/// Onboarding'de sorulan "hayattaki ana rolün ne?" sorusunun cevabı.
///
/// Rol; görev havuzunun ağırlığını belirler (öğrenci → akademik ağırlıklı,
/// çalışan → kariyer ağırlıklı) ama statları kilitlemez.
enum LifeRole {
  student(code: 'student', label: 'Üniversite Öğrencisi', tagline: 'Sınavlar, bölümler, öğrenme.'),
  highSchool(
    code: 'high_school',
    label: 'Lise Öğrencisi',
    tagline: 'Dersler, okul, üniversiteye hazırlık.',
  ),
  examPrep(
    code: 'exam_prep',
    label: 'Sınav Hazırlığı',
    tagline: 'Tek hedef: hedeflediğin sınavı kazanmak.',
  ),
  employee(code: 'employee', label: 'Çalışan / Profesyonel', tagline: 'Kariyer, odak, iş-yaşam dengesi.'),
  freelancer(code: 'freelancer', label: 'Serbest Çalışan', tagline: 'Portfolyo, teslimat, müşteri.'),
  explorer(code: 'explorer', label: 'Keşifte', tagline: 'Yön arıyorum, deniyorum.');

  const LifeRole({required this.code, required this.label, required this.tagline});

  final String code;
  final String label;
  final String tagline;

  /// Bölüm/sınıf soruları gösterilsin mi?
  bool get isStudentRole =>
      this == LifeRole.student || this == LifeRole.highSchool || this == LifeRole.examPrep;

  /// Sektör/yoğunluk soruları gösterilsin mi?
  bool get isProfessionalRole =>
      this == LifeRole.employee || this == LifeRole.freelancer;

  /// Bu rol için görev havuzunda öne çıkacak kategoriler.
  List<StatKey> get weightedStats => switch (this) {
        LifeRole.student => <StatKey>[StatKey.intelligence, StatKey.willpower],
        LifeRole.highSchool => <StatKey>[StatKey.intelligence, StatKey.willpower],
        LifeRole.examPrep => <StatKey>[StatKey.intelligence, StatKey.willpower],
        LifeRole.employee => <StatKey>[StatKey.productivity, StatKey.vitality],
        LifeRole.freelancer => <StatKey>[StatKey.productivity, StatKey.intelligence],
        LifeRole.explorer => <StatKey>[StatKey.vitality, StatKey.willpower],
      };

  static LifeRole fromCode(String? code) {
    for (final LifeRole role in values) {
      if (role.code == code || role.name == code) return role;
    }
    return LifeRole.student;
  }
}

/// XP kazanımının sonucu — kutlama ekranı için seviye bilgisini taşır.
final class XpAward {
  const XpAward({
    required this.profile,
    required this.xpGained,
    required this.before,
    required this.after,
  });

  /// Güncellenmiş profil.
  final UserProfile profile;

  /// Bu işlemde kazanılan XP.
  final int xpGained;

  /// Öncesi/sonrası seviye durumu.
  final LevelProgress before;
  final LevelProgress after;

  bool get leveledUp => after.level > before.level;

  int get levelsGained => after.level - before.level;

  /// Seviye atlandıysa yeni kuşak değişti mi? (rozet animasyonu için)
  bool get tierChanged => after.tier != before.tier;

  @override
  String toString() =>
      'XpAward(+$xpGained XP, Lv${before.level} → Lv${after.level})';
}

/// Karakter profili — oyunun tek gerçeği (single source of truth).
///
/// Seviye, XP ve radar değerleri **saklanmaz**, türetilir: [totalXp] ve
/// [rpgStats] değiştiğinde [level] otomatik doğru sonucu verir. Böylece
/// "seviye ile XP tutarsız" hataları imkansız hale gelir.
final class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.archetype,
    required this.createdAt,
    this.focusStats = const <StatKey>{},
    this.energyMode = EnergyMode.balanced,
    this.totalXp = 0,
    this.rpgStats = RpgStats.initial,
    this.streak = Streak.empty,
    this.xpLog = DailyXpLog.empty,
    this.dailyQuestTarget = defaultDailyQuestTarget,
    this.remindersEnabled = true,
    this.onboardingCompleted = false,
    this.lastActiveAt,
    this.avatarSeed = 0,
  });

  /// Günlük hedef görev sayısı (onboarding'de seçilir).
  static const int defaultDailyQuestTarget = 3;

  /// Kabul edilen aralık — 1 görev "çok az", 8+ görev "boğucu".
  static const int minDailyQuestTarget = 1;
  static const int maxDailyQuestTarget = 8;

  final String id;
  final String displayName;
  final LifeRole role;
  final Archetype archetype;
  final DateTime createdAt;

  /// Onboarding'de seçilen odak alanları (görev sıralamasını etkiler).
  final Set<StatKey> focusStats;

  final EnergyMode energyMode;

  /// Kümülatif XP — seviyenin tek girdisi.
  final int totalXp;

  /// Stat bazlı XP dağılımı.
  final RpgStats rpgStats;

  final Streak streak;

  /// Günlük XP geçmişi — İlerleme sekmesinin grafiği ve takvimi buradan beslenir.
  final DailyXpLog xpLog;

  final int dailyQuestTarget;
  final bool remindersEnabled;
  final bool onboardingCompleted;

  /// Son aktiflik zamanı (davet/geri kazanım bildirimleri için).
  final DateTime? lastActiveAt;

  /// Deterministik avatar üretimi için tohum.
  final int avatarSeed;

  // ── Türetilmiş değerler ──────────────────────────────────────────────────

  /// Seviye ilerlemesi (yüzde, kalan XP, kuşak).
  LevelProgress get level => XpEngine.progressForTotalXp(totalXp);

  int get levelNumber => level.level;

  RankTier get tier => level.tier;

  /// Kart üzerinde görünen "Çaylak Bilgin" tarzı unvan.
  String get titleLabel => '${tier.label} ${archetype.label}';

  String get firstName {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Gezgin';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  bool get isNewPlayer => totalXp == 0 && streak.totalActiveDays == 0;

  bool get needsOnboarding => !onboardingCompleted;

  /// Bugün görev yapıldı mı? (seri göstergesi için)
  bool isActiveOn(DateTime day) => streak.isCompletedOn(day);

  /// Seri risk altındaysa UI kırmızı uyarı gösterir.
  bool isStreakAtRisk(DateTime now) => streak.isAtRiskOn(now);

  /// 0.0 → 1.0 arası "ivme" sinyali: seri ağırlıklı, seviye hafif.
  double get momentum {
    final double streakPart = (streak.currentDays / 30).clamp(0.0, 1.0);
    final double levelPart = level.fraction.clamp(0.0, 1.0);
    return (streakPart * 0.7 + levelPart * 0.3).clamp(0.0, 1.0);
  }

  /// Yeni hesap oluşturur (onboarding öncesi).
  factory UserProfile.starter({
    required String id,
    required String displayName,
    LifeRole role = LifeRole.student,
    Set<StatKey> focusStats = const <StatKey>{},
    Archetype? archetype,
    DateTime? createdAt,
  }) {
    final DateTime now = createdAt ?? DateTime.now();
    final String name = displayName.trim();
    return UserProfile(
      id: id,
      displayName: name.isEmpty ? 'Gezgin' : name,
      role: role,
      archetype: archetype ?? Archetype.recommend(focusStats),
      focusStats: focusStats,
      createdAt: now,
      lastActiveAt: now,
    );
  }

  UserProfile withEnergyMode(EnergyMode mode) =>
      energyMode == mode ? this : copyWith(energyMode: mode);

  UserProfile withFocusStats(Set<StatKey> stats) => copyWith(
        focusStats: stats,
        archetype: Archetype.recommend(stats),
      );

  UserProfile completeOnboarding({
    required LifeRole role,
    required Set<StatKey> focusStats,
    Archetype? archetype,
    int? dailyQuestTarget,
  }) =>
      copyWith(
        role: role,
        focusStats: focusStats,
        archetype: archetype ?? Archetype.recommend(focusStats),
        dailyQuestTarget: dailyQuestTarget,
        onboardingCompleted: true,
      );

  UserProfile copyWith({
    String? displayName,
    LifeRole? role,
    Archetype? archetype,
    Set<StatKey>? focusStats,
    EnergyMode? energyMode,
    int? totalXp,
    RpgStats? rpgStats,
    Streak? streak,
    DailyXpLog? xpLog,
    int? dailyQuestTarget,
    bool? remindersEnabled,
    bool? onboardingCompleted,
    DateTime? lastActiveAt,
    int? avatarSeed,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      archetype: archetype ?? this.archetype,
      createdAt: createdAt,
      focusStats: focusStats ?? this.focusStats,
      energyMode: energyMode ?? this.energyMode,
      totalXp: totalXp ?? this.totalXp,
      rpgStats: rpgStats ?? this.rpgStats,
      streak: streak ?? this.streak,
      xpLog: xpLog ?? this.xpLog,
      dailyQuestTarget: dailyQuestTarget ?? this.dailyQuestTarget,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  // ── Oyun döngüsü ─────────────────────────────────────────────────────────

  /// Görev tamamlandığında XP'yi, stat dağılımını ve seriyi tek hamlede günceller.
  ///
  /// Dönüş değeri seviye atlama kutlaması için önce/sonra bilgisini taşır;
  /// UI sadece `award.leveledUp` kontrolü yapar.
  XpAward completeQuest({
    required StatKey stat,
    required int xp,
    required DateTime at,
  }) {
    final int safeXp = math.max(0, xp);
    final LevelProgress before = level;
    final UserProfile next = copyWith(
      totalXp: totalXp + safeXp,
      rpgStats: rpgStats.recordQuest(stat, safeXp),
      streak: streak.registerActivity(at),
      xpLog: xpLog.record(at: at, xp: safeXp),
      lastActiveAt: at,
    );
    return XpAward(
      profile: next,
      xpGained: safeXp,
      before: before,
      after: next.level,
    );
  }

  /// Kaçırılan günü seri dondurma hakkıyla kapatır.
  UserProfile useStreakFreeze(DateTime now) =>
      copyWith(streak: streak.freezeMissedDay(now));

  /// Ödül olarak dondurma hakkı ekler (üst sınır 3 hak).
  UserProfile grantFreezeToken([int amount = 1]) =>
      copyWith(streak: streak.addFreezeTokens(amount));

  // ── Serileştirme ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
        'role': role.code,
        'archetype': archetype.code,
        'created_at': createdAt.toIso8601String(),
        'focus_stats': <String>[for (final StatKey stat in focusStats) stat.code],
        'energy_mode': energyMode.code,
        'total_xp': totalXp,
        'rpg_stats': rpgStats.toJson(),
        'streak': streak.toJson(),
        'xp_log': xpLog.toJson(),
        'daily_quest_target': dailyQuestTarget,
        'reminders_enabled': remindersEnabled,
        'onboarding_completed': onboardingCompleted,
        'last_active_at': lastActiveAt?.toIso8601String(),
        'avatar_seed': avatarSeed,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: JsonX.asString(json['id']),
        displayName: JsonX.asString(json['display_name'], fallback: 'Gezgin'),
        role: LifeRole.fromCode(JsonX.asString(json['role'])),
        archetype: Archetype.fromCode(JsonX.asString(json['archetype'])),
        createdAt: JsonX.asDate(json['created_at']) ?? DateTime.now(),
        focusStats: _parseFocusStats(json['focus_stats']),
        energyMode: EnergyMode.fromCode(JsonX.asString(json['energy_mode'])),
        totalXp: JsonX.asInt(json['total_xp']),
        rpgStats: RpgStats.fromJson(JsonX.asMap(json['rpg_stats'])),
        streak: Streak.fromJson(JsonX.asMap(json['streak'])),
        xpLog: DailyXpLog.fromJson(JsonX.asMap(json['xp_log'])),
        dailyQuestTarget: JsonX
            .asInt(
              json['daily_quest_target'],
              fallback: defaultDailyQuestTarget,
            )
            .clamp(minDailyQuestTarget, maxDailyQuestTarget),
        remindersEnabled: JsonX.asBool(json['reminders_enabled'], fallback: true),
        onboardingCompleted: JsonX.asBool(json['onboarding_completed']),
        lastActiveAt: JsonX.asDate(json['last_active_at']),
        avatarSeed: JsonX.asInt(json['avatar_seed']),
      );

  static Set<StatKey> _parseFocusStats(Object? raw) {
    final Set<StatKey> result = <StatKey>{};
    for (final String code in JsonX.asStringList(raw)) {
      final StatKey? stat = StatKey.tryFromCode(code);
      if (stat != null) result.add(stat);
    }
    return result;
  }

  static bool _sameStats(Set<StatKey> a, Set<StatKey> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.role == role &&
      other.archetype == archetype &&
      other.createdAt == createdAt &&
      _sameStats(other.focusStats, focusStats) &&
      other.energyMode == energyMode &&
      other.totalXp == totalXp &&
      other.rpgStats == rpgStats &&
      other.streak == streak &&
      other.xpLog == xpLog &&
      other.dailyQuestTarget == dailyQuestTarget &&
      other.remindersEnabled == remindersEnabled &&
      other.onboardingCompleted == onboardingCompleted &&
      other.lastActiveAt == lastActiveAt &&
      other.avatarSeed == avatarSeed;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        role,
        archetype,
        createdAt,
        Object.hashAllUnordered(focusStats),
        energyMode,
        totalXp,
        rpgStats,
        streak,
        xpLog,
        dailyQuestTarget,
        remindersEnabled,
        onboardingCompleted,
        lastActiveAt,
        avatarSeed,
      );

  @override
  String toString() => 'UserProfile($displayName · Lv$levelNumber · '
      '$titleLabel · $totalXp XP · ${streak.currentDays} gün seri)';
}

