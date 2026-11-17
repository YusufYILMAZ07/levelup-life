import '../../core/utils/date_x.dart';
import '../../core/utils/json_x.dart';
import 'stat_key.dart';

/// Haftalık plandaki bir zaman bloğunun türü.
///
/// Her kategori hem görsel kimliği (emoji + kısa ad) hem de bloğu
/// tamamlayınca hangi [StatKey]'in besleneceğini taşır. Böylece plan ↔ XP
/// eşlemesi tek yerde durur; UI hiçbir yerde stat tahmini yapmaz.
enum ScheduleCategory {
  school(
    code: 'school',
    emoji: '🎓',
    label: 'Okul / Ders',
    shortLabel: 'Okulda',
    stat: StatKey.intelligence,
  ),
  workout(
    code: 'workout',
    emoji: '🏋️',
    label: 'Spor / Antrenman',
    shortLabel: 'Sporda',
    stat: StatKey.strength,
  ),
  study(
    code: 'study',
    emoji: '📚',
    label: 'Derin Çalışma',
    shortLabel: 'Çalışıyor',
    stat: StatKey.productivity,
  ),
  date(
    code: 'date',
    emoji: '💑',
    label: 'Birlikte / Randevu',
    shortLabel: 'Birlikte',
    stat: StatKey.willpower,
  ),
  chore(
    code: 'chore',
    emoji: '🏡',
    label: 'Günlük İşler',
    shortLabel: 'Günlük işlerde',
    stat: StatKey.productivity,
  ),
  rest(
    code: 'rest',
    emoji: '☕',
    label: 'Mola / Dinlenme',
    shortLabel: 'Dinleniyor',
    stat: StatKey.vitality,
  );

  const ScheduleCategory({
    required this.code,
    required this.emoji,
    required this.label,
    required this.shortLabel,
    required this.stat,
  });

  final String code;
  final String emoji;
  final String label;

  /// "Okulda", "Sporda"… — canlı karttaki kısa etiket.
  final String shortLabel;

  /// Blok tamamlanınca +25 XP kazanan stat.
  final StatKey stat;

  /// "🎓 Okul / Ders"
  String get fullLabel => '$emoji $label';

  /// Anı kartı / kanıt fotoğrafı için hazır gradient kart anahtarı.
  String get presetSource => switch (this) {
    ScheduleCategory.school => 'preset:campus',
    ScheduleCategory.workout => 'preset:gym',
    ScheduleCategory.study => 'preset:study-desk',
    ScheduleCategory.date => 'preset:picnic',
    ScheduleCategory.chore => 'preset:walk',
    ScheduleCategory.rest => 'preset:coffee',
  };

  /// Yeni plan ekleme sheet'indeki sıra.
  static const List<ScheduleCategory> picker = <ScheduleCategory>[
    ScheduleCategory.school,
    ScheduleCategory.workout,
    ScheduleCategory.study,
    ScheduleCategory.date,
    ScheduleCategory.chore,
    ScheduleCategory.rest,
  ];

  static ScheduleCategory fromCode(String? code) {
    for (final ScheduleCategory category in values) {
      if (category.code == code || category.name == code) return category;
    }
    return ScheduleCategory.study;
  }
}

