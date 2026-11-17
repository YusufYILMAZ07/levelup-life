import '../core/utils/json_x.dart';
import '../domain/entities/entities.dart';

/// Uygulamanın tek oyun durumu (Riverpod `GameController` tarafından tutulur).
///
/// İki mod vardır:
///
/// * **Tek oyuncu (legacy)** → [setup]/[profile]/[quests] doğrudan dolu,
///   [partners] boş. Onboarding akışı ve eski testler bu modu kullanır.
/// * **Çift sürümü** → [partners] iki kişiyi tutar, [activePartnerId] hangisinin
///   ekranda olduğunu belirler. [setup]/[profile]/[quests] her zaman **aktif
///   partnerin** aynasıdır; böylece mevcut tüm ekranlar değişmeden çalışır.
final class GameState {
  const GameState({
    this.setup,
    this.profile,
    this.quests = const <Quest>[],
    this.partners = const <String, PartnerData>{},
    this.activePartnerId = CouplePartner.yusufId,
    this.couple = const CoupleState(),
  });

  /// Aktif partnerin onboarding cevapları.
  final UserSetup? setup;

  /// Aktif partnerin RPG profili.
  final UserProfile? profile;

  /// Aktif partnerin bugünkü görevleri.
  final List<Quest> quests;

  /// Partner kimliği → kişisel veri (çift sürümünde 2 kayıt).
  final Map<String, PartnerData> partners;

  /// Ekranda olan partner (`yusuf` / `ceyda`).
  final String activePartnerId;

  /// İki kişiyi bağlayan ortak durum (sohbet, rubrik, bucket list…).
  final CoupleState couple;

  /// Çift sürümü mü? (iki partner de kayıtlı)
  bool get isCoupleEdition =>
      partners.containsKey(CouplePartner.yusufId) &&
      partners.containsKey(CouplePartner.ceydaId);

  /// Onboarding tamamlandı mı? Router bu değere bakar.
  bool get isOnboarded => setup != null && profile != null;

  bool get hasPendingQuests => quests.any((Quest quest) => quest.isOpen);

  int get completedCount =>
      quests.where((Quest quest) => quest.isCompleted).length;

  int get totalXp => profile?.totalXp ?? 0;

  /// Günlük XP geçmişi (onboarding öncesi boş).
  DailyXpLog get xpLog => profile?.xpLog ?? DailyXpLog.empty;

  /// Bugün tamamlanan görevlerin ham XP toplamı (özet kartı için).
  int get earnedXpToday => quests
      .where((Quest quest) => quest.isCompleted)
      .fold<int>(0, (int sum, Quest quest) => sum + quest.effectiveBaseXp);

  List<Quest> get openQuests =>
      quests.where((Quest quest) => quest.isOpen).toList(growable: false);

  // ── Partner erişimi ──────────────────────────────────────────────────────

  /// Aktif partnerin verisi (tek oyuncu modunda alanlardan üretilir).
  PartnerData get activePartner =>
      partners[activePartnerId] ??
      PartnerData(setup: setup, profile: profile, quests: quests);

  /// Aktif partnerin "öteki yarısı" (tek oyuncu modunda boş).
  PartnerData get otherPartner =>
      partnerData(CouplePartner.other(activePartnerId)) ?? const PartnerData();

  PartnerData? partnerData(String partnerId) => partners[partnerId];

  List<PartnerData> get partnerList => <PartnerData>[
    for (final String id in CouplePartner.ids)
      partnerData(id) ?? const PartnerData(),
  ];

  /// Partnerin bugünkü XP'si (üst bardaki "+X XP" etiketi).
  int xpTodayFor(String partnerId, DateTime now) =>
      partnerData(partnerId)?.xpOn(now) ?? 0;

  /// Partnerin bugün tamamladığı görev sayısı.
  int questsCompletedFor(String partnerId, DateTime now) =>
      couple.questsCompletedOn(partnerId, now);

  // ── Kopyalama / geçiş ────────────────────────────────────────────────────

  /// [setup]/[profile]/[quests] verilirse **aktif partnerin** verisi güncellenir.
  GameState copyWith({
    UserSetup? setup,
    UserProfile? profile,
    List<Quest>? quests,
    Map<String, PartnerData>? partners,
    CoupleState? couple,
  }) {
    final Map<String, PartnerData> nextPartners = partners == null
        ? <String, PartnerData>{...this.partners}
        : <String, PartnerData>{...partners};

    if (nextPartners.isEmpty) {
      return GameState(
        setup: setup ?? this.setup,
        profile: profile ?? this.profile,
        quests: quests ?? this.quests,
        activePartnerId: activePartnerId,
        couple: couple ?? this.couple,
      );
    }

    final PartnerData current =
        nextPartners[activePartnerId] ?? const PartnerData();
    nextPartners[activePartnerId] = current.copyWith(
      setup: setup,
      profile: profile,
      quests: quests,
    );
    return GameState.dual(
      partners: nextPartners,
      activePartnerId: activePartnerId,
      couple: couple ?? this.couple,
    );
  }

