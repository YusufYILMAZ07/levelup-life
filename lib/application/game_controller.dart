import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../domain/services/couple_efficiency_engine.dart';
import 'controllers/couple_chat_controller.dart';
import 'controllers/couple_goals_controller.dart';
import 'controllers/couple_sync_controller.dart';
import 'controllers/development_controller.dart';
import 'controllers/quest_controller.dart';
import 'game_mutation.dart';
import 'game_outcomes.dart';
import 'game_state.dart';

export 'game_outcomes.dart';

/// Oyun döngüsünün **ince koordinatörü** (v6).
///
/// v5'te 962 satır olan sınıf beş modüle bölündü:
///
/// | Modül | Sorumluluk |
/// |---|---|
/// | [QuestController] | onboarding, günlük/özel görevler, XP & seviye |
/// | [DevelopmentController] | 5 alanlı rubrik, sinerji, bonuslar, kapsüller |
/// | [CoupleChatController] | sohbet, medya, dürtme, tepkiler, tombstone |
/// | [CoupleGoalsController] | bucket list, haftalık plan/bahis, özel günler |
/// | [CoupleSyncController] | cihaz kimliği, bulut birleştirme, sıfırlama |
///
/// Genel API geriye dönük uyum için korunur; UI kademeli olarak modül
/// provider'larına ([questControllerProvider] …) geçebilir.
final class GameController extends Notifier<GameState>
    implements GameStateAccess {
  late final QuestController quests = QuestController(this);
  late final DevelopmentController development = DevelopmentController(this);
  late final CoupleChatController chat = CoupleChatController(this);
  late final CoupleGoalsController goals = CoupleGoalsController(this);
  late final CoupleSyncController sync = CoupleSyncController(this);

  int _localRevision = 0;
  MutationOrigin _lastOrigin = MutationOrigin.local;

  /// Yerel mutasyon sayacı. Uzak paketler bu sayacı artırmaz; senkron
  /// koordinatörü "gönderilecek yeni bir şey var mı?" sorusunu buradan
  /// deterministik olarak yanıtlar (sabit Timer penceresi yok).
  int get localRevision => _localRevision;

  /// En son mutasyonun kaynağı.
  MutationOrigin get lastOrigin => _lastOrigin;

  @override
  GameState build() {
    final GameStore store = ref.watch(gameStoreProvider);
    return store.load() ?? const GameState();
  }

  @override
  void commit(GameState next, {MutationOrigin origin = MutationOrigin.local}) {
    if (identical(next, state)) return;
    _lastOrigin = origin;
    if (origin == MutationOrigin.local) _localRevision++;
    state = next;
    _persist();
  }

  // ── Onboarding & görevler (QuestController) ──────────────────────────────

  void completeOnboarding(UserSetup setup) => quests.completeOnboarding(setup);

  XpAward? completeQuest(String questId) => quests.completeQuest(questId);

  int xpForQuest(UserProfile profile, Quest quest) =>
      quests.xpForQuest(profile, quest);

  bool addQuest(Quest quest) => quests.addQuest(quest);

  void removeQuest(String questId) => quests.removeQuest(questId);

  void refreshQuests() => quests.refreshQuests();

  void setEnergyMode(EnergyMode mode) => quests.setEnergyMode(mode);

  // ── Gelişim & bonuslar (DevelopmentController) ───────────────────────────

  RubricOutcome ratePillar({
    required StatKey pillar,
    required int score,
    String? partnerId,
  }) => development.ratePillar(
    pillar: pillar,
    score: score,
    partnerId: partnerId,
  );

  XpAward? quickAction(QuickAction action, {String? partnerId}) =>
      development.quickAction(action, partnerId: partnerId);

  XpAward? addCustomBonus({
    required String title,
    required int points,
    required StatKey stat,
    String? partnerId,
  }) => development.addCustomBonus(
    title: title,
    points: points,
    stat: stat,
    partnerId: partnerId,
  );

  bool openRewardCapsule(String capsuleId) =>
      development.openRewardCapsule(capsuleId);

  RewardCapsule? addRewardCapsule({
    required String title,
    required int requiredPoints,
    String emoji = '🎁',
    String description = '',
    String rewardMessage = '',
  }) => development.addRewardCapsule(
    title: title,
    requiredPoints: requiredPoints,
    emoji: emoji,
    description: description,
    rewardMessage: rewardMessage,
  );

  // ── Partner & uzak durum (CoupleSyncController) ──────────────────────────

  void switchPartner(String partnerId) => sync.switchPartner(partnerId);

  void toggleActivePartner() => sync.toggleActivePartner();

  /// Cihaz sahibi kilidi (`AppSettings`) aktifse partneri sahibe sabitler.
  ///
  /// Ayar nesnesi artık parametre olarak taşınmaz: `sync` katmanı güncel
  /// ayarları kendi okur (eski imza yanlışlıkla eski bir kopyayı uyguluyordu).
  void enforceDeviceOwner() => sync.enforceDeviceOwner();

  void applyRemoteState(GameState remote, {String? deviceRole}) =>
      sync.applyRemoteState(remote, deviceRole: deviceRole);

  Future<void> resetJourney() => sync.resetJourney();

  Future<void> restartCoupleJourney() => sync.restartCoupleJourney();

  Future<void> importState(GameState state) => sync.importState(state);

  // ── Sohbet & anı albümü (CoupleChatController) ───────────────────────────

  bool addLoveNote(String note) => goals.addLoveNote(note);

  bool deleteLoveNote(String note) => goals.deleteLoveNote(note);

  void setBirthdayMessage(String message) => goals.setBirthdayMessage(message);

  void cycleLoveNote() => chat.cycleLoveNote();

  ChatMessage? sendMessage(
    String text, {
    ChatMessageKind kind = ChatMessageKind.text,
    ChatMessage? replyTo,
  }) => chat.sendMessage(text, kind: kind, replyTo: replyTo);

  ChatMessage? sendPhoto({
    required String photoDataOrUrl,
    String caption = '',
    ChatMessage? replyTo,
  }) => chat.sendPhoto(
    photoDataOrUrl: photoDataOrUrl,
    caption: caption,
    replyTo: replyTo,
  );

  ChatMessage? sendMedia({
    required String mediaPathOrUrl,
    required ChatMediaType mediaType,
    String caption = '',
    String? thumbnailPath,
    int durationSeconds = 0,
    ChatMessage? replyTo,
  }) => chat.sendMedia(
    mediaPathOrUrl: mediaPathOrUrl,
    mediaType: mediaType,
    caption: caption,
    thumbnailPath: thumbnailPath,
    durationSeconds: durationSeconds,
    replyTo: replyTo,
  );

  ChatMessage? sendScheduleProof({
    String? partnerId,
    String? blockId,
    ChatMessage? replyTo,
  }) => chat.sendScheduleProof(
    partnerId: partnerId,
    blockId: blockId,
    replyTo: replyTo,
  );

  bool deleteMessage(
    String messageId, {
    MutationOrigin origin = MutationOrigin.local,
  }) => chat.deleteMessage(messageId, origin: origin);

  bool editMessage(String messageId, String text) =>
      chat.editMessage(messageId, text);

  bool reactToMessage(String messageId, String emoji) =>
      chat.reactToMessage(messageId, emoji);

  void markConversationRead({String? readerId}) =>
      chat.markConversationRead(readerId: readerId);

  bool receiveRemoteMessage(ChatMessage message) =>
      chat.receiveRemoteMessage(message);

  bool mergeRemoteMessageUpdate(ChatMessage message) =>
      chat.mergeRemoteMessageUpdate(message);

  int mergeRemoteMessages(
    List<ChatMessage> incoming, {
    MutationOrigin origin = MutationOrigin.remote,
  }) => chat.mergeRemoteMessages(incoming, origin: origin);

  void patchMessage(ChatMessage message) => chat.patchMessage(message);

  void likeMessage(String messageId) => chat.likeMessage(messageId);

  ChatMessage? nudgePartner() => chat.nudgePartner();

  /// Dürtme bekleme süresinden kalan saniye (0 → gönderilebilir).
  Duration nudgeCooldownRemaining() => chat.nudgeCooldownRemaining();

  ChatMessage? sendLoveNote() => chat.sendLoveNote();

  ChatMessage? sendLoveMessage(String text) => chat.sendLoveMessage(text);

  ChatMessage? shareQuest(Quest quest, {int earnedPoints = 0}) =>
      chat.shareQuest(quest, earnedPoints: earnedPoints);

  // ── Hedefler & plan (CoupleGoalsController) ──────────────────────────────

  void setLiveStatus(LiveStatus status, {String? partnerId}) =>
      goals.setLiveStatus(status, partnerId: partnerId);

  bool toggleBucketGoal(String goalId) => goals.toggleBucketGoal(goalId);

  ScheduleOutcome? completeScheduleBlock(String blockId, {DateTime? day}) =>
      goals.completeScheduleBlock(blockId, day: day);

  int addScheduleBlocks(Iterable<ScheduleBlock> blocks) =>
      goals.addScheduleBlocks(blocks);

  void removeScheduleBlock(String blockId) =>
      goals.removeScheduleBlock(blockId);

  void setStake(DuelStake stake) => goals.setStake(stake);

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  void _persist() {
    final GameStore store = ref.read(gameStoreProvider);
    final GameState snapshot = state;
    // Seri kuyruk: her yazma bir öncekinin bitmesini bekler. Aksi hâlde hızlı
    // art arda mutasyonlarda eski bir anlık görüntü sonuncuyu ezebiliyordu.
    _writeChain = _writeChain.then((_) async {
      try {
        await store.save(snapshot);
        _lastStorageError = null;
      } catch (error) {
        // Web'de localStorage kotası dolsa bile uygulama çalışmaya devam eder;
        // ancak hata sessizce yutulmaz (teşhis paneli gösterebilir).
        _lastStorageError = 'Oyun durumu kaydedilemedi: $error';
        debugPrint('[GameController] $_lastStorageError');
      }
    });
  }

  Future<void> _writeChain = Future<void>.value();

  String? _lastStorageError;

  /// Son kalıcılık hatası (yoksa `null`).
  String? get lastStorageError => _lastStorageError;

  /// Bekleyen yazımların bitmesini bekler (uygulama kapanışı / test).
  @override
  Future<void> flushWrites() => _writeChain;
}