/// Haftalık plandaki tek bir zaman bloğu (ders, antrenman, randevu…).
///
/// Saatler **gün başından itibaren dakika** olarak tutulur (`14:00 → 840`).
/// Bu sayede "şu an aktif mi?" ve "kaç dakika kaldı?" hesapları tarih/saat
/// dilimlerinden bağımsız, saf ve test edilebilir kalır.
final class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.partnerId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    required this.category,
    this.locationOrNote = '',
    this.completedDateKeys = const <String>{},
  });

  /// UI'dan yeni blok üretirken kullanılan kolay kurucu.
  factory ScheduleBlock.create({
    required String partnerId,
    required int weekday,
    required int startMinutes,
    required int endMinutes,
    required String title,
    required ScheduleCategory category,
    String locationOrNote = '',
    String? id,
    DateTime? now,
  }) {
    final int stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    final int safeWeekday = weekday.clamp(1, 7);
    final int safeStart = startMinutes.clamp(0, 24 * 60 - 1);
    final int safeEnd = endMinutes.clamp(1, 24 * 60);
    return ScheduleBlock(
      id:
          id ??
          'plan-$partnerId-$safeWeekday-$safeStart-$safeEnd-$stamp',
      partnerId: partnerId,
      weekday: safeWeekday,
      startMinutes: safeStart,
      endMinutes: safeEnd,
      title: title.trim(),
      category: category,
      locationOrNote: locationOrNote.trim(),
    );
  }

  static const List<String> weekdayShort = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static const List<String> weekdayLong = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  final String id;

  /// `yusuf` veya `ceyda`.
  final String partnerId;

  /// `1 = Pazartesi` … `7 = Pazar`.
  final int weekday;

  /// Gün başından itibaren dakika (`14:00 → 840`).
  final int startMinutes;
  final int endMinutes;

  final String title;
  final ScheduleCategory category;

  /// "Mühendislik Fak." / "Spor Salonu" gibi yer veya kısa not.
  final String locationOrNote;

  /// `'YYYY-MM-DD'` → bu blok o gün tamamlandı olarak işaretlendi.
  final Set<String> completedDateKeys;

  /// `840 → '14:00'`.
  static String clock(int minutes) {
    final int safe = minutes.clamp(0, 24 * 60);
    final String hh = (safe ~/ 60).toString().padLeft(2, '0');
    final String mm = (safe % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String get startLabel => clock(startMinutes);
  String get endLabel => clock(endMinutes);

  /// `'14:00 - 16:00'`
  String get timeRangeLabel => '$startLabel - $endLabel';

  /// `'Salı'`
  String get weekdayLabel => weekdayLong[weekday.clamp(1, 7) - 1];

  String get weekdayShortLabel => weekdayShort[weekday.clamp(1, 7) - 1];

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60);

  /// `'105 dk'` biçiminde süre.
  String get durationLabel => '$durationMinutes dk';

  /// "🎓 Okulda · Bilgisayar Müh. Dersi"
  String get displayTitle => '${category.emoji} $title';

  static int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

  /// Şu an bu blok aktif mi? (bitiş saati hariç: `[start, end)`)
  bool isActiveAt(DateTime now) {
    if (now.weekday != weekday) return false;
    final int minute = _minuteOfDay(now);
    return minute >= startMinutes && minute < endMinutes;
  }

  /// Aktifse geçen sürenin oranı (0..1), değilse 0.
  double progressAt(DateTime now) {
    if (!isActiveAt(now)) return 0;
    if (durationMinutes <= 0) return 1;
    final double elapsed = (_minuteOfDay(now) - startMinutes).toDouble();
    return (elapsed / durationMinutes).clamp(0.0, 1.0);
  }

  /// Bitişe kalan dakika (aktif değilse 0).
  int remainingMinutesAt(DateTime now) => isActiveAt(now)
      ? (endMinutes - _minuteOfDay(now)).clamp(0, durationMinutes)
      : 0;

  /// Blok henüz başlamadıysa kaç dakika kaldı (geçmişse 0).
  int minutesUntilStart(DateTime now) {
    if (now.weekday != weekday) return 0;
    return (startMinutes - _minuteOfDay(now)).clamp(0, 24 * 60);
  }

  bool isCompletedOn(DateTime day) =>
      completedDateKeys.contains(DateX.isoDay(day));

  /// Günü "tamamlandı" olarak işaretler (tekrar dokunursa geri alır).
  ScheduleBlock toggleCompleted(DateTime day) {
    final String key = DateX.isoDay(day);
    final Set<String> next = <String>{...completedDateKeys};
    if (!next.add(key)) next.remove(key);
    return copyWith(completedDateKeys: next);
  }

  ScheduleBlock copyWith({
    String? partnerId,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
    String? title,
    ScheduleCategory? category,
    String? locationOrNote,
    Set<String>? completedDateKeys,
  }) => ScheduleBlock(
    id: id,
    partnerId: partnerId ?? this.partnerId,
    weekday: weekday ?? this.weekday,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    title: title ?? this.title,
    category: category ?? this.category,
    locationOrNote: locationOrNote ?? this.locationOrNote,
    completedDateKeys: completedDateKeys ?? this.completedDateKeys,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'partner_id': partnerId,
    'weekday': weekday,
    'start_minutes': startMinutes,
    'end_minutes': endMinutes,
    'title': title,
    'category': category.code,
    'location_or_note': locationOrNote,
    'completed_date_keys': completedDateKeys.toList(growable: false),
  };

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) => ScheduleBlock(
    id: JsonX.asString(json['id']),
    partnerId: JsonX.asString(json['partner_id'], fallback: 'yusuf'),
    weekday: JsonX.asInt(json['weekday'], fallback: 1).clamp(1, 7),
    startMinutes: JsonX.asInt(json['start_minutes']).clamp(0, 24 * 60 - 1),
    endMinutes: JsonX.asInt(
      json['end_minutes'],
      fallback: 60,
    ).clamp(1, 24 * 60),
    title: JsonX.asString(json['title']),
    category: ScheduleCategory.fromCode(JsonX.asString(json['category'])),
    locationOrNote: JsonX.asString(json['location_or_note']),
    completedDateKeys: JsonX.asStringList(json['completed_date_keys']).toSet(),
  );

  @override
  String toString() =>
      'ScheduleBlock($partnerId · $weekdayShortLabel $timeRangeLabel · '
      '${category.emoji} $title)';
}

