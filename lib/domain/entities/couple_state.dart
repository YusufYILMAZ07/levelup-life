import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';
import 'chat_message.dart';
import 'partner_data.dart';
import 'stat_key.dart';
import 'weekly_schedule.dart';

/// Üst bardaki "canlı durum" seçenekleri.
enum LiveStatus {
  coding(code: 'coding', emoji: '💻', label: 'Kod & Ders Odakta'),
  academic(code: 'academic', emoji: '🌸', label: 'Akademik & Gelişim Odakta'),
  studying(code: 'studying', emoji: '📚', label: 'Ders Çalışıyor'),
  gym(code: 'gym', emoji: '🏋️', label: 'Sporda'),
  coffee(code: 'coffee', emoji: '☕', label: 'Kahve Molasında'),
  deepFocus(code: 'deep_focus', emoji: '🎧', label: 'Derin Odakta'),
  resting(code: 'resting', emoji: '💤', label: 'Dinleniyor');

  const LiveStatus({
    required this.code,
    required this.emoji,
    required this.label,
  });

  final String code;
  final String emoji;
  final String label;

  /// "💻 Kod & Ders Odakta" — pill metni.
  String get fullLabel => '$emoji $label';

  /// Seçicide gösterilecek sıra.
  static const List<LiveStatus> picker = <LiveStatus>[
    LiveStatus.studying,
    LiveStatus.gym,
    LiveStatus.coffee,
    LiveStatus.deepFocus,
    LiveStatus.resting,
    LiveStatus.coding,
    LiveStatus.academic,
  ];

  static LiveStatus fromCode(String? code) {
    for (final LiveStatus status in values) {
      if (status.code == code || status.name == code) return status;
    }
    return LiveStatus.studying;
  }
}

/// Haftanın kazananı için seçilen ödül (bahis).
enum DuelStake {
  coffee(
    code: 'coffee',
    emoji: '☕',
    label: 'Kahve & Tatlı Ismarlama',
    detail: 'Haftanın kazananı, kaybedene kahve ve tatlı ısmarlar.',
  ),
  massage(
    code: 'massage',
    emoji: '💆',
    label: '30 Dakika Masaj Hakkı',
    detail: 'Kaybeden, kazanan 30 dakika masaj yapar.',
  ),
  movie(
    code: 'movie',
    emoji: '🎬',
    label: 'Hafta Sonu Film Seçimi',
    detail: 'Hafta sonu filmi kazanan seçer — itiraz yok.',
  ),
  dinner(
    code: 'dinner',
    emoji: '🍕',
    label: 'Özel Akşam Yemeği Sözü',
    detail: 'Kazanan için özel bir akşam yemeği hazırlanır.',
  );

  const DuelStake({
    required this.code,
    required this.emoji,
    required this.label,
    required this.detail,
  });

  final String code;
  final String emoji;
  final String label;
  final String detail;

  static DuelStake fromCode(String? code) {
    for (final DuelStake stake in values) {
      if (stake.code == code || stake.name == code) return stake;
    }
    return DuelStake.coffee;
  }
}

/// Gelişim sekmesindeki tek dokunuşluk bonus eylemler.
enum QuickAction {
  pomodoro(
    code: 'pomodoro',
    emoji: '⏱️',
    label: '+1 Pomodoro (25 dk) Odaklandım',
    points: 20,
    stat: StatKey.intelligence,
  ),
  water(
    code: 'water',
    emoji: '💧',
    label: '2.5L Su Hedefini Tamamladım',
    points: 15,
    stat: StatKey.vitality,
  ),
  reading(
    code: 'reading',
    emoji: '📖',
    label: '20 Sayfa Kitap / Makale Okudum',
    points: 20,
    stat: StatKey.productivity,
  ),
  steps(
    code: 'steps',
    emoji: '🚶',
    label: '10.000 Adım / Antrenman Yaptım',
    points: 25,
    stat: StatKey.strength,
  ),
  cleanFood(
    code: 'clean_food',
    emoji: '🥗',
    label: 'Paketli Gıda / Şeker Tüketmedim',
    points: 20,
    stat: StatKey.vitality,
  ),
  english(
    code: 'english',
    emoji: '🇬🇧',
    label: '10 Yeni İngilizce Kelime Öğrendim',
    points: 20,
    stat: StatKey.intelligence,
  );

  const QuickAction({
    required this.code,
    required this.emoji,
    required this.label,
    required this.points,
    required this.stat,
  });

  final String code;
  final String emoji;
  final String label;

  /// Anında kazanılan gelişim puanı (= XP).
  final int points;

  /// Bu eylemin beslediği stat.
  final StatKey stat;
}

/// 1-2-3 rubriğinin tek bir yaşam alanı tanımı.
final class PillarDefinition {
  const PillarDefinition({
    required this.stat,
    required this.title,
    required this.emoji,
    required this.hint,
    required this.level1,
    required this.level2,
    required this.level3,
  });

  final StatKey stat;
  final String title;
  final String emoji;
  final String hint;

  /// 1 puan (minimum altı), 2 puan (hedef tamam), 3 puan (ustalık).
  final String level1;
  final String level2;
  final String level3;

  String criteriaFor(int score) => switch (score) {
    1 => level1,
    2 => level2,
    _ => level3,
  };
}

/// Gelişim sekmesinin omurgası: 5 yaşam alanı × 1-2-3 puan.
abstract final class DevelopmentRubric {
  static const int maxScore = 3;
  static const int pillarCount = 5;

  /// Puan → XP eşlemesi (1: minimum altı, 2: hedef, 3: ustalık).
  static const Map<int, int> xpByScore = <int, int>{1: 10, 2: 25, 3: 45};

  static int xpFor(int score) => xpByScore[score.clamp(1, maxScore)] ?? 10;