/// Tüm ekranların dinlediği tek provider.
final NotifierProvider<GameController, GameState> gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

// ── Modül provider'ları (granular erişim) ──────────────────────────────────

final Provider<QuestController> questControllerProvider =
    Provider<QuestController>(
      (Ref ref) => ref.watch(gameProvider.notifier).quests,
    );

final Provider<DevelopmentController> developmentControllerProvider =
    Provider<DevelopmentController>(
      (Ref ref) => ref.watch(gameProvider.notifier).development,
    );

final Provider<CoupleChatController> coupleChatControllerProvider =
    Provider<CoupleChatController>(
      (Ref ref) => ref.watch(gameProvider.notifier).chat,
    );

final Provider<CoupleGoalsController> coupleGoalsControllerProvider =
    Provider<CoupleGoalsController>(
      (Ref ref) => ref.watch(gameProvider.notifier).goals,
    );

final Provider<CoupleSyncController> coupleSyncControllerProvider =
    Provider<CoupleSyncController>(
      (Ref ref) => ref.watch(gameProvider.notifier).sync,
    );

// ── Granular seçiciler (gereksiz rebuild'i önler) ─────────────────────────

/// Kısayol: onboarding tamamlandı mı?
final Provider<bool> isOnboardedProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(gameProvider.select((GameState state) => state.isOnboarded)),
);