/// İki kişinin de boş olduğu zaman aralığı.
final class FreeWindow {
  const FreeWindow({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  /// `'16:00 - 18:00'`
  String get label =>
      '${ScheduleBlock.clock(startMinutes)} - ${ScheduleBlock.clock(endMinutes)}';

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60);

  String get durationLabel => '$durationMinutes dk';

  @override
  String toString() => 'FreeWindow($label)';
}

/// Haftalık plan üzerinde saf hesaplar: aktif blok, sıradaki blok, ortak
/// boşluklar. Hiçbir tarih/saat dilimi veya UI bağımlılığı yoktur → birim
/// testleriyle doğrudan doğrulanır.
abstract final class SchedulePlanner {
  /// Ortak boşluk taraması bu aralıkta yapılır (gün başı / sonu).
  static const int dayStartMinutes = 9 * 60;
  static const int dayEndMinutes = 23 * 60;

  /// Daha kısa boşluklar "ortak vakit" sayılmaz (gürültüyü engeller).
  static const int minFreeWindowMinutes = 45;

  /// Plan bloğu tamamlandığında kazanılan XP.
  static const int completionXp = 25;

  static int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

  static int _byStart(ScheduleBlock a, ScheduleBlock b) =>
      a.weekday == b.weekday
      ? a.startMinutes.compareTo(b.startMinutes)
      : a.weekday.compareTo(b.weekday);

  /// Partnerin seçilen gündeki blokları (başlangıca göre sıralı).
  static List<ScheduleBlock> blocksForDay(
    Iterable<ScheduleBlock> blocks,
    String partnerId,
    int weekday,
  ) {
    final List<ScheduleBlock> day = blocks
        .where(
          (ScheduleBlock block) =>
              block.partnerId == partnerId && block.weekday == weekday,
        )
        .toList();
    day.sort(_byStart);
    return List<ScheduleBlock>.unmodifiable(day);
  }

  /// İki partnerin de dahil olduğu günün tüm blokları (timeline için).
  static List<ScheduleBlock> allBlocksForDay(
    Iterable<ScheduleBlock> blocks,
    int weekday,
  ) {
    final List<ScheduleBlock> day = blocks
        .where((ScheduleBlock block) => block.weekday == weekday)
        .toList();
    day.sort(_byStart);
    return List<ScheduleBlock>.unmodifiable(day);
  }

  /// Şu an aktif olan blok (birden fazla varsa en erken başlayan).
  static ScheduleBlock? currentBlock(
    Iterable<ScheduleBlock> blocks,
    String partnerId,
    DateTime now,
  ) {
    ScheduleBlock? found;
    for (final ScheduleBlock block in blocks) {
      if (block.partnerId != partnerId || !block.isActiveAt(now)) continue;
      if (found == null || block.startMinutes < found.startMinutes) {
        found = block;
      }
    }
    return found;
  }

