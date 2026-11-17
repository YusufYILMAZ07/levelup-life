import '../../core/utils/json_x.dart';
import 'quest.dart';
import 'user_profile.dart';
import 'user_setup.dart';

/// İki kişilik sürümün sabit partner kimlikleri.
///
/// `GameState` bu kimlikleri anahtar olarak kullanır; UI ise renk/emoji
/// eşlemesini `CouplePalette` üzerinden alır (domain renk bilmez).
abstract final class CouplePartner {
  static const String yusufId = 'yusuf';
  static const String ceydaId = 'ceyda';

  /// Sabit sıra: üst bardaki segment sırası da budur.
  static const List<String> ids = <String>[yusufId, ceydaId];

  static bool isValid(String id) => ids.contains(id);

  static String other(String id) => id == ceydaId ? yusufId : ceydaId;

  static String displayName(String id) => id == ceydaId ? 'Ceyda' : 'Yusuf';

  static String emoji(String id) => id == ceydaId ? '🌸' : '💻';

  /// "Yusuf 💻" gibi tek satırlık etiket.
  static String badge(String id) => '${displayName(id)} ${emoji(id)}';
}

/// Tek bir partnerin kişisel oyun verisi.
///
/// `GameState` aktif partnerin alanlarını üst seviyede aynalar (geriye dönük
/// uyumluluk için), ama iki partnerin verisi her zaman bu sarmalayıcı ile
/// haritada saklanır → partner değiştirme veri kaybetmez.
final class PartnerData {
  const PartnerData({this.setup, this.profile, this.quests = const <Quest>[]});

  final UserSetup? setup;
  final UserProfile? profile;

  /// Bugünün görev listesi — partner başına ayrı tutulur.
  final List<Quest> quests;

  /// Profil ve tanışma verisi hazır mı?
  bool get isReady => setup != null && profile != null;

  String get displayName =>
      profile?.displayName ?? setup?.displayName ?? 'Gezgin';

  int get levelNumber => profile?.levelNumber ?? 1;

  int get totalXp => profile?.totalXp ?? 0;

  List<Quest> get openQuests =>
      quests.where((Quest quest) => quest.isOpen).toList(growable: false);

  int get completedCount =>
      quests.where((Quest quest) => quest.isCompleted).length;

  int xpOn(DateTime day) => profile?.xpLog.xpOn(day) ?? 0;

  bool get isActiveToday => openQuests.length < quests.length;

  PartnerData copyWith({
    UserSetup? setup,
    UserProfile? profile,
    List<Quest>? quests,
  }) => PartnerData(
    setup: setup ?? this.setup,
    profile: profile ?? this.profile,
    quests: quests ?? this.quests,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'setup': setup?.toJson(),
    'profile': profile?.toJson(),
    'quests': <Map<String, dynamic>>[
      for (final Quest quest in quests) quest.toJson(),
    ],
  };

  factory PartnerData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> setupJson = JsonX.asMap(json['setup']);
    final Map<String, dynamic> profileJson = JsonX.asMap(json['profile']);
    final List<Quest> quests = <Quest>[];
    final Object? rawQuests = json['quests'];
    if (rawQuests is List) {
      for (final Object? item in rawQuests) {
        if (item is Map) quests.add(Quest.fromJson(JsonX.asMap(item)));
      }
    }
    return PartnerData(
      setup: setupJson.isEmpty ? null : UserSetup.fromJson(setupJson),
      profile: profileJson.isEmpty ? null : UserProfile.fromJson(profileJson),
      quests: quests,
    );
  }

  @override
  String toString() =>
      'PartnerData($displayName · Lv$levelNumber · '
      '${quests.length} görev)';
}
