import 'dart:math' as math;

import '../entities/entities.dart';
import 'xp_engine.dart';

/// Kullanıcının onboarding cevaplarına göre **kişiselleştirilmiş** görev üretir.
///
/// Rastgelelik yoktur:
/// * Şablonlar seçilen hedeflere göre filtrelenir (spor seçmeyen kullanıcı
///   antrenman görevi görmez).
/// * Süre bütçesi günlük tempoya göre hesaplanır (15 dk → kısa görevler).
/// * Liste güne göre deterministik olarak döndürülür: aynı gün aynı görevler,
///   ertesi gün taze bir liste.
/// * Her seçilen hedef için en az bir görev garanti edilir.
abstract final class QuestGenerator {
  /// Kullanıcıya özel günlük görev listesi.
  static List<Quest> dailyQuests({
    required UserSetup setup,
    required DateTime now,
    EnergyMode energyMode = EnergyMode.balanced,
    int? count,
  }) {
    final int target = count ?? setup.dailyQuestTarget;
    final double tempoFactor = setup.isProfessional
        ? setup.workload.tempoFactor
        : 1.0;
    final int budget = (setup.tempo.minutes * tempoFactor).round();

    final List<_QuestTemplate> pool = _templates
        .where(
          (_QuestTemplate t) => t.goal == null || setup.goals.contains(t.goal),
        )
        .toList(growable: false);
    final List<_QuestTemplate> affordable = pool
        .where((_QuestTemplate t) => t.minutes <= budget + 15)
        .toList(growable: false);
    final List<_QuestTemplate> source = affordable.length >= target
        ? affordable
        : pool;

    final List<_QuestTemplate> ordered = _rotate(source, _dayIndex(now));
    final List<_QuestTemplate> picked = <_QuestTemplate>[];
    final Set<String> usedIds = <String>{};

    // 1) Her seçilen hedef için bir görev (kapsama garantisi).
    for (final GoalType goal in setup.goals) {
      final _QuestTemplate? template = _firstWhere(
        ordered,
        (_QuestTemplate t) => t.goal == goal,
      );
      if (template != null && usedIds.add(template.id)) {
        picked.add(template);
      }
    }

    // 2) Kalan slotları günlük sırayla doldur (stat çeşitliliği korunur).
    for (final _QuestTemplate template in ordered) {
      if (picked.length >= target) break;
      if (!usedIds.add(template.id)) continue;
      picked.add(template);
    }

    return <Quest>[
      for (final _QuestTemplate template in picked.take(target))
        _build(template, setup, now, energyMode),
    ];
  }

  /// Kullanıcının kendi eklediği görev (modal) için fabrika.
  static Quest custom({
    required String title,
    required StatKey stat,
    required int minutes,
    required QuestDifficulty difficulty,
    required DateTime now,
    EnergyMode energyMode = EnergyMode.balanced,
    String? summary,
    String idSuffix = '',
  }) {
    final int safeMinutes = minutes.clamp(5, 180);
    final int xp = estimateXp(safeMinutes, difficulty);
    return Quest(
      id: 'custom-${now.microsecondsSinceEpoch}$idSuffix',
      title: title.trim(),
      summary: (summary ?? '').trim().isEmpty
          ? 'Kendi hedefin · $safeMinutes dakika'
          : summary!.trim(),
      stat: stat,
      category: _categoryFor(stat),
      difficulty: difficulty,
      baseXp: xp,
      estimatedMinutes: safeMinutes,
      verification: QuestVerification.manual(),
      createdAt: now,
      cadence: QuestCadence.oneOff,
      energyMode: energyMode,
      microVariant: safeMinutes >= 30
          ? MicroVariant(
              title: 'Mikro: ${title.trim()}',
              minutes: 10,
              baseXp: math.max(10, (xp * 0.35).round()),
            )
          : null,
      tags: <String>{'custom', stat.code.toLowerCase()},
    );
  }

  /// Süre + zorluktan XP tahmini (5'in katı, 10-300 arası).
  static int estimateXp(int minutes, QuestDifficulty difficulty) {
    final double raw = minutes * 1.5 * difficulty.xpMultiplier;
    return (raw.clamp(10, 300) / 5).round() * 5;
  }

  // ── İç yardımcılar ───────────────────────────────────────────────────────