  /// Sıradaki blok: bugünün kalanları, yoksa haftanın bir sonraki günü.
  static ScheduleBlock? nextBlock(
    Iterable<ScheduleBlock> blocks,
    String partnerId,
    DateTime now,
  ) {
    final List<ScheduleBlock> mine =
        blocks
            .where((ScheduleBlock block) => block.partnerId == partnerId)
            .toList()
          ..sort(_byStart);
    if (mine.isEmpty) return null;

    final int minute = _minuteOfDay(now);
    for (final ScheduleBlock block in mine) {
      if (block.weekday == now.weekday && block.startMinutes > minute) {
        return block;
      }
    }
    for (int offset = 1; offset <= 7; offset++) {
      final int weekday = ((now.weekday - 1 + offset) % 7) + 1;
      for (final ScheduleBlock block in mine) {
        if (block.weekday == weekday) return block;
      }
    }
    return null;
  }

  static ScheduleBlock? blockById(
    Iterable<ScheduleBlock> blocks,
    String blockId,
  ) {
    for (final ScheduleBlock block in blocks) {
      if (block.id == blockId) return block;
    }
    return null;
  }

  /// İki partnerin de boş olduğu pencereler (`09:00 – 23:00` arası).
  static List<FreeWindow> sharedFreeWindows(
    Iterable<ScheduleBlock> blocks,
    int weekday,
  ) {
    final List<List<int>> busy = <List<int>>[];
    for (final ScheduleBlock block in blocks) {
      if (block.weekday != weekday) continue;
      final int start = block.startMinutes.clamp(
        dayStartMinutes,
        dayEndMinutes,
      );
      final int end = block.endMinutes.clamp(dayStartMinutes, dayEndMinutes);
      if (end > start) busy.add(<int>[start, end]);
    }
    busy.sort((List<int> a, List<int> b) => a[0].compareTo(b[0]));

    final List<List<int>> merged = <List<int>>[];
    for (final List<int> span in busy) {
      if (merged.isEmpty || span[0] > merged.last[1]) {
        merged.add(<int>[span[0], span[1]]);
        continue;
      }
      if (span[1] > merged.last[1]) merged.last[1] = span[1];
    }

    final List<FreeWindow> windows = <FreeWindow>[];
    int cursor = dayStartMinutes;
    for (final List<int> span in merged) {
      if (span[0] - cursor >= minFreeWindowMinutes) {
        windows.add(FreeWindow(startMinutes: cursor, endMinutes: span[0]));
      }
      cursor = span[1] > cursor ? span[1] : cursor;
    }
    if (dayEndMinutes - cursor >= minFreeWindowMinutes) {
      windows.add(FreeWindow(startMinutes: cursor, endMinutes: dayEndMinutes));
    }
    return List<FreeWindow>.unmodifiable(windows);
  }

  /// Günün en uzun ortak boşluğu (dashboard'daki pill için).
  static FreeWindow? longestSharedFreeWindow(
    Iterable<ScheduleBlock> blocks,
    int weekday,
  ) {
    FreeWindow? best;
    for (final FreeWindow window in sharedFreeWindows(blocks, weekday)) {
      if (best == null || window.durationMinutes > best.durationMinutes) {
        best = window;
      }
    }
    return best;
  }
}

/// Yusuf & Ceyda'nın gerçekçi haftalık planı (demo tohumu).
///
/// Her gün iki tarafta da sabah okul/çalışma, akşam odak ve hafta sonu ortak
/// bloklar vardır. Salı 14:00–16:00 bilinçli olarak "biri okulda, diğeri
/// sporda" senaryosudur — canlı kart bu durumu gösterir.
abstract final class ScheduleSeed {
  static int _t(int hour, [int minute = 0]) => hour * 60 + minute;

  static List<ScheduleBlock> week() => <ScheduleBlock>[
    ...yusufWeek,
    ...ceydaWeek,
  ];

  static ScheduleBlock _block(
    String partnerId,
    int weekday,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
    String title,
    ScheduleCategory category,
    String note,
  ) => ScheduleBlock(
    id: 'plan-$partnerId-$weekday-${_t(startHour, startMinute)}',
    partnerId: partnerId,
    weekday: weekday,
    startMinutes: _t(startHour, startMinute),
    endMinutes: _t(endHour, endMinute),
    title: title,
    category: category,
    locationOrNote: note,
  );