  static const List<PillarDefinition> pillars = <PillarDefinition>[
    PillarDefinition(
      stat: StatKey.intelligence,
      title: 'Akademik & Derin Odak',
      emoji: '📚',
      hint: 'Ders, sınav ve kesintisiz odak seansları.',
      level1: '10 dk bile olsa masaya oturdum',
      level2: 'Planlanan dersi / çalışmayı bitirdim',
      level3: 'Ekstra soru çözdüm, anlatarak pekiştirdim',
    ),
    PillarDefinition(
      stat: StatKey.productivity,
      title: 'Gelişim & Dil / Okuma',
      emoji: '📖',
      hint: 'Okuma, yeni kelime, kurs ve üretim.',
      level1: '5 sayfa okudum / 3 kelime öğrendim',
      level2: '20 sayfa okudum / 10 kelime öğrendim',
      level3: 'Not aldım, paylaştım veya uyguladım',
    ),
    PillarDefinition(
      stat: StatKey.strength,
      title: 'Spor & Aktif Hareket',
      emoji: '🏋️',
      hint: 'Antrenman, yürüyüş ve hareket.',
      level1: '10 dk yürüdüm / esneme yaptım',
      level2: '30 dk antrenman veya 8.000 adım',
      level3: 'Planlı antrenmanı bitirdim, rekor denedim',
    ),
    PillarDefinition(
      stat: StatKey.vitality,
      title: 'Sağlıklı Beslenme & Su',
      emoji: '🥗',
      hint: 'Su, öğün düzeni ve temiz beslenme.',
      level1: '1.5L su içtim, abur cuburu azalttım',
      level2: '2.5L su + 3 dengeli öğün',
      level3: 'Şekersiz gün + evde sağlıklı yemek',
    ),
    PillarDefinition(
      stat: StatKey.willpower,
      title: 'Uyku & Zihin Detoksu',
      emoji: '🌙',
      hint: 'Uyku saati, ekran detoksu ve dinlenme.',
      level1: 'Hedefe yakın saatte yattım',
      level2: '7+ saat uyudum, ekranı erken bıraktım',
      level3: 'Nefes/meditasyon + tam uyku düzeni',
    ),
  ];

  static PillarDefinition forStat(StatKey stat) => pillars.firstWhere(
    (PillarDefinition pillar) => pillar.stat == stat,
    orElse: () => pillars.first,
  );
}

