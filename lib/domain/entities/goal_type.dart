import 'quest.dart';
import 'stat_key.dart';

/// Onboarding'de çoklu seçilen gelişim hedefleri.
///
/// Her hedef 1-2 statı besler: birincil stat tam ağırlıkla, ikincil stat yarı
/// ağırlıkla odak kümesine girer. Bu küme hem arketip önerisini hem de görev
/// motorunun hangi şablonları öne çıkaracağını belirler.
enum GoalType {
  fitness(
    code: 'fitness',
    label: 'Düzenli Spor & Fitnes',
    tagline: 'Antrenman, güç, dayanıklılık',
    primaryStat: StatKey.strength,
    secondaryStat: StatKey.vitality,
    category: QuestCategory.physical,
  ),
  academic(
    code: 'academic',
    label: 'Akademik Başarı & Not Ortalaması',
    tagline: 'Dersler, sınavlar, GPA',
    primaryStat: StatKey.intelligence,
    secondaryStat: StatKey.willpower,
    category: QuestCategory.academic,
  ),
  career(
    code: 'career',
    label: 'Yazılım / Kariyer Projeleri',
    tagline: 'Portfolyo, GitHub, mülakat',
    primaryStat: StatKey.productivity,
    secondaryStat: StatKey.intelligence,
    category: QuestCategory.career,
  ),
  nutrition(
    code: 'nutrition',
    label: 'Sağlıklı Beslenme & Su',
    tagline: 'Su, uyku, temiz beslenme',
    primaryStat: StatKey.vitality,
    secondaryStat: null,
    category: QuestCategory.health,
  ),
  reading(
    code: 'reading',
    label: 'Kitap Okuma & Genel Kültür',
    tagline: 'Her gün 20+ sayfa',
    primaryStat: StatKey.intelligence,
    secondaryStat: StatKey.willpower,
    category: QuestCategory.mind,
  ),
  discipline(
    code: 'discipline',
    label: 'Erken Kalkma & Disiplin',
    tagline: 'Uyku düzeni, alışkanlıklar',
    primaryStat: StatKey.willpower,
    secondaryStat: StatKey.strength,
    category: QuestCategory.mind,
  );

  const GoalType({
    required this.code,
    required this.label,
    required this.tagline,
    required this.primaryStat,
    required this.secondaryStat,
    required this.category,
  });

  /// Backend / JSON kimliği.
  final String code;

  final String label;
  final String tagline;

  /// Hedefin ana odağı.
  final StatKey primaryStat;

  /// Destekleyici odak (yoksa hedef tek statlıdır).
  final StatKey? secondaryStat;

  /// Bu hedefin görevlerinin ait olduğu kategori.
  final QuestCategory category;

  /// Hedefin beslediği statlar (birincil önce gelir → determinist sıra).
  Set<StatKey> get stats => <StatKey>{primaryStat, ?secondaryStat};

  static GoalType fromCode(String? code) {
    for (final GoalType goal in values) {
      if (goal.code == code || goal.name == code) return goal;
    }
    return GoalType.discipline;
  }

  static GoalType? tryFromCode(String? code) {
    if (code == null) return null;
    for (final GoalType goal in values) {
      if (goal.code == code || goal.name == code) return goal;
    }
    return null;
  }
}