  /// Partnerin verisini değiştirir (aktifse aynalar da güncellenir).
  GameState withPartner(String partnerId, PartnerData data) =>
      _rebuild(partners: <String, PartnerData>{...partners, partnerId: data});

  /// Üst bardaki segment geçişi. Tek oyuncu modunda etkisizdir.
  GameState activatePartner(String partnerId) {
    if (!CouplePartner.isValid(partnerId) || partnerId == activePartnerId) {
      return this;
    }
    if (partners.isEmpty) return this;
    return GameState.dual(
      partners: partners,
      activePartnerId: partnerId,
      couple: couple,
    );
  }

  /// Ortak durumu değiştirir.
  GameState withCouple(CoupleState next) => _rebuild(couple: next);

  /// Her iki partnerin profilini XP ile ödüllendirir (Co-Op / sinerji).
  GameState grantBoth({
    required StatKey stat,
    required int xp,
    required DateTime at,
  }) {
    if (partners.isEmpty) {
      final UserProfile? self = profile;
      if (self == null) return this;
      return copyWith(
        profile: self.completeQuest(stat: stat, xp: xp, at: at).profile,
      );
    }
    final Map<String, PartnerData> next = <String, PartnerData>{...partners};
    for (final String id in CouplePartner.ids) {
      final PartnerData? data = next[id];
      final UserProfile? partnerProfile = data?.profile;
      if (data == null || partnerProfile == null) continue;
      next[id] = data.copyWith(
        profile: partnerProfile
            .completeQuest(stat: stat, xp: xp, at: at)
            .profile,
      );
    }
    return _rebuild(partners: next);
  }

  GameState _rebuild({
    Map<String, PartnerData>? partners,
    CoupleState? couple,
  }) {
    final Map<String, PartnerData> nextPartners = partners ?? this.partners;
    final CoupleState nextCouple = couple ?? this.couple;
    if (nextPartners.isEmpty) {
      return GameState(
        setup: setup,
        profile: profile,
        quests: quests,
        activePartnerId: activePartnerId,
        couple: nextCouple,
      );
    }
    return GameState.dual(
      partners: nextPartners,
      activePartnerId: activePartnerId,
      couple: nextCouple,
    );
  }

  /// Partner haritasından aynaları yeniden üreten kurucu.
  factory GameState.dual({
    required Map<String, PartnerData> partners,
    String activePartnerId = CouplePartner.yusufId,
    CoupleState couple = const CoupleState(),
  }) {
    final String activeId = partners.containsKey(activePartnerId)
        ? activePartnerId
        : (partners.keys.isEmpty ? activePartnerId : partners.keys.first);
    final PartnerData active = partners[activeId] ?? const PartnerData();
    return GameState(
      setup: active.setup,
      profile: active.profile,
      quests: active.quests,
      partners: partners,
      activePartnerId: activeId,
      couple: couple,
    );
  }

  // ── Kalıcılık ────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
    'setup': setup?.toJson(),
    'profile': profile?.toJson(),
    'quests': <Map<String, dynamic>>[
      for (final Quest quest in quests) quest.toJson(),
    ],
    'partners': <String, dynamic>{
      for (final MapEntry<String, PartnerData> entry in partners.entries)
        entry.key: entry.value.toJson(),
    },
    'active_partner_id': activePartnerId,
    'couple': couple.toJson(),
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

    final Map<String, PartnerData> partners = <String, PartnerData>{};
    JsonX.asMap(json['partners']).forEach((String key, dynamic value) {
      if (value is Map) {
        partners[key] = PartnerData.fromJson(JsonX.asMap(value));
      }
    });

    final CoupleState couple = CoupleState.fromJson(
      JsonX.asMap(json['couple']),
    );
    final String requestedActive = JsonX.asString(
      json['active_partner_id'],
      fallback: CouplePartner.yusufId,
    );
    final String activeId = CouplePartner.isValid(requestedActive)
        ? requestedActive
        : CouplePartner.yusufId;

    if (partners.isNotEmpty) {
      return GameState.dual(
        partners: partners,
        activePartnerId: activeId,
        couple: couple,
      );
    }

    return GameState(
      setup: setupJson.isEmpty ? null : UserSetup.fromJson(setupJson),
      profile: profileJson.isEmpty ? null : UserProfile.fromJson(profileJson),
      quests: quests,
      activePartnerId: activeId,
      couple: couple,
    );
  }

  @override
  String toString() =>
      'GameState(onboarded: $isOnboarded · '
      '${quests.length} görev · $totalXp XP · aktif: $activePartnerId · '
      '${couple.messages.length} mesaj)';
}
