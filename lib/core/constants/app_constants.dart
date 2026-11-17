/// Ürün genelinde paylaşılan, framework'ten bağımsız sabitler.
///
/// Ürün ekibinin ileride tune etmek isteyebileceği her şey (seviye tavanı,
/// streak dondurma hakkı, tablo isimleri) widget'ların içine gömülmez;
/// burada tek noktadan yönetilir.
abstract final class AppConstants {
  // ── Ürün kimliği ─────────────────────────────────────────────────────────
  static const String appName = 'LevelUp Life';
  static const String appTagline = 'Hayatını seviye atlat.';
  static const String appVersion = '0.1.0';

  // ── İlerleme sınırları ───────────────────────────────────────────────────
  static const int minLevel = 1;
  static const int maxLevel = 99;

  // ── Streak ekonomisi ─────────────────────────────────────────────────────
  /// Yeni karakterin başlangıçta sahip olduğu seri dondurma hakkı.
  static const int startingFreezeTokens = 2;

  /// Satın alınabilecek / kazanılabilecek üst sınır.
  static const int maxFreezeTokens = 3;

  // ── Yerleşim ─────────────────────────────────────────────────────────────
  /// Tablet ve katlanabilir cihazlarda içeriğin dağılmaması için üst sınır.
  static const double maxContentWidth = 560;

  /// Apple HIG / Material dokunma hedefi alt sınırı.
  static const double minTouchTarget = 48;

  // ── Backend (Supabase / Firebase uyumlu) tablo adları ────────────────────
  static const String profilesTable = 'profiles';
  static const String questsTable = 'quests';
  static const String questCompletionsTable = 'quest_completions';
  static const String questlinesTable = 'questlines';
  static const String leagueEntriesTable = 'league_entries';
  static const String coopBuddiesTable = 'coop_buddies';
  static const String weeklyReportsTable = 'weekly_reports';

  // ── Yerel önbellek anahtarları ───────────────────────────────────────────
  /// Tüm oyun durumu (onboarding + profil + görevler) tek JSON olarak.
  static const String cacheGameState = 'cache.game_state';
  static const String cacheUserProfile = 'cache.user_profile';
  static const String cacheActiveQuests = 'cache.active_quests';
  static const String cacheWeeklyReport = 'cache.weekly_report';

  // ── Deney bayrakları (ileride remote config ile ezilecek) ────────────────
  static const bool enableHaptics = true;
  static const bool enableSocialLeague = true;
}