  static final List<ScheduleBlock> yusufWeek = <ScheduleBlock>[
    _block(
      'yusuf',
      1,
      9,
      0,
      11,
      0,
      'Okulda · Algoritma & Veri Yapıları',
      ScheduleCategory.school,
      'Mühendislik Fak.',
    ),
    _block(
      'yusuf',
      1,
      13,
      0,
      15,
      0,
      'Derin Çalışma · Proje Sprinti',
      ScheduleCategory.study,
      'Kütüphane',
    ),
    _block(
      'yusuf',
      1,
      18,
      0,
      19,
      30,
      'Sporda · Üst Vücut Antrenmanı',
      ScheduleCategory.workout,
      'Spor Salonu',
    ),

    _block(
      'yusuf',
      2,
      9,
      30,
      11,
      30,
      'Okulda · İşletim Sistemleri',
      ScheduleCategory.school,
      'Mühendislik Fak.',
    ),
    _block(
      'yusuf',
      2,
      14,
      0,
      16,
      0,
      'Okulda · Bilgisayar Müh. Dersi',
      ScheduleCategory.school,
      'Amfi 3',
    ),
    _block(
      'yusuf',
      2,
      19,
      0,
      20,
      30,
      'Derin Çalışma · Veri Yapıları Tekrarı',
      ScheduleCategory.study,
      'Kütüphane',
    ),

    _block(
      'yusuf',
      3,
      9,
      0,
      10,
      30,
      'Okulda · Olasılık & İstatistik',
      ScheduleCategory.school,
      'Mühendislik Fak.',
    ),
    _block(
      'yusuf',
      3,
      11,
      0,
      12,
      0,
      'Mola · Kampüs Kahvesi',
      ScheduleCategory.rest,
      'Kampüs',
    ),
    _block(
      'yusuf',
      3,
      14,
      0,
      16,
      0,
      'Derin Çalışma · Bitirme Projesi',
      ScheduleCategory.study,
      'Kütüphane',
    ),
    _block(
      'yusuf',
      3,
      18,
      30,
      20,
      0,
      'Sporda · Kardiyo & Mobilite',
      ScheduleCategory.workout,
      'Spor Salonu',
    ),

    _block(
      'yusuf',
      4,
      10,
      0,
      12,
      0,
      'Okulda · Yazılım Mühendisliği',
      ScheduleCategory.school,
      'Mühendislik Fak.',
    ),
    _block(
      'yusuf',
      4,
      13,
      30,
      15,
      30,
      'Derin Çalışma · Kod & Debug',
      ScheduleCategory.study,
      'Kütüphane',
    ),
    _block(
      'yusuf',
      4,
      19,
      30,
      21,
      0,
      'Akşam Odağı · Algoritma Soruları',
      ScheduleCategory.study,
      'Ev',
    ),

    _block(
      'yusuf',
      5,
      9,
      0,
      11,
      0,
      'Okulda · Veritabanı Sistemleri',
      ScheduleCategory.school,
      'Mühendislik Fak.',
    ),
    _block(
      'yusuf',
      5,
      16,
      0,
      17,
      0,
      'Günlük İşler · Oda & Çamaşır',
      ScheduleCategory.chore,
      'Ev',
    ),
    _block(
      'yusuf',
      5,
      20,
      30,
      23,
      0,
      'Birlikte · Film & Atıştırmalık Gecesi',
      ScheduleCategory.date,
      'Ev',
    ),

    _block(
      'yusuf',
      6,
      10,
      0,
      11,
      30,
      'Sporda · Uzun Koşu',
      ScheduleCategory.workout,
      'Sahil',
    ),
    _block(
      'yusuf',
      6,
      13,
      0,
      14,
      0,
      'Günlük İşler · Haftalık Alışveriş',
      ScheduleCategory.chore,
      'Market',
    ),
    _block(
      'yusuf',
      6,
      16,
      0,
      18,
      0,
      'Birlikte · Kahve & Sahil Yürüyüşü',
      ScheduleCategory.date,
      'Sahil',
    ),

    _block(
      'yusuf',
      7,
      11,
      0,
      12,
      0,
      'Mola · Geç Kahvaltı',
      ScheduleCategory.rest,
      'Ev',
    ),
    _block(
      'yusuf',
      7,
      14,
      0,
      16,
      0,
      'Derin Çalışma · Haftalık Planlama',
      ScheduleCategory.study,
      'Ev',
    ),
    _block(
      'yusuf',
      7,
      20,
      30,
      22,
      0,
      'Birlikte · Hafta Planı & Film',
      ScheduleCategory.date,
      'Ev',
    ),
  ];