/// Kısayol: aktif profil (onboarding öncesi `null`).
final Provider<UserProfile?> profileProvider = Provider<UserProfile?>(
  (Ref ref) =>
      ref.watch(gameProvider.select((GameState state) => state.profile)),
);

/// Aktif partnerin tam verisi (görevler dahil).
final Provider<PartnerData> activePartnerProvider = Provider<PartnerData>(
  (Ref ref) =>
      ref.watch(gameProvider.select((GameState state) => state.activePartner)),
);

/// Ekranda olmayan partnerin profili (üst bar / karşılaştırma kartları).
final Provider<UserProfile?> partnerProfileProvider = Provider<UserProfile?>((
  Ref ref,
) {
  return ref.watch(
    gameProvider.select(
      (GameState state) => state
          .partnerData(CouplePartner.other(state.activePartnerId))
          ?.profile,
    ),
  );
});

/// Ortak çift durumu (sohbet, rubrik, bucket list).
final Provider<CoupleState> coupleStateProvider = Provider<CoupleState>(
  (Ref ref) =>
      ref.watch(gameProvider.select((GameState state) => state.couple)),
);

/// Yalnızca görev listesi — görev ekranı sohbet değişiminde rebuild olmaz.
final Provider<List<Quest>> questsProvider = Provider<List<Quest>>(
  (Ref ref) =>
      ref.watch(gameProvider.select((GameState state) => state.quests)),
);

