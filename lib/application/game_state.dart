import '../core/utils/json_x.dart';
import '../domain/entities/entities.dart';

/// Uygulamanın tek oyun durumu (Riverpod `GameController` tarafından tutulur).
///
/// * [setup] → onboarding cevapları (kişi bilgileri)
/// * [profile] → RPG profili (XP, statlar, seri)
/// * [quests] → bugünün kişiselleştirilmiş görev listesi
final class GameState {
  const GameState({
    this.setup,
    this.profile,
    this.quests = const <Quest>[],
  });

  final UserSetup? setup;
  final UserProfile? profile;
  final List<Quest> quests;

  /// Onboarding tamamlandı mı? Router bu değere bakar.
  bool get isOnboarded => setup != null && profile != null;

  bool get hasPendingQuests => quests.any((Quest quest) => quest.isOpen);

  int get completedCount => quests.where((Quest quest) => quest.isCompleted).length;

  int get totalXp => profile?.totalXp ?? 0;

  /// Günlük XP geçmişi (onboarding öncesi boş).
  DailyXpLog get xpLog => profile?.xpLog ?? DailyXpLog.empty;

  /// Bugün tamamlanan görevlerin ham XP toplamı (özet kartı için).
  int get earnedXpToday => quests
      .where((Quest quest) => quest.isCompleted)
      .fold<int>(0, (int sum, Quest quest) => sum + quest.effectiveBaseXp);

  List<Quest> get openQuests =>
      quests.where((Quest quest) => quest.isOpen).toList(growable: false);

  GameState copyWith({
    UserSetup? setup,
    UserProfile? profile,
    List<Quest>? quests,
  }) {
    return GameState(
      setup: setup ?? this.setup,
      profile: profile ?? this.profile,
      quests: quests ?? this.quests,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'setup': setup?.toJson(),
        'profile': profile?.toJson(),
        'quests': <Map<String, dynamic>>[
          for (final Quest quest in quests) quest.toJson(),
        ],
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> setupJson = JsonX.asMap(json['setup']);
    final Map<String, dynamic> profileJson = JsonX.asMap(json['profile']);
    final List<Quest> quests = <Quest>[];
    final Object? rawQuests = json['quests'];
    if (rawQuests is List) {
      for (final Object? item in rawQuests) {
        if (item is Map) {
          quests.add(Quest.fromJson(JsonX.asMap(item)));
        }
      }
    }
    return GameState(
      setup: setupJson.isEmpty ? null : UserSetup.fromJson(setupJson),
      profile: profileJson.isEmpty ? null : UserProfile.fromJson(profileJson),
      quests: quests,
    );
  }

  @override
  String toString() => 'GameState(onboarded: $isOnboarded · '
      '${quests.length} görev · $totalXp XP)';
}