  static Quest _build(
    _QuestTemplate template,
    UserSetup setup,
    DateTime now,
    EnergyMode energyMode,
  ) {
    final String title = _fill(template.title, setup);
    final int baseXp = XpEngine.applyMultipliers(template.baseXp, <double>[
      if (template.goal != null && setup.focusStats.contains(template.stat))
        1.1,
    ]);

    return Quest(
      id: 'q-${_dayKey(now)}-${template.id}',
      title: title,
      summary: _fill(template.summary, setup),
      stat: template.stat,
      category: template.category,
      difficulty: template.difficulty,
      baseXp: baseXp,
      estimatedMinutes: template.minutes,
      verification: _verification(template),
      createdAt: now,
      cadence: QuestCadence.daily,
      energyMode: energyMode,
      microVariant: template.minutes >= 30
          ? MicroVariant(
              title: 'Mikro: ${_fill(template.microTitle, setup)}',
              minutes: 10,
              baseXp: math.max(10, (baseXp * 0.35).round()),
              summary: 'Enerjin düşükse 10 dakikalık bu adımla seriyi koru.',
            )
          : null,
      tags: <String>{
        template.goal?.code ?? 'core',
        template.stat.code.toLowerCase(),
      },
      streakCritical: template.minutes <= 30,
    );
  }

  static QuestVerification _verification(_QuestTemplate template) {
    return switch (template.kind) {
      _VerifyKind.timer => QuestVerification.timer(minutes: template.minutes),
      _VerifyKind.checklist => QuestVerification.checklist(
        items: template.checklist,
      ),
      _VerifyKind.steps => QuestVerification.stepGoal(
        targetSteps: template.stepTarget,
      ),
      _VerifyKind.reflection => QuestVerification.reflection(
        prompt: template.reflectionPrompt,
      ),
      _VerifyKind.manual => QuestVerification.manual(),
    };
  }