  static final List<ScheduleBlock> ceydaWeek = <ScheduleBlock>[
    _block(
      'ceyda',
      1,
      9,
      0,
      11,
      0,
      'Okulda · Psikolojiye Giriş',
      ScheduleCategory.school,
      'Fen-Edebiyat',
    ),
    _block(
      'ceyda',
      1,
      13,
      0,
      14,
      30,
      'Derin Çalışma · Psikoloji Notları',
      ScheduleCategory.study,
      'Kütüphane',
    ),
    _block(
      'ceyda',
      1,
      18,
      0,
      19,
      0,
      'Mola · Yoga & Esneme',
      ScheduleCategory.rest,
      'Ev',
    ),

    _block(
      'ceyda',
      2,
      10,
      0,
      11,
      30,
      'Okulda · Gelişim Psikolojisi',
      ScheduleCategory.school,
      'Fen-Edebiyat',
    ),
    _block(
      'ceyda',
      2,
      14,
      0,
      16,
      0,
      'Sporda · Antrenman & Mobilite',
      ScheduleCategory.workout,
      'Spor Salonu',
    ),
    _block(
      'ceyda',
      2,
      19,
      0,
      20,
      30,
      'Derin Çalışma · Makale Okuma',
      ScheduleCategory.study,
      'Ev',
    ),

    _block(
      'ceyda',
      3,
      9,
      30,
      11,
      0,
      'Derin Çalışma · İstatistik Tekrarı',
      ScheduleCategory.study,
      'Kütüphane',
    ),
    _block(
      'ceyda',
      3,
      13,
      0,
      15,
      0,
      'Okulda · Sosyal Psikoloji',
      ScheduleCategory.school,
      'Fen-Edebiyat',
    ),
    _block(
      'ceyda',
      3,
      18,
      30,
      19,
      30,
      'Sporda · Pilates & Kardiyo',
      ScheduleCategory.workout,
      'Stüdyo',
    ),

    _block(
      'ceyda',
      4,
      10,
      0,
      12,
      0,
      'Okulda · Klinik Psikoloji',
      ScheduleCategory.school,
      'Fen-Edebiyat',
    ),
    _block(
      'ceyda',
      4,
      13,
      0,
      14,
      0,
      'Mola · Kahve & Kitap',
      ScheduleCategory.rest,
      'Kafe',
    ),
    _block(
      'ceyda',
      4,
      15,
      0,
      17,
      0,
      'Derin Çalışma · Sunum Hazırlığı',
      ScheduleCategory.study,
      'Kütüphane',
    ),

    _block(
      'ceyda',
      5,
      9,
      0,
      11,
      0,
      'Okulda · Araştırma Yöntemleri',
      ScheduleCategory.school,
      'Fen-Edebiyat',
    ),
    _block(
      'ceyda',
      5,
      16,
      0,
      17,
      30,
      'Günlük İşler · Mutfak & Düzen',
      ScheduleCategory.chore,
      'Ev',
    ),
    _block(
      'ceyda',
      5,
      20,
      30,
      23,
      0,
      'Birlikte · Film & Atıştırmalık Gecesi',
      ScheduleCategory.date,
      'Ev',
    ),

    _block(
      'ceyda',
      6,
      11,
      0,
      12,
      30,
      'Sporda · Pilates Stüdyosu',
      ScheduleCategory.workout,
      'Stüdyo',
    ),
    _block(
      'ceyda',
      6,
      15,
      0,
      15,
      45,
      'Mola · Kitap & Kahve',
      ScheduleCategory.rest,
      'Kafe',
    ),
    _block(
      'ceyda',
      6,
      16,
      0,
      18,
      0,
      'Birlikte · Kahve & Sahil Yürüyüşü',
      ScheduleCategory.date,
      'Sahil',
    ),

    _block(
      'ceyda',
      7,
      10,
      30,
      12,
      0,
      'Derin Çalışma · Haftalık Özet',
      ScheduleCategory.study,
      'Ev',
    ),
    _block(
      'ceyda',
      7,
      14,
      0,
      15,
      30,
      'Mola · Aile Ziyareti',
      ScheduleCategory.rest,
      'Aile',
    ),
    _block(
      'ceyda',
      7,
      20,
      30,
      22,
      0,
      'Birlikte · Hafta Planı & Film',
      ScheduleCategory.date,
      'Ev',
    ),
  ];
}