/// Ortak "bucket list" hedefi — tamamlanınca iki tarafa da Co-Op XP gelir.
final class BucketGoal {
  const BucketGoal({
    required this.id,
    required this.title,
    required this.emoji,
    this.detail = '',
    this.rewardPoints = CoupleState.bucketBonusXp,
    this.isDone = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String emoji;
  final String detail;

  /// Tamamlandığında **her iki** partnere verilecek XP.
  final int rewardPoints;

  final bool isDone;
  final DateTime? completedAt;

  BucketGoal toggle(DateTime now) => BucketGoal(
    id: id,
    title: title,
    emoji: emoji,
    detail: detail,
    rewardPoints: rewardPoints,
    isDone: !isDone,
    completedAt: isDone ? null : now,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'emoji': emoji,
    'detail': detail,
    'reward_points': rewardPoints,
    'is_done': isDone,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory BucketGoal.fromJson(Map<String, dynamic> json) => BucketGoal(
    id: JsonX.asString(json['id']),
    title: JsonX.asString(json['title']),
    emoji: JsonX.asString(json['emoji'], fallback: '💖'),
    detail: JsonX.asString(json['detail']),
    rewardPoints: JsonX.asInt(
      json['reward_points'],
      fallback: CoupleState.bucketBonusXp,
    ),
    isDone: JsonX.asBool(json['is_done']),
    completedAt: JsonX.asDate(json['completed_at']),
  );

  @override
  String toString() =>
      'BucketGoal($emoji $title · ${isDone ? 'done' : 'open'})';
}

/// Doğum günü modülündeki "Aşk Notu Üretici" havuzu (Yusuf → Ceyda).
abstract final class LoveNotes {
  static const List<String> all = <String>[
    'Ceyda, senin gülüşün benim en hızlı seviye atlama yolum. 💖',
    'Bugün ne yaparsan yap, hatırla: ben senin en büyük hayranınım. 🌸',
    'Seninle sıradan bir gün bile favori günüm oluyor. ☕',
    'Psikoloji kitaplarını okurken gözlerindeki ışığa aşığım. 📚',
    'İyi günde de, final haftasında da, her sürümde seni seçiyorum. 💫',
    'Seninle hayat, oynadığım en güzel oyun. 🎮💕',
    'Bugünkü görevin: kendine benim kadar iyi davranmak. 💆',
    'Bir kahve molası kadar bile yokluğun uzun geliyor. ☕',
    'Seninle her hedef ulaşılabilir, her pazartesi yeniden başlanabilir. 🌱',
    'Kalbim senin adını her gün yeniden öğreniyor. ✨',
    'Ben senin yanında hem daha güçlü hem daha sakinim. 🌙',
    'Doğum günün kutlu olsun aşkım — bu yıl birlikte rekor kıracağız. 🎂',
  ];

  static const List<String> emojis = <String>['💖', '🌸', '💌', '✨'];
}

/// Gelişim sekmesinde tek dokunuşla kaydedilen puan hareketi.
final class BonusActionLog {
  const BonusActionLog({
    required this.id,
    required this.partnerId,
    required this.title,
    required this.emoji,
    required this.points,
    required this.stat,
    required this.at,
  });

  factory BonusActionLog.fromQuickAction({
    required QuickAction action,
    required String partnerId,
    required DateTime at,
  }) => BonusActionLog(
    id: 'quick-${at.microsecondsSinceEpoch}-${action.code}',
    partnerId: partnerId,
    title: action.label,
    emoji: action.emoji,
    points: action.points,
    stat: action.stat,
    at: at,
  );

  factory BonusActionLog.custom({
    required String title,
    required int points,
    required StatKey stat,
    required String partnerId,
    required DateTime at,
  }) => BonusActionLog(
    id: 'custom-${at.microsecondsSinceEpoch}',
    partnerId: partnerId,
    title: title.trim(),
    emoji: '⭐',
    points: points,
    stat: stat,
    at: at,
  );

  final String id;
  final String partnerId;
  final String title;
  final String emoji;
  final int points;
  final StatKey stat;
  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'partner_id': partnerId,
    'title': title,
    'emoji': emoji,
    'points': points,
    'stat': stat.code,
    'at': at.toIso8601String(),
  };

  factory BonusActionLog.fromJson(Map<String, dynamic> json) => BonusActionLog(
    id: JsonX.asString(json['id']),
    partnerId: JsonX.asString(
      json['partner_id'],
      fallback: CouplePartner.yusufId,
    ),
    title: JsonX.asString(json['title']),
    emoji: JsonX.asString(json['emoji'], fallback: '⭐'),
    points: JsonX.asInt(json['points']),
    stat:
        StatKey.tryFromCode(JsonX.asString(json['stat'])) ??
        StatKey.productivity,
    at: JsonX.asDate(json['at']) ?? DateTime.now(),
  );
}

/// Puanla açılan ödül kapsülü.
///
/// Çiftin **birleşik gelişim puanı** ([CoupleState.combinedPoints]) eşiği
/// geçtiğinde kilit açılır; kapsül açıldığında içindeki ödül mesajı gösterilir.
/// Kilit durumu saklanmaz, puandan türetilir → puan düşse bile kapsül "kapandı"
/// gibi görünmez, [isOpened] ise kalıcıdır.
final class RewardCapsule {
  const RewardCapsule({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.requiredPoints,
    this.rewardMessage = '',
    this.isOpened = false,
    this.openedAt,
    this.isCustom = false,
  });

  final String id;
  final String title;
  final String emoji;

  /// Kilitliyken gösterilen tanıtım cümlesi.
  final String description;

  /// Çiftin birleşik puan eşiği.
  final int requiredPoints;

  /// Kapsül açıldığında gösterilen sıcak mesaj.
  final String rewardMessage;

  final bool isOpened;
  final DateTime? openedAt;

  /// Yusuf & Ceyda'nın kendi eklediği kapsül mü?
  final bool isCustom;

  /// `'500 Puan Kapsülü'`
  String get thresholdLabel => '$requiredPoints Puan Kapsülü';

  /// Bu puanla kilit açıldı mı?
  bool isUnlockedFor(int points) => points >= requiredPoints;

  /// `0..1` ilerleme oranı (kilitliyken doluşan bar).
  double progressFor(int points) {
    if (requiredPoints <= 0) return 1;
    return (points / requiredPoints).clamp(0.0, 1.0);
  }

  /// Kilide kalan puan (`0` → açıldı).
  int remainingFor(int points) =>
      (requiredPoints - points).clamp(0, requiredPoints);

  RewardCapsule open(DateTime at) => copyWith(isOpened: true, openedAt: at);

  RewardCapsule copyWith({
    String? title,
    String? emoji,
    String? description,
    int? requiredPoints,
    String? rewardMessage,
    bool? isOpened,
    DateTime? openedAt,
    bool? isCustom,
  }) => RewardCapsule(
    id: id,
    title: title ?? this.title,
    emoji: emoji ?? this.emoji,
    description: description ?? this.description,
    requiredPoints: requiredPoints ?? this.requiredPoints,
    rewardMessage: rewardMessage ?? this.rewardMessage,
    isOpened: isOpened ?? this.isOpened,
    openedAt: openedAt ?? this.openedAt,
    isCustom: isCustom ?? this.isCustom,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'emoji': emoji,
    'description': description,
    'required_points': requiredPoints,
    'reward_message': rewardMessage,
    'is_opened': isOpened,
    'opened_at': openedAt?.toIso8601String(),
    'is_custom': isCustom,
  };

  factory RewardCapsule.fromJson(Map<String, dynamic> json) => RewardCapsule(
    id: JsonX.asString(json['id']),
    title: JsonX.asString(json['title']),
    emoji: JsonX.asString(json['emoji'], fallback: '🎁'),
    description: JsonX.asString(json['description']),
    requiredPoints: JsonX.asInt(json['required_points'], fallback: 250),
    rewardMessage: JsonX.asString(json['reward_message']),
    isOpened: JsonX.asBool(json['is_opened']),
    openedAt: JsonX.asDate(json['opened_at']),
    isCustom: JsonX.asBool(json['is_custom']),
  );

  /// İlk açılışta hazır gelen 5 kapsül (puan eşikleri artan sırada).
  static const List<RewardCapsule> starter = <RewardCapsule>[
    RewardCapsule(
      id: 'capsule-coffee',
      title: 'Kahve & Tatlı Molası Kapsülü',
      emoji: '☕',
      description:
          'Birlikte seçtiğimiz bir kafede telefonları kenara bırakıp '
          'kahve & tatlı keyfi!',
      requiredPoints: 250,
      rewardMessage:
          'Kapsülü açtın! Bu hafta bir kafe seçiyoruz: telefonlar çantada, '
          'kahve ve tatlı bizim ☕💖',
    ),
    RewardCapsule(
      id: 'capsule-massage',
      title: '30 Dakika Masaj & Dinlenme Kapsülü',
      emoji: '💆',
      description:
          'Yorucu bir okul ve spor haftasının sonunda 30 dakikalık özel '
          'masaj hakkı!',
      requiredPoints: 500,
      rewardMessage:
          '30 dakika masaj hakkı kazanıldı! Bu akşam sırt ve omuz '
          'gerginliği sıfırlanıyor 💆✨',
    ),
    RewardCapsule(
      id: 'capsule-movie',
      title: 'Film & Atıştırmalık Gecesi Kapsülü',
      emoji: '🎬',
      description: 'Filmi ve menüyü kazananın seçtiği özel sinema gecesi!',
      requiredPoints: 750,
      rewardMessage:
          'Film gecesi kapsülü açıldı! Menüyü seçen, filmi seçen — '
          'itiraz yok 🎬🍿',
    ),
    RewardCapsule(
      id: 'capsule-dinner',
      title: 'Özel Akşam Yemeği Randevusu',
      emoji: '🍕',
      description:
          'Haftanın yorgunluğunu sıfırlayan baş başa güzel bir akşam yemeği!',
      requiredPoints: 1000,
      rewardMessage:
          'Özel akşam yemeği randevusu kapsülü açıldı! En güzel kıyafetler, '
          'en güzel akşam 🍕🌙',
    ),
    RewardCapsule(
      id: 'capsule-birthday',
      title: 'Ceyda\'nın Büyük Doğum Günü Sürpriz Kapsülü',
      emoji: '🎂',
      description:
          'İyi ki doğdun sevgilim! Bu kapsülü açtığında özel doğum günü '
          'hediyen/sürprizin seni bekliyor ❤️',
      requiredPoints: 1500,
      rewardMessage:
          '🎂 İyi ki doğdun Ceyda! Bu kapsülün içinde planlanmış bir sürpriz '
          'gün var — hazır ol ❤️',
    ),
  ];

  @override
  String toString() =>
      'RewardCapsule($emoji $title · $requiredPoints puan · '
      '${isOpened ? 'açıldı' : 'kapalı'})';
}

/// İki kişilik sürümün **ortak** durumu.
///
/// Partner başına kişisel ilerleme `GameState.partners` içinde tutulur; bu
/// sınıf ise iki kişiyi bağlayan her şeyi taşır: canlı durumlar, günlük
/// gelişim rubriği, bonus eylemler, sinerji, sohbet, ortak bucket list ve
/// haftalık bahis. Tüm koleksiyonlar `const` varsayılana sahiptir; böylece
/// onboarding öncesi `const GameState()` bozulmadan çalışır.
final class CoupleState {
  const CoupleState({
    this.liveStatus = _defaultLiveStatus,
    this.bonusActions = const <BonusActionLog>[],
    this.rubricScores = const <String, int>{},
    this.questTally = const <String, int>{},
    this.synergyKeys = const <String>{},
    this.bucketGoals = const <BucketGoal>[],
    this.customLoveNotes = const <String>[],
    this.loveNoteCursor = 0,
    this.birthdayMessage = defaultBirthdayMessage,
    this.messages = const <ChatMessage>[],
    this.stake = DuelStake.coffee,
    this.scheduleBlocks = const <ScheduleBlock>[],
    this.rewardCapsules = const <RewardCapsule>[],
  });

  /// Yusuf'un Ceyda'ya doğum günü mektubu — modalden düzenlenebilir.
  static const String defaultBirthdayMessage =
      'Seninle hem hayatı paylaşmak hem de birlikte gelişip hedeflerimize '
      'koşmak en güzel macera. Yeni yaşında tüm hedeflerini birlikte '
      'gerçekleştirelim, iyi ki varsın sevgilim! ❤️';

  /// Bucket list maddesi tamamlandığında iki tarafa da verilen Co-Op XP.
  static const int bucketBonusXp = 50;

  /// Aynı gün aynı alanda iki taraf da 2+ puan alırsa verilen sinerji bonusu.
  static const int synergyBonusXp = 25;

  /// "Dürt" (nudge) ile partnerine hatırlatma gönderenin kazandığı XP.
  static const int nudgeXp = 10;

  static const Map<String, LiveStatus> _defaultLiveStatus =
      <String, LiveStatus>{
        CouplePartner.yusufId: LiveStatus.coding,
        CouplePartner.ceydaId: LiveStatus.academic,
      };

  /// partnerId → canlı durum.
  final Map<String, LiveStatus> liveStatus;

  final List<BonusActionLog> bonusActions;

  /// `gun|partner|STAT` → 1..3 rubrik puanı.
  final Map<String, int> rubricScores;

  /// `gun|partner` → tamamlanan görev sayısı (tutarlılık metriği).
  final Map<String, int> questTally;

  /// `gun|STAT` → sinerji bonusu alınmış alanlar.
  final Set<String> synergyKeys;

  final List<BucketGoal> bucketGoals;
  final List<String> customLoveNotes;
  final int loveNoteCursor;

  /// Yusuf'tan Ceyda'ya kişiselleştirilebilir doğum günü mektubu.
  final String birthdayMessage;

  /// Yusuf & Ceyda'nın haftalık plan blokları (iki partnerin tek listesi).
  final List<ScheduleBlock> scheduleBlocks;

  /// Puanla açılan ödül kapsülleri (artan eşik sırasıyla eklenir).
  final List<RewardCapsule> rewardCapsules;

  /// Sohbet kronolojik sırada (eskiden yeniye).
  final List<ChatMessage> messages;

  final DuelStake stake;

  // ── Anahtar yardımcıları ─────────────────────────────────────────────────

  static String dayKey(DateTime day) => DateX.isoDay(day);

  static String rubricKey(String partnerId, StatKey pillar, DateTime day) =>
      '${dayKey(day)}|$partnerId|${pillar.code}';

  static String tallyKey(String partnerId, DateTime day) =>
      '${dayKey(day)}|$partnerId';

  static String synergyKey(StatKey pillar, DateTime day) =>
      '${dayKey(day)}|${pillar.code}';

  // ── Okuma ────────────────────────────────────────────────────────────────

  LiveStatus liveStatusOf(String partnerId) =>
      liveStatus[partnerId] ??
      _defaultLiveStatus[partnerId] ??
      LiveStatus.studying;

  /// Kümülatif gelişim puanı: rubrik XP'si + bonus eylem puanları.
  ///
  /// Saklanmaz, türetilir → puan ile kayıt arasında tutarsızlık olamaz.
  int improvementPointsOf(String partnerId) {
    int total = 0;
    for (final MapEntry<String, int> entry in rubricScores.entries) {
      final List<String> parts = entry.key.split('|');
      if (parts.length == 3 && parts[1] == partnerId) {
        total += DevelopmentRubric.xpFor(entry.value);
      }
    }
    for (final BonusActionLog log in bonusActions) {
      if (log.partnerId == partnerId) total += log.points;
    }
    return total;
  }

  int rubricScore(String partnerId, StatKey pillar, DateTime day) =>
      rubricScores[rubricKey(partnerId, pillar, day)] ?? 0;

  bool hasRated(String partnerId, StatKey pillar, DateTime day) =>
      rubricScores.containsKey(rubricKey(partnerId, pillar, day));

  /// Günün rubrik puanı toplamı (0..15).
  int rubricTotalOn(String partnerId, DateTime day) =>
      DevelopmentRubric.pillars.fold<int>(
        0,
        (int sum, PillarDefinition pillar) =>
            sum + rubricScore(partnerId, pillar.stat, day),
      );

  /// Rubrikten gelen günlük XP.
  int rubricXpOn(String partnerId, DateTime day) =>
      DevelopmentRubric.pillars.fold<int>(
        0,
        (int sum, PillarDefinition pillar) =>
            sum +
            DevelopmentRubric.xpFor(rubricScore(partnerId, pillar.stat, day)),
      );

  List<BonusActionLog> actionsOn(String partnerId, DateTime day) => bonusActions
      .where(
        (BonusActionLog log) =>
            log.partnerId == partnerId && DateX.isSameDay(log.at, day),
      )
      .toList(growable: false);

  int bonusPointsOn(String partnerId, DateTime day) => actionsOn(
    partnerId,
    day,
  ).fold<int>(0, (int sum, BonusActionLog log) => sum + log.points);

  /// Gelişim sekmesinin "Bugünkü Gelişim Puanı" değeri.
  int pointsOn(String partnerId, DateTime day) =>
      rubricXpOn(partnerId, day) + bonusPointsOn(partnerId, day);

  int questsCompletedOn(String partnerId, DateTime day) =>
      questTally[tallyKey(partnerId, day)] ?? 0;

  // ── Haftalık plan ────────────────────────────────────────────────────────

  /// Partnerin gün içindeki blokları (saat sırasıyla).
  List<ScheduleBlock> blocksForDay(String partnerId, int weekday) =>
      SchedulePlanner.blocksForDay(scheduleBlocks, partnerId, weekday);

  /// İki partnerin de blokları — yan yana timeline için.
  List<ScheduleBlock> allBlocksForDay(int weekday) =>
      SchedulePlanner.allBlocksForDay(scheduleBlocks, weekday);

  /// Şu an devam eden blok (yoksa `null`).
  ScheduleBlock? currentBlockFor(String partnerId, DateTime now) =>
      SchedulePlanner.currentBlock(scheduleBlocks, partnerId, now);

  /// Sıradaki blok (bugün kalmadıysa haftanın sonraki günü).
  ScheduleBlock? nextBlockFor(String partnerId, DateTime now) =>
      SchedulePlanner.nextBlock(scheduleBlocks, partnerId, now);

  ScheduleBlock? blockById(String blockId) =>
      SchedulePlanner.blockById(scheduleBlocks, blockId);

  /// Ortak boşluklar — `['16:00 - 18:00', '20:30 - 23:00']`.
  List<String> sharedFreeWindowsForDay(int weekday) =>
      SchedulePlanner.sharedFreeWindows(
        scheduleBlocks,
        weekday,
      ).map((FreeWindow window) => window.label).toList(growable: false);

  /// Günün en uzun ortak boşluğu (dashboard pill'i).
  FreeWindow? longestSharedFreeWindowForDay(int weekday) =>
      SchedulePlanner.longestSharedFreeWindow(scheduleBlocks, weekday);

  CoupleState addScheduleBlock(ScheduleBlock block) =>
      copyWith(scheduleBlocks: <ScheduleBlock>[...scheduleBlocks, block]);

  CoupleState addScheduleBlocks(Iterable<ScheduleBlock> blocks) =>
      copyWith(scheduleBlocks: <ScheduleBlock>[...scheduleBlocks, ...blocks]);

  CoupleState removeScheduleBlock(String blockId) => copyWith(
    scheduleBlocks: scheduleBlocks
        .where((ScheduleBlock block) => block.id != blockId)
        .toList(growable: false),
  );

  /// Bloğun bugünkü "tamamlandı" işaretini açar/kapatır.
  CoupleState completeScheduleBlock(String blockId, DateTime day) => copyWith(
    scheduleBlocks: <ScheduleBlock>[
      for (final ScheduleBlock block in scheduleBlocks)
        if (block.id == blockId) block.toggleCompleted(day) else block,
    ],
  );

  // ── Ödül kapsülleri ──────────────────────────────────────────────────────

  /// Çiftin birleşik gelişim puanı (Yusuf + Ceyda rubrik/bonus puanları).
  int get combinedPoints => CouplePartner.ids.fold<int>(
    0,
    (int sum, String partnerId) => sum + improvementPointsOf(partnerId),
  );

  /// Eşiğe göre artan sırada kapsüller (UI her zaman bu sırayla çizer).
  List<RewardCapsule> get capsulesByThreshold =>
      <RewardCapsule>[...rewardCapsules]..sort(
        (RewardCapsule a, RewardCapsule b) =>
            a.requiredPoints.compareTo(b.requiredPoints),
      );

  RewardCapsule? capsuleById(String capsuleId) {
    for (final RewardCapsule capsule in rewardCapsules) {
      if (capsule.id == capsuleId) return capsule;
    }
    return null;
  }

  /// Puanı yeten kapsül sayısı (kilit açılmış).
  int get unlockedCapsuleCount => rewardCapsules
      .where((RewardCapsule capsule) => capsule.isUnlockedFor(combinedPoints))
      .length;

  /// Puanı yeten ilk kapsül (dashboard'daki "sıradaki ödül" ipucu).
  RewardCapsule? get nextUnlockedCapsule {
    for (final RewardCapsule capsule in capsulesByThreshold) {
      if (capsule.isUnlockedFor(combinedPoints) && !capsule.isOpened) {
        return capsule;
      }
    }
    return null;
  }

  /// Kapsülü açar; eşik dolmadıysa durum değişmez.
  CoupleState openCapsule(String capsuleId, {DateTime? now}) {
    final RewardCapsule? capsule = capsuleById(capsuleId);
    if (capsule == null || capsule.isOpened) return this;
    if (!capsule.isUnlockedFor(combinedPoints)) return this;
    return copyWith(
      rewardCapsules: <RewardCapsule>[
        for (final RewardCapsule item in rewardCapsules)
          if (item.id == capsuleId) item.open(now ?? DateTime.now()) else item,
      ],
    );
  }

  CoupleState addCapsule(RewardCapsule capsule) =>
      copyWith(rewardCapsules: <RewardCapsule>[...rewardCapsules, capsule]);

  bool hasSynergy(StatKey pillar, DateTime day) =>
      synergyKeys.contains(synergyKey(pillar, day));

  int synergyCountOn(DateTime day) => DevelopmentRubric.pillars
      .where((PillarDefinition pillar) => hasSynergy(pillar.stat, day))
      .length;

  /// Hiçbir partnerin rubriği yoksa gelişim henüz başlamamıştır.
  bool get hasAnyRating => rubricScores.isNotEmpty;

  List<String> get allLoveNotes => <String>[
    ...LoveNotes.all,
    ...customLoveNotes,
  ];

  /// Üreticinin sıradaki notu (imleç mod ile döner).
  String get currentLoveNote {
    final List<String> notes = allLoveNotes;
    if (notes.isEmpty) return '';
    return notes[loveNoteCursor.abs() % notes.length];
  }

  List<ChatMessage> get photoMessages => messages
      .where((ChatMessage message) => message.hasMedia)
      .toList(growable: false);

  /// Yalnızca fotoğraflar (plan kanıtı ve hazır anı kartları dahil).
  List<ChatMessage> get imageMessages => messages
      .where((ChatMessage message) => message.hasImage)
      .toList(growable: false);

  /// Yalnızca videolar.
  List<ChatMessage> get videoMessages => messages
      .where((ChatMessage message) => message.hasVideo)
      .toList(growable: false);

  int get likedPhotoCount =>
      photoMessages.where((ChatMessage message) => message.isLiked).length;

  ChatMessage? messageById(String id) {
    for (final ChatMessage message in messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  /// `readerId` dışındaki gönderenlerin mesajlarını okundu işaretler.
  CoupleState markMessagesRead({required String readerId}) {
    bool changed = false;
    final List<ChatMessage> next = <ChatMessage>[
      for (final ChatMessage message in messages)
        if (message.senderId != readerId && !message.isRead)
          () {
            changed = true;
            return message.markRead();
          }()
        else
          message,
    ];
    return changed ? copyWith(messages: next) : this;
  }

  CoupleState deleteMessage(String messageId) {
    final List<ChatMessage> next = messages
        .where((ChatMessage message) => message.id != messageId)
        .toList(growable: false);
    return next.length == messages.length ? this : copyWith(messages: next);
  }

  CoupleState upsertMessage(ChatMessage message) {
    bool found = false;
    final List<ChatMessage> next = <ChatMessage>[
      for (final ChatMessage item in messages)
        if (item.id == message.id)
          () {
            found = true;
            return message;
          }()
        else
          item,
    ];
    return found
        ? copyWith(messages: next)
        : copyWith(messages: <ChatMessage>[...messages, message]);
  }

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  // ── Kopyalama ────────────────────────────────────────────────────────────

  CoupleState copyWith({
    Map<String, LiveStatus>? liveStatus,
    List<BonusActionLog>? bonusActions,
    Map<String, int>? rubricScores,
    Map<String, int>? questTally,
    Set<String>? synergyKeys,
    List<BucketGoal>? bucketGoals,
    List<String>? customLoveNotes,
    int? loveNoteCursor,
    String? birthdayMessage,
    List<ChatMessage>? messages,
    DuelStake? stake,
    List<ScheduleBlock>? scheduleBlocks,
    List<RewardCapsule>? rewardCapsules,
  }) => CoupleState(
    liveStatus: liveStatus ?? this.liveStatus,
    bonusActions: bonusActions ?? this.bonusActions,
    rubricScores: rubricScores ?? this.rubricScores,
    questTally: questTally ?? this.questTally,
    synergyKeys: synergyKeys ?? this.synergyKeys,
    bucketGoals: bucketGoals ?? this.bucketGoals,
    customLoveNotes: customLoveNotes ?? this.customLoveNotes,
    loveNoteCursor: loveNoteCursor ?? this.loveNoteCursor,
    birthdayMessage: birthdayMessage ?? this.birthdayMessage,
    messages: messages ?? this.messages,
    stake: stake ?? this.stake,
    scheduleBlocks: scheduleBlocks ?? this.scheduleBlocks,
    rewardCapsules: rewardCapsules ?? this.rewardCapsules,
  );

  // ── Mutasyonlar (hepsi yeni örnek döner) ─────────────────────────────────

  CoupleState withLiveStatus(String partnerId, LiveStatus status) => copyWith(
    liveStatus: <String, LiveStatus>{...liveStatus, partnerId: status},
  );

  /// Rubrik puanı yazar; `score == 0` puanı siler (yanlış dokunuşu geri alır).
  CoupleState ratePillar({
    required String partnerId,
    required StatKey pillar,
    required int score,
    required DateTime day,
  }) {
    final Map<String, int> next = <String, int>{...rubricScores};
    final String key = rubricKey(partnerId, pillar, day);
    if (score <= 0) {
      next.remove(key);
    } else {
      next[key] = score.clamp(1, DevelopmentRubric.maxScore);
    }
    return copyWith(rubricScores: next);
  }

  CoupleState recordQuestCompletion({
    required String partnerId,
    required DateTime day,
    int count = 1,
  }) {
    final String key = tallyKey(partnerId, day);
    return copyWith(
      questTally: <String, int>{
        ...questTally,
        key: (questTally[key] ?? 0) + count,
      },
    );
  }

  CoupleState addBonusAction(BonusActionLog log) =>
      copyWith(bonusActions: <BonusActionLog>[...bonusActions, log]);

  CoupleState markSynergy({required StatKey pillar, required DateTime day}) =>
      copyWith(synergyKeys: <String>{...synergyKeys, synergyKey(pillar, day)});

  CoupleState toggleBucketGoal(String goalId, {DateTime? now}) => copyWith(
    bucketGoals: <BucketGoal>[
      for (final BucketGoal goal in bucketGoals)
        if (goal.id == goalId) goal.toggle(now ?? DateTime.now()) else goal,
    ],
  );

  CoupleState addLoveNote(String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) return this;
    return copyWith(
      customLoveNotes: <String>[...customLoveNotes, trimmed],
      loveNoteCursor: allLoveNotes.length,
    );
  }

  CoupleState cycleLoveNote() {
    final int total = allLoveNotes.length;
    if (total == 0) return this;
    return copyWith(loveNoteCursor: (loveNoteCursor + 1) % total);
  }

  /// Doğum günü mektubunu günceller (boş metin varsayılana döner).
  CoupleState withBirthdayMessage(String message) {
    final String trimmed = message.trim();
    final String next = trimmed.isEmpty ? defaultBirthdayMessage : trimmed;
    return next == birthdayMessage ? this : copyWith(birthdayMessage: next);
  }

  /// Yeni mesajı kronolojik sıraya ekler.
  ///
  /// Realtime gecikmesiyle eski zamanlı bir mesaj sonradan gelirse listenin
  /// başına yerleşir; böylece "daha eski mesajları yükle" sınırı ve sohbet
  /// sırası bozulmaz.
  CoupleState addMessage(ChatMessage message) {
    final List<ChatMessage> next = <ChatMessage>[...messages, message];
    if (messages.isNotEmpty &&
        messages.last.createdAt.isAfter(message.createdAt)) {
      next.sort((ChatMessage a, ChatMessage b) {
        final int byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    }
    return copyWith(messages: next);
  }

  CoupleState toggleMessageLike(String messageId) => copyWith(
    messages: <ChatMessage>[
      for (final ChatMessage message in messages)
        if (message.id == messageId) message.toggleLike() else message,
    ],
  );

  CoupleState withStake(DuelStake next) =>
      stake == next ? this : copyWith(stake: next);

  // ── Kalıcılık ────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
    'live_status': <String, String>{
      for (final MapEntry<String, LiveStatus> entry in liveStatus.entries)
        entry.key: entry.value.code,
    },
    'bonus_actions': <Map<String, dynamic>>[
      for (final BonusActionLog log in bonusActions) log.toJson(),
    ],
    'rubric_scores': rubricScores,
    'quest_tally': questTally,
    'synergy_keys': synergyKeys.toList(growable: false),
    'bucket_goals': <Map<String, dynamic>>[
      for (final BucketGoal goal in bucketGoals) goal.toJson(),
    ],
    'custom_love_notes': customLoveNotes,
    'love_note_cursor': loveNoteCursor,
    'birthday_message': birthdayMessage,
    'messages': <Map<String, dynamic>>[
      for (final ChatMessage message in messages) message.toJson(),
    ],
    'stake': stake.code,
    'schedule_blocks': <Map<String, dynamic>>[
      for (final ScheduleBlock block in scheduleBlocks) block.toJson(),
    ],
    'reward_capsules': <Map<String, dynamic>>[
      for (final RewardCapsule capsule in rewardCapsules) capsule.toJson(),
    ],
  };

  factory CoupleState.fromJson(Map<String, dynamic> json) {
    final Map<String, LiveStatus> statuses = <String, LiveStatus>{
      ..._defaultLiveStatus,
    };
    JsonX.asMap(json['live_status']).forEach((String key, dynamic value) {
      statuses[key] = LiveStatus.fromCode(value?.toString());
    });

    final Map<String, int> rubric = <String, int>{};
    JsonX.asMap(json['rubric_scores']).forEach((String key, dynamic value) {
      final int score = JsonX.asInt(value);
      if (score > 0) rubric[key] = score.clamp(1, DevelopmentRubric.maxScore);
    });

    final Map<String, int> tally = <String, int>{};
    JsonX.asMap(json['quest_tally']).forEach((String key, dynamic value) {
      tally[key] = JsonX.asInt(value);
    });

    final List<BonusActionLog> actions = <BonusActionLog>[];
    final Object? rawActions = json['bonus_actions'];
    if (rawActions is List) {
      for (final Object? item in rawActions) {
        if (item is Map) {
          actions.add(BonusActionLog.fromJson(JsonX.asMap(item)));
        }
      }
    }

    final List<BucketGoal> goals = <BucketGoal>[];
    final Object? rawGoals = json['bucket_goals'];
    if (rawGoals is List) {
      for (final Object? item in rawGoals) {
        if (item is Map) goals.add(BucketGoal.fromJson(JsonX.asMap(item)));
      }
    }

    final List<ChatMessage> messages = <ChatMessage>[];
    final Object? rawMessages = json['messages'];
    if (rawMessages is List) {
      for (final Object? item in rawMessages) {
        if (item is Map) messages.add(ChatMessage.fromJson(JsonX.asMap(item)));
      }
    }

    final Object? rawSchedule = json['schedule_blocks'];
    final List<ScheduleBlock> schedule = <ScheduleBlock>[];
    if (rawSchedule is List) {
      for (final Object? item in rawSchedule) {
        if (item is Map) {
          schedule.add(ScheduleBlock.fromJson(JsonX.asMap(item)));
        }
      }
    }

    final Object? rawCapsules = json['reward_capsules'];
    final List<RewardCapsule> capsules = <RewardCapsule>[];
    if (rawCapsules is List) {
      for (final Object? item in rawCapsules) {
        if (item is Map) {
          capsules.add(RewardCapsule.fromJson(JsonX.asMap(item)));
        }
      }
    }

    return CoupleState(
      liveStatus: statuses,
      bonusActions: actions,
      rubricScores: rubric,
      questTally: tally,
      synergyKeys: JsonX.asStringList(json['synergy_keys']).toSet(),
      bucketGoals: goals,
      customLoveNotes: JsonX.asStringList(json['custom_love_notes']),
      loveNoteCursor: JsonX.asInt(json['love_note_cursor']),
      birthdayMessage: JsonX.asString(
        json['birthday_message'],
        fallback: CoupleState.defaultBirthdayMessage,
      ),
      messages: messages,
      stake: DuelStake.fromCode(JsonX.asString(json['stake'])),
      scheduleBlocks: rawSchedule is List ? schedule : ScheduleSeed.week(),
      rewardCapsules: rawCapsules is List ? capsules : RewardCapsule.starter,
    );
  }

  /// İlk açılışta iki kişiyi de selamlayan sıcak başlangıç içeriği.
  factory CoupleState.demo({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return CoupleState(
      bucketGoals: const <BucketGoal>[
        BucketGoal(
          id: 'bucket-morning-coffee',
          emoji: '☕',
          title: 'Birlikte sabah kahvesi ve 1 saat kesintisiz okuma seansı',
          detail: 'Telefonlar ters, kahveler sıcak, sayfalar bizim.',
        ),
        BucketGoal(
          id: 'bucket-joint-300',
          emoji: '🏆',
          title: 'Haftalık 300 ortak gelişim puanına ulaşmak',
          detail: 'Rubrik + hızlı eylemler + görevler birlikte sayılır.',
        ),
        BucketGoal(
          id: 'bucket-new-place',
          emoji: '📸',
          title: 'Birlikte yeni bir yer keşfetmek ve fotoğraf çekinmek',
          detail: 'Galerimizde yeni bir anı karesi daha.',
        ),
        BucketGoal(
          id: 'bucket-cappadocia',
          emoji: '🎈',
          title: 'Kapadokya\'da balon turu',
          detail: 'Gün doğumunda birlikte izlemek.',
        ),
        BucketGoal(
          id: 'bucket-finals',
          emoji: '🎓',
          title: 'Final haftasını birlikte atlatmak',
          detail: 'Kahve, notlar ve sabır üçlüsü.',
        ),
        BucketGoal(
          id: 'bucket-recipe',
          emoji: '🍳',
          title: 'Birlikte yeni bir tarif denemek',
          detail: 'Sonuç ne olursa olsun gülmek garantili.',
        ),
        BucketGoal(
          id: 'bucket-5k',
          emoji: '🏃',
          title: 'Birlikte 5K koşusuna katılmak',
          detail: 'Antrenman planı Gelişim sekmesinde.',
        ),
        BucketGoal(
          id: 'bucket-book',
          emoji: '📚',
          title: 'Aynı kitabı okuyup tartışmak',
          detail: 'İki farklı bakış, tek kitap.',
        ),
        BucketGoal(
          id: 'bucket-sunrise',
          emoji: '🌅',
          title: 'Sahilde gün doğumuna yetişmek',
          detail: 'Erken kalkma serisi burada işe yarayacak.',
        ),
      ],
      messages: <ChatMessage>[
        ChatMessage(
          id: 'seed-1',
          senderId: CouplePartner.ceydaId,
          createdAt: at.subtract(const Duration(hours: 20)),
          text: 'Günaydın sevgilim ☀️ Bugün hangi dersle başlıyoruz?',
        ),
        ChatMessage(
          id: 'seed-2',
          senderId: CouplePartner.yusufId,
          createdAt: at.subtract(const Duration(hours: 19, minutes: 40)),
          text:
              'Günaydın aşkım! 💻 Önce 1 saat veri yapıları, sonra seninle kahve molası ☕',
        ),
        ChatMessage(
          id: 'seed-3',
          senderId: CouplePartner.ceydaId,
          createdAt: at.subtract(const Duration(hours: 5)),
          photoDataOrUrl: 'preset:study-desk',
          photoCaption:
              'Psikoloji notlarını bitirdim 📚 Seninle gurur duyuyorum!',
          kind: ChatMessageKind.photo,
        ),
        ChatMessage(
          id: 'seed-4',
          senderId: CouplePartner.yusufId,
          createdAt: at.subtract(const Duration(hours: 2)),
          text: 'Seninle her gün bir öncekinden daha güzel 💖',
          kind: ChatMessageKind.loveNote,
        ),
        ChatMessage(
          id: 'seed-5',
          senderId: CouplePartner.ceydaId,
          createdAt: at.subtract(const Duration(hours: 1, minutes: 20)),
          photoDataOrUrl: 'preset:gym',
          photoCaption: '🏋️ Spor kanıtı · 16:00 bitti, duş ve kahve ☕',
          questBadgeTitle: 'Sporda · Antrenman & Mobilite',
          kind: ChatMessageKind.proof,
        ),
      ],
      scheduleBlocks: ScheduleSeed.week(),
      rewardCapsules: RewardCapsule.starter,
    );
  }

  @override
  String toString() =>
      'CoupleState(${messages.length} mesaj · '
      '${bucketGoals.where((BucketGoal goal) => goal.isDone).length}/${bucketGoals.length} '
      'bucket · ${stake.label})';
}