  static String _fill(String template, UserSetup setup) {
    final String name = setup.displayName.trim().isEmpty
        ? 'Gezgin'
        : setup.displayName.trim();
    return template
        .replaceAll('{field}', setup.personalizationLabel)
        .replaceAll('{name}', name)
        .replaceAll(
          '{grade}',
          setup.gradeYear > 0 ? '${setup.gradeYear}. sınıf' : '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static QuestCategory _categoryFor(StatKey stat) {
    for (final GoalType goal in GoalType.values) {
      if (goal.primaryStat == stat) return goal.category;
    }
    return QuestCategory.mind;
  }

  static int _dayIndex(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(2026, 1, 1)).inDays.abs();

  static String _dayKey(DateTime now) =>
      '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';

  static List<_QuestTemplate> _rotate(List<_QuestTemplate> source, int offset) {
    if (source.isEmpty) return source;
    final int start = offset % source.length;
    return <_QuestTemplate>[...source.skip(start), ...source.take(start)];
  }

  static _QuestTemplate? _firstWhere(
    List<_QuestTemplate> templates,
    bool Function(_QuestTemplate) test,
  ) {
    for (final _QuestTemplate template in templates) {
      if (test(template)) return template;
    }
    return null;
  }

  /// Tüm görev şablonları. `goal == null` olanlar herkese uygundur.
  static const List<_QuestTemplate> _templates = <_QuestTemplate>[
    // ── Evrensel (herkese uygun) ───────────────────────────────────────────
    _QuestTemplate(
      id: 'core-plan',
      title: 'Günü 3 maddelik planla',
      summary: 'Bugünün en önemli 3 işini yaz; gerisini bilinçli olarak bırak.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 20,
      kind: _VerifyKind.manual,
      microTitle: 'Yarının en önemli 1 işini not et',
    ),
    _QuestTemplate(
      id: 'core-walk',
      title: '20 dakika tempolu yürüyüşe çık',
      summary:
          'Telefonu cebinde tut, tempo yüksek olsun. Güne hareketle başla.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 20,
      baseXp: 30,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'core-water',
      title: '2 litre su iç',
      summary:
          'Şişeni doldur; öğlene kadar yarısını, akşama kadar tamamını bitir.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 20,
      kind: _VerifyKind.manual,
    ),
    _QuestTemplate(
      id: 'core-sleep',
      title: '23:30\'da telefonu bırak',
      summary:
          'Ekranı kapat, 10 dakika oku ve yatağa geç. Yarın daha güçlü kalk.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 25,
      kind: _VerifyKind.manual,
    ),

    // ── Kariyer / yazılım ──────────────────────────────────────────────────
    _QuestTemplate(
      id: 'career-module',
      goal: GoalType.career,
      title: 'GitHub projene 1 modül ekle',
      summary: '{field} projen için çalışan tek bir modül bitir ve commit at.',
      stat: StatKey.productivity,
      category: QuestCategory.career,
      difficulty: QuestDifficulty.moderate,
      minutes: 60,
      baseXp: 70,
      kind: _VerifyKind.checklist,
      microTitle: 'Projeye 15 dakika ayır, ilk commit\'i at',
      checklist: <String>[
        'Modülün sözleşmesini (input/output) yaz',
        'Kodu yaz ve çalıştır',
        'Commit + push et',
      ],
    ),
    _QuestTemplate(
      id: 'career-portfolio',
      goal: GoalType.career,
      title: 'Portfolyona 1 vaka çalışması ekle',
      summary: 'Yaptığın bir işi problem → çözüm → sonuç formatında anlat.',
      stat: StatKey.productivity,
      category: QuestCategory.career,
      difficulty: QuestDifficulty.moderate,
      minutes: 45,
      baseXp: 60,
      kind: _VerifyKind.checklist,
      microTitle: 'Portfolyo taslağına 3 başlık yaz',
      checklist: <String>[
        'Problemi 2 cümleyle tanımla',
        'Çözümü ve teknoloji seçimini anlat',
        'Sonucu bir metrikle göster',
      ],
    ),
    _QuestTemplate(
      id: 'career-reading',
      goal: GoalType.career,
      title: '{field} alanında 1 teknik makale oku',
      summary:
          'Okurken 3 madde not çıkar; yarın işine yarayacak tek fikri seç.',
      stat: StatKey.intelligence,
      category: QuestCategory.career,
      difficulty: QuestDifficulty.light,
      minutes: 25,
      baseXp: 40,
      kind: _VerifyKind.reflection,
      microTitle: 'Bir teknik yazının sadece özetini oku',
      reflectionPrompt: 'Makaleden işine yarayacak en önemli fikir neydi?',
    ),
    _QuestTemplate(
      id: 'career-interview',
      goal: GoalType.career,
      title: '1 mülakat sorusu çöz ve cevabını yaz',
      summary:
          'Sesli düşün: soruyu anlat, yaklaşımını kur, kenar durumları say.',
      stat: StatKey.productivity,
      category: QuestCategory.career,
      difficulty: QuestDifficulty.light,
      minutes: 25,
      baseXp: 40,
      kind: _VerifyKind.reflection,
      microTitle: 'Bir mülakat sorusunu sadece oku ve planla',
      reflectionPrompt: 'Sorunun çözüm yaklaşımı neydi?',
    ),
    _QuestTemplate(
      id: 'career-network',
      goal: GoalType.career,
      title: 'LinkedIn profilini güncelle, 3 kişiyle etkileşim kur',
      summary:
          'Başlığını netleştir; sektöründen 3 kişiye anlamlı bir yorum yaz.',
      stat: StatKey.productivity,
      category: QuestCategory.career,
      difficulty: QuestDifficulty.light,
      minutes: 15,
      baseXp: 25,
      kind: _VerifyKind.manual,
    ),
    // ── Akademik ───────────────────────────────────────────────────────────
    _QuestTemplate(
      id: 'academic-pomodoro',
      goal: GoalType.academic,
      title: 'Ders notlarını 25 dk Pomodoro ile tekrar et',
      summary: '{field} notlarını kapat, hatırlamaya çalış, sonra kontrol et.',
      stat: StatKey.intelligence,
      category: QuestCategory.academic,
      difficulty: QuestDifficulty.moderate,
      minutes: 25,
      baseXp: 45,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'academic-problems',
      goal: GoalType.academic,
      title: '{field} için 5 soru çöz',
      summary: 'Zor olanlardan başla; takıldığın adımı ayrıca not et.',
      stat: StatKey.intelligence,
      category: QuestCategory.academic,
      difficulty: QuestDifficulty.moderate,
      minutes: 40,
      baseXp: 60,
      kind: _VerifyKind.checklist,
      microTitle: 'Sadece 1 soru çöz ve çözümünü anlat',
      checklist: <String>[
        '5 soruyu seç',
        'Çözümleri yaz',
        'Hatalarını işaretle',
      ],
    ),
    _QuestTemplate(
      id: 'academic-preread',
      goal: GoalType.academic,
      title: 'Yarınki ders için ön okuma yap',
      summary: 'Konu başlıklarını oku, bilmediğin 3 kavramı işaretle.',
      stat: StatKey.intelligence,
      category: QuestCategory.academic,
      difficulty: QuestDifficulty.light,
      minutes: 25,
      baseXp: 40,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'academic-flashcards',
      goal: GoalType.academic,
      title: '15 flashcard ile aktif hatırlama yap',
      summary: 'Cevabı görmeden söyle; yanlışları desteye geri koy.',
      stat: StatKey.intelligence,
      category: QuestCategory.academic,
      difficulty: QuestDifficulty.light,
      minutes: 20,
      baseXp: 35,
      kind: _VerifyKind.manual,
    ),
    _QuestTemplate(
      id: 'academic-summary',
      goal: GoalType.academic,
      title: 'Bir konunun özet kartını çıkar',
      summary: 'Tek sayfaya sığdır: tanım, formül, örnek, sık yapılan hata.',
      stat: StatKey.intelligence,
      category: QuestCategory.academic,
      difficulty: QuestDifficulty.moderate,
      minutes: 35,
      baseXp: 50,
      kind: _VerifyKind.checklist,
      microTitle: 'Özet kartı için 3 anahtar kelime yaz',
      checklist: <String>[
        'Ana tanımı yaz',
        'Bir örnek ekle',
        'Sık yapılan hatayı not et',
      ],
    ),

    // ── Spor / fitnes ──────────────────────────────────────────────────────
    _QuestTemplate(
      id: 'fitness-upper',
      goal: GoalType.fitness,
      title: '40 dakika ağırlık / üst vücut antrenmanı',
      summary: 'Isınma + 4 hareket + soğuma. Ağırlığı formu bozmadan artır.',
      stat: StatKey.strength,
      category: QuestCategory.physical,
      difficulty: QuestDifficulty.hard,
      minutes: 45,
      baseXp: 75,
      kind: _VerifyKind.timer,
      microTitle: '10 dakika üst vücut ısınma + 2 hareket',
    ),
    _QuestTemplate(
      id: 'fitness-steps',
      goal: GoalType.fitness,
      title: '8.000 adım tamamla',
      summary: 'Gün sonuna bırakma: 2 kısa yürüyüşe böl, tempoyu koru.',
      stat: StatKey.strength,
      category: QuestCategory.physical,
      difficulty: QuestDifficulty.moderate,
      minutes: 60,
      baseXp: 60,
      kind: _VerifyKind.steps,
      stepTarget: 8000,
      microTitle: '2.000 adım tamamla',
    ),
    _QuestTemplate(
      id: 'fitness-mobility',
      goal: GoalType.fitness,
      title: '15 dakika esneme & mobilite',
      summary: 'Kalça, omuz ve sırt için 5 hareket; her biri 45 saniye.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 15,
      baseXp: 25,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'fitness-plank',
      goal: GoalType.fitness,
      title: '3 set plank + 20 squat',
      summary:
          'Plank 45 saniye, squat 10 tekrar. Setler arası 60 saniye dinlen.',
      stat: StatKey.strength,
      category: QuestCategory.physical,
      difficulty: QuestDifficulty.light,
      minutes: 15,
      baseXp: 30,
      kind: _VerifyKind.manual,
    ),
    // ── Beslenme ───────────────────────────────────────────────────────────
    _QuestTemplate(
      id: 'nutrition-water',
      goal: GoalType.nutrition,
      title: 'Gün boyu 2.5 litre su iç',
      summary: 'Sabah 1 bardakla başla; her öğün öncesi 1 bardak daha.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 25,
      kind: _VerifyKind.manual,
    ),
    _QuestTemplate(
      id: 'nutrition-sugarfree',
      goal: GoalType.nutrition,
      title: 'Şekersiz bir gün geçir',
      summary: 'Paketli tatlı ve şekerli içecek yok; meyve serbest.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.moderate,
      minutes: 10,
      baseXp: 45,
      kind: _VerifyKind.manual,
    ),
    _QuestTemplate(
      id: 'nutrition-meal',
      goal: GoalType.nutrition,
      title: 'Sebze ağırlıklı 1 öğün hazırla',
      summary: 'Tabağının yarısı sebze, çeyreği protein, çeyreği karbonhidrat.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 25,
      baseXp: 35,
      kind: _VerifyKind.checklist,
      checklist: <String>[
        'Sebzeleri hazırla',
        'Protein kaynağını ekle',
        'Öğünü fotoğrafla / not et',
      ],
    ),
    _QuestTemplate(
      id: 'nutrition-sleep',
      goal: GoalType.nutrition,
      title: '7 saat uyku için 23:30\'da yat',
      summary: 'Kafeini 16:00\'da kes, ekranı 22:30\'da bırak.',
      stat: StatKey.vitality,
      category: QuestCategory.health,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 40,
      kind: _VerifyKind.manual,
    ),

    // ── Okuma ──────────────────────────────────────────────────────────────
    _QuestTemplate(
      id: 'reading-session',
      goal: GoalType.reading,
      title: '30 dakika kitap oku',
      summary: 'Telefonu başka odada bırak; tek oturumda 20+ sayfa hedefle.',
      stat: StatKey.intelligence,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 30,
      baseXp: 40,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'reading-notes',
      goal: GoalType.reading,
      title: 'Bir bölüm bitir, 5 cümlelik özet yaz',
      summary: 'Kendi cümlelerinle yaz; kitaptan alıntı yapma.',
      stat: StatKey.intelligence,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.moderate,
      minutes: 40,
      baseXp: 55,
      kind: _VerifyKind.reflection,
      microTitle: 'Bir bölümün ilk 3 sayfasını oku',
      reflectionPrompt: 'Bölümün ana fikri neydi?',
    ),
    _QuestTemplate(
      id: 'reading-pages',
      goal: GoalType.reading,
      title: '20 sayfa oku ve 3 not çıkar',
      summary: 'İşaretleme yapma, kenara kendi notunu yaz.',
      stat: StatKey.intelligence,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 25,
      baseXp: 35,
      kind: _VerifyKind.manual,
    ),

    // ── Disiplin ───────────────────────────────────────────────────────────
    _QuestTemplate(
      id: 'discipline-wake',
      goal: GoalType.discipline,
      title: '07:00\'de kalk ve 5 dk günlük yaz',
      summary: 'Alarmı erteleme; kalkınca ilk iş 3 cümle yazmak.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.moderate,
      minutes: 20,
      baseXp: 45,
      kind: _VerifyKind.reflection,
      microTitle: 'Alarmdan sonra 1 cümle yaz',
      reflectionPrompt: 'Bu sabah seni en çok ne motive etti?',
    ),
    _QuestTemplate(
      id: 'discipline-focus',
      goal: GoalType.discipline,
      title: '1 saat telefonsuz derin odak',
      summary: 'Bildirimleri kapat, tek bir işe odaklan, ara verme.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.hard,
      minutes: 60,
      baseXp: 80,
      kind: _VerifyKind.timer,
      microTitle: '15 dakika telefonsuz odak',
    ),
    _QuestTemplate(
      id: 'discipline-meditate',
      goal: GoalType.discipline,
      title: '10 dakika nefes / meditasyon',
      summary: '4 saniye al, 6 saniye ver. Düşünceler gelirse geri dön.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 10,
      baseXp: 20,
      kind: _VerifyKind.timer,
    ),
    _QuestTemplate(
      id: 'discipline-morning',
      goal: GoalType.discipline,
      title: 'Sabah rutini: soğuk duş + 10 dk yürüyüş',
      summary: 'Duştan sonra doğrudan dışarı çık; telefonu yanına alma.',
      stat: StatKey.willpower,
      category: QuestCategory.mind,
      difficulty: QuestDifficulty.light,
      minutes: 15,
      baseXp: 30,
      kind: _VerifyKind.manual,
    ),
  ];

  // ── Şablon modeli ────────────────────────────────────────────────────────
}

/// Doğrulama türü — şablon listesini `const` tutabilmek için enum'a çevrildi.
enum _VerifyKind { timer, checklist, steps, reflection, manual }

/// Tek bir görev şablonu.
///
/// `{field}` / `{name}` / `{grade}` yer tutucuları kullanıcının onboarding
/// cevaplarıyla doldurulur; böylece şablonlar sabit kalırken görevler kişisel
/// görünür.
final class _QuestTemplate {
  const _QuestTemplate({
    required this.id,
    required this.title,
    required this.summary,
    required this.stat,
    required this.category,
    required this.difficulty,
    required this.minutes,
    required this.baseXp,
    required this.kind,
    this.goal,
    this.microTitle = 'Aynı görevin 10 dakikalık hali',
    this.checklist = const <String>[],
    this.stepTarget = 8000,
    this.reflectionPrompt = 'Bugün bu görevde ne öğrendin?',
  });

  final String id;
  final GoalType? goal;
  final String title;
  final String summary;
  final StatKey stat;
  final QuestCategory category;
  final QuestDifficulty difficulty;
  final int minutes;
  final int baseXp;
  final _VerifyKind kind;
  final String microTitle;
  final List<String> checklist;
  final int stepTarget;
  final String reflectionPrompt;
}