/// Yalnızca sohbet mesajları.
final Provider<List<ChatMessage>> messagesProvider =
    Provider<List<ChatMessage>>(
      (Ref ref) => ref.watch(
        gameProvider.select((GameState state) => state.couple.messages),
      ),
    );

/// Dashboard'un gördüğü dar durum kesiti.
///
/// v6: ekranlar artık tüm `GameState`'i dinlemek zorunda değil. Sohbet
/// değiştiğinde dashboard rebuild olmaz; yalnızca profil/görev alanları
/// değiştiğinde yeniden çizilir.
final class DashboardSnapshot {
  const DashboardSnapshot({
    required this.profile,
    required this.setup,
    required this.isCoupleEdition,
    required this.quests,
  });

  final UserProfile? profile;
  final UserSetup? setup;
  final bool isCoupleEdition;
  final List<Quest> quests;

  int get completedCount =>
      quests.where((Quest quest) => quest.isCompleted).length;

  List<Quest> get openQuests =>
      quests.where((Quest quest) => quest.isOpen).toList(growable: false);
}

final Provider<DashboardSnapshot> dashboardSnapshotProvider =
    Provider<DashboardSnapshot>((Ref ref) {
      final ({
        UserProfile? profile,
        UserSetup? setup,
        bool isCouple,
        List<Quest> quests,
      })
      data = ref.watch(
        gameProvider.select(
          (GameState state) => (
            profile: state.profile,
            setup: state.setup,
            isCouple: state.isCoupleEdition,
            quests: state.quests,
          ),
        ),
      );
      return DashboardSnapshot(
        profile: data.profile,
        setup: data.setup,
        isCoupleEdition: data.isCouple,
        quests: data.quests,
      );
    });

/// Haftalık verimlilik düellosu — durum değiştikçe yeniden hesaplanır.
final Provider<CoupleDuelResult> duelProvider = Provider<CoupleDuelResult>((
  Ref ref,
) {
  final GameState state = ref.watch(gameProvider);
  return CoupleEfficiencyEngine.evaluate(
    couple: state.couple,
    partners: state.partners,
  );
});

/// Sıradaki aşk notu (doğum günü üreticisi).
final Provider<String> loveNoteProvider = Provider<String>(
  (Ref ref) => ref.watch(
    gameProvider.select((GameState state) => state.couple.currentLoveNote),
  ),
);
