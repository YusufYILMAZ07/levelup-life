import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_store.dart';
import '../domain/entities/entities.dart';
import '../domain/services/services.dart';
import '../services/app_settings.dart';
import 'couple_bootstrap.dart';
import 'game_state.dart';

/// Gelişim rubriğinde bir puanlamanın sonucu (kutlama/özet için).
final class RubricOutcome {
  const RubricOutcome({
    required this.partnerId,
    required this.pillar,
    required this.score,
    required this.xpGained,
    required this.leveledUp,
    required this.synergyXp,
    required this.totalToday,
  });

  final String partnerId;
  final StatKey pillar;
  final int score;

  /// Bu dokunuşla kazanılan XP (aynı gün tekrar puanlamada 0).
  final int xpGained;

  final bool leveledUp;

  /// Sinerji tetiklendiyse her iki partnerin kazandığı XP.
  final int synergyXp;

  /// Partnerin bugünkü toplam rubrik puanı (0..15).
  final int totalToday;

  bool get hasSynergy => synergyXp > 0;

  @override
  String toString() =>
      'RubricOutcome($partnerId · ${pillar.code} = $score · +$xpGained XP · '
      'sinerji: $synergyXp)';
}

/// Plan bloğu tamamlamanın sonucu (kutlama/snackbar için).
final class ScheduleOutcome {
  const ScheduleOutcome({
    required this.partnerId,
    required this.block,
    required this.xpGained,
    required this.leveledUp,
    required this.alreadyCompleted,
  });

  final String partnerId;
  final ScheduleBlock block;

  /// Bu dokunuşla kazanılan XP (gün içinde tekrar tamamlamada 0).
  final int xpGained;

  final bool leveledUp;

  /// Blok bugün daha önce tamamlanmış mıydı?
  final bool alreadyCompleted;

  @override
  String toString() =>
      'ScheduleOutcome($partnerId · ${block.title} · +$xpGained XP)';
}

/// Oyun döngüsünün tek yöneticisi.
///
/// Tüm mutasyonlar burada toplanır: onboarding, görev tamamlama, gelişim
/// rubriği, hızlı eylemler, partner geçişi, sohbet/fotoğraf, bucket list ve
/// haftalık bahis. Her değişiklikten sonra durum diske yazılır.
final class GameController extends Notifier<GameState> {
  @override
  GameState build() {
    final GameStore store = ref.watch(gameStoreProvider);
    return store.load() ?? const GameState();
  }

  // ── Onboarding ───────────────────────────────────────────────────────────

  /// 4 adımlı sihirbazın sonunda çağrılır.
  ///
  /// Profil + ilk günün kişiselleştirilmiş görevleri tek hamlede üretilir.
  /// Çift sürümünde yalnızca **aktif partner** güncellenir.
  void completeOnboarding(UserSetup setup) {
    final DateTime now = DateTime.now();
    final UserProfile profile = setup.toProfile(now: now);
    final List<Quest> quests = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    if (state.partners.isEmpty) {
      state = GameState(
        setup: setup,
        profile: profile,
        quests: quests,
        couple: state.couple,
      );
    } else {
      state = state.copyWith(setup: setup, profile: profile, quests: quests);
    }
    _persist();
  }

  // ── Partner geçişi ───────────────────────────────────────────────────────

  /// Üst bardaki segmentten partner değiştirir.
  ///
  /// Cihaz sahibi kilidi açıksa yalnızca kilitli profile geçilebilir; böylece
  /// yanlış isimle mesaj / puan girilmesi engellenir.
  void switchPartner(String partnerId) {
    final AppSettings settings = ref.read(appSettingsProvider);
    if (settings.lockToDeviceOwner && partnerId != settings.deviceRole) return;
    final GameState next = state.activatePartner(partnerId);
    if (identical(next, state)) return;
    // Telefonu devralan partner, karşı taraftan gelen mesajları görmüş olur.
    state = next.withCouple(next.couple.markMessagesRead(readerId: partnerId));
    _persist();
  }

  /// Yusuf ↔ Ceyda geçişi.
  void toggleActivePartner() =>
      switchPartner(CouplePartner.other(state.activePartnerId));

  /// Cihaz sahibi kilidi açıksa aktif profili sahibe sabitler.
  void enforceDeviceOwner(AppSettings settings) {
    if (!settings.lockToDeviceOwner || !state.isCoupleEdition) return;
    if (!CouplePartner.isValid(settings.deviceRole)) return;
    if (state.activePartnerId == settings.deviceRole) return;
    state = state.activatePartner(settings.deviceRole);
    _persist();
  }

  /// Üst bardaki canlı durum seçimi.
  void setLiveStatus(LiveStatus status, {String? partnerId}) {
    final String id = partnerId ?? state.activePartnerId;
    if (state.couple.liveStatusOf(id) == status) return;
    state = state.withCouple(state.couple.withLiveStatus(id, status));
    _persist();
  }

  // ── Görev döngüsü ────────────────────────────────────────────────────────

  /// Görevi tamamlar; kutlama/snackbar için [XpAward] döner.
  ///
  /// XP = görevin taban XP'si × (1 + arketip bonusu). Bonus UI'da ayrıca
  /// gösterilir, böylece "+%15" bilgisi şeffaf kalır.
  XpAward? completeQuest(String questId) {
    final UserProfile? profile = state.profile;
    if (profile == null) return null;
    final int index = state.quests.indexWhere(
      (Quest quest) => quest.id == questId,
    );
    if (index < 0) return null;
    final Quest quest = state.quests[index];
    if (quest.isCompleted) return null;

    final DateTime now = DateTime.now();
    final int awarded = xpForQuest(profile, quest);
    final XpAward result = profile.completeQuest(
      stat: quest.stat,
      xp: awarded,
      at: now,
    );
    final List<Quest> quests = <Quest>[...state.quests];
    quests[index] = quest.complete(at: now);

    state = state
        .copyWith(profile: result.profile, quests: quests)
        .withCouple(
          state.couple.recordQuestCompletion(
            partnerId: state.activePartnerId,
            day: now,
          ),
        );
    _persist();
    return result;
  }

  /// Bu görev tamamlandığında gerçekten verilecek XP.
  int xpForQuest(UserProfile profile, Quest quest) => XpEngine.applyBonus(
    quest.effectiveBaseXp,
    profile.archetype.bonusFor(quest.stat),
  );

  /// Modalden eklenen özel görev.
  void addQuest(Quest quest) {
    state = state.copyWith(quests: <Quest>[...state.quests, quest]);
    _persist();
  }

  void removeQuest(String questId) {
    state = state.copyWith(
      quests: state.quests
          .where((Quest quest) => quest.id != questId)
          .toList(growable: false),
    );
    _persist();
  }

  /// Günün görevlerini yeniden üretir; kullanıcının kendi ekledikleri korunur.
  void refreshQuests() {
    final UserSetup? setup = state.setup;
    final UserProfile? profile = state.profile;
    if (setup == null || profile == null) return;
    final DateTime now = DateTime.now();
    final List<Quest> daily = QuestGenerator.dailyQuests(
      setup: setup,
      now: now,
      energyMode: profile.energyMode,
    );
    state = state.copyWith(quests: daily);
    _persist();
  }

  // ── Enerji modu ──────────────────────────────────────────────────────────

  void setEnergyMode(EnergyMode mode) {
    final UserProfile? profile = state.profile;
    if (profile == null || profile.energyMode == mode) return;
    state = state.copyWith(
      profile: profile.withEnergyMode(mode),
      quests: <Quest>[
        for (final Quest quest in state.quests) quest.applyEnergyMode(mode),
      ],
    );
    _persist();
  }

  // ── Gelişim rubriği (1-2-3) ──────────────────────────────────────────────

  /// Bir yaşam alanına 1-2-3 puanı verir.
  ///
  /// Aynı gün ilk puanlamada XP kazanılır; düzeltmeler XP üretmez
  /// (puan avcılığını engeller). İki taraf da aynı alanda 2+ puana ulaşırsa
  /// sinerji bonusu **her iki** partnere verilir.
  RubricOutcome ratePillar({
    required StatKey pillar,
    required int score,
    String? partnerId,
  }) {
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final int previous = state.couple.rubricScore(id, pillar, now);
    final CoupleState nextCouple = state.couple.ratePillar(
      partnerId: id,
      pillar: pillar,
      score: score,
      day: now,
    );

    final int gained = previous > 0 || score <= 0
        ? 0
        : DevelopmentRubric.xpFor(score);
    bool leveledUp = false;
    GameState next = state;

    if (gained > 0) {
      final PartnerData data = state.partnerData(id) ?? state.activePartner;
      final UserProfile? profile = data.profile;
      if (profile != null) {
        final XpAward award = profile.completeQuest(
          stat: pillar,
          xp: gained,
          at: now,
        );
        leveledUp = award.leveledUp;
        next = next.withPartner(id, data.copyWith(profile: award.profile));
      }
    }

    next = next.withCouple(nextCouple);

    int synergyXp = 0;
    if (score >= 2 &&
        CoupleEfficiencyEngine.shouldAwardSynergy(next.couple, pillar, now)) {
      next = next
          .withCouple(next.couple.markSynergy(pillar: pillar, day: now))
          .grantBoth(
            stat: pillar,
            xp: CoupleEfficiencyEngine.synergyXp,
            at: now,
          );
      synergyXp = CoupleEfficiencyEngine.synergyXp;
    }

    state = next;
    _persist();
    return RubricOutcome(
      partnerId: id,
      pillar: pillar,
      score: score,
      xpGained: gained,
      leveledUp: leveledUp,
      synergyXp: synergyXp,
      totalToday: next.couple.rubricTotalOn(id, now),
    );
  }

  // ── Hızlı bonus eylemler ─────────────────────────────────────────────────

  /// Gelişim sekmesindeki tek dokunuşluk eylem.
  XpAward? quickAction(QuickAction action, {String? partnerId}) {
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.fromQuickAction(
      action: action,
      partnerId: id,
      at: now,
    );
    return _awardPartner(
      partnerId: id,
      stat: action.stat,
      xp: action.points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  /// Kullanıcının kendi yazdığı bonus eylem.
  XpAward? addCustomBonus({
    required String title,
    required int points,
    required StatKey stat,
    String? partnerId,
  }) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || points <= 0) return null;
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final BonusActionLog log = BonusActionLog.custom(
      title: trimmed,
      points: points,
      stat: stat,
      partnerId: id,
      at: now,
    );
    return _awardPartner(
      partnerId: id,
      stat: stat,
      xp: points,
      at: now,
      then: (GameState current) =>
          current.withCouple(current.couple.addBonusAction(log)),
    );
  }

  // ── Haftalık plan (senkron program) ──────────────────────────────────────

  /// Plan bloğunu **bugün için** tamamlar.
  ///
  /// Partnerin bloğun kategorisine karşılık gelen statına +25 XP verilir ve
  /// sohbete kanıt rozeti düşülür. Aynı blok aynı gün ikinci kez
  /// tamamlanırsa XP verilmez (puan avcılığını engeller).
  ScheduleOutcome? completeScheduleBlock(String blockId, {DateTime? day}) {
    final ScheduleBlock? block = state.couple.blockById(blockId);
    if (block == null) return null;

    final DateTime now = day ?? DateTime.now();
    final bool alreadyCompleted = block.isCompletedOn(now);
    if (alreadyCompleted) {
      final CoupleState reset = state.couple.completeScheduleBlock(
        blockId,
        now,
      );
      if (!identical(reset, state.couple)) {
        state = state.withCouple(reset);
        _persist();
      }
      return ScheduleOutcome(
        partnerId: block.partnerId,
        block: block,
        xpGained: 0,
        leveledUp: false,
        alreadyCompleted: true,
      );
    }

    final ChatMessage badge = ChatMessage(
      id: _newMessageId('plan'),
      senderId: block.partnerId,
      createdAt: now,
      text: '${block.title} planını tamamladım! 💪',
      questBadgeTitle: block.title,
      earnedPoints: SchedulePlanner.completionXp,
      kind: ChatMessageKind.questShare,
    );

    final XpAward? award = _awardPartner(
      partnerId: block.partnerId,
      stat: block.category.stat,
      xp: SchedulePlanner.completionXp,
      at: now,
      then: (GameState current) => current.withCouple(
        current.couple.completeScheduleBlock(blockId, now).addMessage(badge),
      ),
    );
    if (award == null) return null;

    return ScheduleOutcome(
      partnerId: block.partnerId,
      block: block,
      xpGained: award.xpGained,
      leveledUp: award.leveledUp,
      alreadyCompleted: false,
    );
  }

  /// Yeni plan blokları ekler (💑 "İkimiz Birden" için iki blok birden).
  int addScheduleBlocks(Iterable<ScheduleBlock> blocks) {
    final List<ScheduleBlock> valid = blocks
        .where(
          (ScheduleBlock block) =>
              block.title.trim().isNotEmpty &&
              block.endMinutes > block.startMinutes,
        )
        .toList(growable: false);
    if (valid.isEmpty) return 0;
    state = state.withCouple(state.couple.addScheduleBlocks(valid));
    _persist();
    return valid.length;
  }

  void removeScheduleBlock(String blockId) {
    final CoupleState next = state.couple.removeScheduleBlock(blockId);
    if (identical(next, state.couple)) return;
    state = state.withCouple(next);
    _persist();
  }

  /// Şu anki (yoksa sıradaki) plan bloğunu sohbete görsel kanıt olarak atar.
  ///
  /// Kanıt kartı, bloğun kategorisine uygun gradient görsel + saat rozetiyle
  /// gönderilir; böylece albümde "Plan & Görev Kanıtları" filtresinde görünür.
  ChatMessage? sendScheduleProof({String? partnerId, String? blockId}) {
    final String id = partnerId ?? state.activePartnerId;
    final DateTime now = DateTime.now();
    final ScheduleBlock? block = blockId != null
        ? state.couple.blockById(blockId)
        : state.couple.currentBlockFor(id, now) ??
              state.couple.nextBlockFor(id, now);
    if (block == null) return null;

    final bool live = block.isActiveAt(now);
    final ChatMessage message = ChatMessage(
      id: _newMessageId('proof'),
      senderId: block.partnerId,
      createdAt: now,
      photoDataOrUrl: block.category.presetSource,
      photoCaption:
          '${block.weekdayShortLabel} ${block.timeRangeLabel} • '
          '${block.category.emoji} ${block.category.shortLabel} Kanıtı',
      questBadgeTitle: block.title,
      text: live
          ? '${block.category.emoji} ${block.category.shortLabel} · '
                'şu an kanıt paylaşıldı'
          : 'Sıradaki plan · ${block.weekdayShortLabel} '
                '${block.timeRangeLabel}',
      kind: ChatMessageKind.proof,
    );
    return _appendMessage(message);
  }

  // ── Ödül kapsülleri ──────────────────────────────────────────────────────

  /// Eşiği dolmuş kapsülü açar. Kilitliyse `false` döner.
  bool openRewardCapsule(String capsuleId) {
    final CoupleState next = state.couple.openCapsule(capsuleId);
    if (identical(next, state.couple)) return false;
    state = state.withCouple(next);
    _persist();
    return true;
  }

  /// Yusuf & Ceyda'nın kendi ödül kapsülünü ekler.
  RewardCapsule? addRewardCapsule({
    required String title,
    required int requiredPoints,
    String emoji = '🎁',
    String description = '',
    String rewardMessage = '',
  }) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || requiredPoints <= 0) return null;
    final String cleanEmoji = emoji.trim().isEmpty ? '🎁' : emoji.trim();
    final RewardCapsule capsule = RewardCapsule(
      id: 'capsule-${DateTime.now().microsecondsSinceEpoch}',
      title: trimmed,
      emoji: cleanEmoji,
      description: description.trim(),
      requiredPoints: requiredPoints,
      rewardMessage: rewardMessage.trim().isEmpty
          ? trimmed
          : rewardMessage.trim(),
      isCustom: true,
    );
    state = state.withCouple(state.couple.addCapsule(capsule));
    _persist();
    return capsule;
  }

  // ── Bucket list (ortak hedefler) ─────────────────────────────────────────

  /// Ortak hedefi açar/kapatır. Tamamlanınca iki tarafa Co-Op XP gelir.
  bool toggleBucketGoal(String goalId) {
    BucketGoal? target;
    for (final BucketGoal goal in state.couple.bucketGoals) {
      if (goal.id == goalId) target = goal;
    }
    if (target == null) return false;

    final DateTime now = DateTime.now();
    final bool completing = !target.isDone;
    GameState next = state.withCouple(state.couple.toggleBucketGoal(goalId));
    if (completing) {
      next = next.grantBoth(
        stat: StatKey.willpower,
        xp: target.rewardPoints,
        at: now,
      );
    }
    state = next;
    _persist();
    return completing;
  }

  // ── Sohbet & anı albümü ──────────────────────────────────────────────────

  String _newMessageId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage _appendMessage(ChatMessage message, {bool persist = true}) {
    state = state.withCouple(state.couple.addMessage(message));
    if (persist) _persist();
    return message;
  }

  /// Aktif partner adına metin mesajı gönderir.
  ///
  /// [replyTo] verilirse balonun içinde alıntı şeridi gösterilir.
  ChatMessage? sendMessage(
    String text, {
    ChatMessageKind kind = ChatMessageKind.text,
    ChatMessage? replyTo,
  }) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return _appendMessage(
      ChatMessage(
        id: _newMessageId('msg'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        text: trimmed,
        kind: kind,
        replyToMessageId: replyTo?.id,
        replyPreviewText: replyTo?.preview,
      ),
    );
  }

  /// Anı albümüne fotoğraf ekler (`preset:…`, `data:image/…` veya `https://`).
  ChatMessage? sendPhoto({
    required String photoDataOrUrl,
    String caption = '',
    ChatMessage? replyTo,
  }) => sendMedia(
    mediaPathOrUrl: photoDataOrUrl,
    mediaType: ChatMediaType.image,
    caption: caption,
    replyTo: replyTo,
  );

  /// Cihazdan seçilen fotoğraf / videoyu sohbete ve anı albümüne ekler.
  ChatMessage? sendMedia({
    required String mediaPathOrUrl,
    required ChatMediaType mediaType,
    String caption = '',
    String? thumbnailPath,
    int durationSeconds = 0,
    ChatMessage? replyTo,
  }) {
    final String source = mediaPathOrUrl.trim();
    if (source.isEmpty || mediaType == ChatMediaType.none) return null;
    final String cleanCaption = caption.trim();
    return _appendMessage(
      ChatMessage(
        id: _newMessageId(mediaType == ChatMediaType.video ? 'video' : 'photo'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        photoDataOrUrl: source,
        photoCaption: cleanCaption.isEmpty ? null : cleanCaption,
        kind: ChatMessageKind.photo,
        mediaType: mediaType,
        thumbnailPath: thumbnailPath,
        durationSeconds: durationSeconds,
        replyToMessageId: replyTo?.id,
        replyPreviewText: replyTo?.preview,
      ),
    );
  }

  /// Sohbetten bir mesajı siler (yanıt şeritleri güvenli kalır).
  void deleteMessage(String messageId) {
    final CoupleState next = state.couple.deleteMessage(messageId);
    if (identical(next, state.couple)) return;
    state = state.withCouple(next);
    _persist();
  }

  /// Aktif partner sohbeti okudu → karşı tarafın mesajlarına ✓✓.
  void markConversationRead({String? readerId}) {
    final String reader = readerId ?? state.activePartnerId;
    final CoupleState next = state.couple.markMessagesRead(readerId: reader);
    if (identical(next, state.couple)) return;
    state = state.withCouple(next);
    _persist();
  }

  /// Supabase Realtime'dan gelen mesajı yerel duruma işler (id ile dedupe).
  /// Yeni mesaj eklendiyse `true` döner.
  bool receiveRemoteMessage(ChatMessage message) {
    if (state.couple.messageById(message.id) != null) return false;
    state = state.withCouple(state.couple.addMessage(message));
    _persist();
    return true;
  }

  /// Geçmişten gelen mesajları yereldeki mesajlarla birleştirir.
  ///
  /// Hiçbir yerel mesaj silinmez; yalnızca yeni id'ler eklenir ve liste
  /// kronolojik sıraya girer. Eklenen mesaj sayısını döner.
  int mergeRemoteMessages(List<ChatMessage> incoming) {
    if (incoming.isEmpty) return 0;
    final List<ChatMessage> merged = _mergeMessages(
      state.couple.messages,
      incoming,
    );
    if (merged.length == state.couple.messages.length) return 0;
    final int added = merged.length - state.couple.messages.length;
    state = state.withCouple(state.couple.copyWith(messages: merged));
    _persist();
    return added;
  }

  /// Karşı telefondan gelen tam durumu **tahribatsız** uygular.
  ///
  /// Mesajlar, kapsüller ve plan blokları birleştirilir; rubrik/puan gibi
  /// skor alanları karşı cihazın daha güncel değerlerini alır.
  void applyRemoteState(GameState remote) {
    final CoupleState local = state.couple;
    final CoupleState merged = remote.couple.copyWith(
      messages: _mergeMessages(local.messages, remote.couple.messages),
      rewardCapsules: _mergeCapsules(
        local.rewardCapsules,
        remote.couple.rewardCapsules,
      ),
      scheduleBlocks: _mergeSchedules(
        local.scheduleBlocks,
        remote.couple.scheduleBlocks,
      ),
      bucketGoals: remote.couple.bucketGoals.isEmpty
          ? local.bucketGoals
          : remote.couple.bucketGoals,
      customLoveNotes: <String>{
        ...local.customLoveNotes,
        ...remote.couple.customLoveNotes,
      }.toList(growable: false),
    );
    state = remote.withCouple(merged);
    _persist();
  }

  static List<ChatMessage> _mergeMessages(
    List<ChatMessage> local,
    List<ChatMessage> remote,
  ) {
    final Map<String, ChatMessage> byId = <String, ChatMessage>{
      for (final ChatMessage message in local) message.id: message,
    };
    for (final ChatMessage message in remote) {
      byId.putIfAbsent(message.id, () => message);
    }
    final List<ChatMessage> merged = byId.values.toList(growable: false);
    merged.sort((ChatMessage a, ChatMessage b) {
      final int byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return merged;
  }

  static List<RewardCapsule> _mergeCapsules(
    List<RewardCapsule> local,
    List<RewardCapsule> remote,
  ) {
    final Map<String, RewardCapsule> merged = <String, RewardCapsule>{
      for (final RewardCapsule capsule in remote) capsule.id: capsule,
    };
    for (final RewardCapsule capsule in local) {
      final RewardCapsule? other = merged[capsule.id];
      if (other == null) {
        merged[capsule.id] = capsule;
      } else if (capsule.isOpened && !other.isOpened) {
        merged[capsule.id] = other.copyWith(
          isOpened: true,
          openedAt: capsule.openedAt,
        );
      }
    }
    return merged.values.toList(growable: false);
  }

  static List<ScheduleBlock> _mergeSchedules(
    List<ScheduleBlock> local,
    List<ScheduleBlock> remote,
  ) {
    final Map<String, ScheduleBlock> merged = <String, ScheduleBlock>{
      for (final ScheduleBlock block in remote) block.id: block,
    };
    for (final ScheduleBlock block in local) {
      merged.putIfAbsent(block.id, () => block);
    }
    return merged.values.toList(growable: false);
  }

  /// Mesajı beğeni durumunu değiştirmeden yerinde günceller (okundu vb.).
  void patchMessage(ChatMessage message) {
    final ChatMessage? current = state.couple.messageById(message.id);
    if (current == null || current == message) return;
    state = state.withCouple(state.couple.upsertMessage(message));
    _persist();
  }

  /// Tamamlanan görevi sohbette paylaşır (rozetli balon).
  ChatMessage? shareQuest(Quest quest, {int earnedPoints = 0}) =>
      _appendMessage(
        ChatMessage(
          id: _newMessageId('quest'),
          senderId: state.activePartnerId,
          createdAt: DateTime.now(),
          text: '${quest.effectiveTitle} görevini tamamladım!',
          questBadgeTitle: quest.effectiveTitle,
          earnedPoints: earnedPoints,
          kind: ChatMessageKind.questShare,
        ),
      );

  /// Fotoğrafı beğenir/beğeniyi kaldırır (galeri kalbi).
  void likeMessage(String messageId) {
    state = state.withCouple(state.couple.toggleMessageLike(messageId));
    _persist();
  }

  /// Partnerine dürtme gönderir ve küçük bir disiplin XP'si kazanır.
  ChatMessage? nudgePartner() {
    final String me = state.activePartnerId;
    final String target = CouplePartner.other(me);
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('nudge'),
        senderId: me,
        createdAt: DateTime.now(),
        text:
            '💫 ${CouplePartner.displayName(me)} → '
            '${CouplePartner.displayName(target)}: hadi bir puan daha!',
        kind: ChatMessageKind.nudge,
      ),
      persist: false,
    );
    _awardPartner(
      partnerId: me,
      stat: StatKey.willpower,
      xp: CoupleState.nudgeXp,
      at: DateTime.now(),
    );
    return message;
  }

  /// Üreticideki aşk notunu gönderip bir sonrakine geçer.
  ChatMessage? sendLoveNote() {
    final String note = state.couple.currentLoveNote;
    if (note.isEmpty) return null;
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('love'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        text: note,
        kind: ChatMessageKind.loveNote,
      ),
      persist: false,
    );
    state = state.withCouple(state.couple.cycleLoveNote());
    _persist();
    return message;
  }

  /// Duygu kapsüllerinden seçilen metni aşk notu olarak sohbete gönderir.
  ///
  /// [sendLoveNote] üreticiyi ilerletir; bu metot ise kullanıcının seçtiği
  /// metni olduğu gibi gönderir.
  ChatMessage? sendLoveMessage(String text) {
    final String note = text.trim();
    if (note.isEmpty) return null;
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('love'),
        senderId: state.activePartnerId,
        createdAt: DateTime.now(),
        text: note,
        kind: ChatMessageKind.loveNote,
      ),
      persist: false,
    );
    _persist();
    return message;
  }

  /// Üretici imlecini kaydırmadan sonraki notu gösterir.
  void cycleLoveNote() {
    state = state.withCouple(state.couple.cycleLoveNote());
    _persist();
  }

  /// Doğum günü için kişisel not ekler.
  void addLoveNote(String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) return;
    state = state.withCouple(state.couple.addLoveNote(trimmed));
    _persist();
  }

  /// Yusuf'un doğum günü mektubunu kişiselleştirir.
  void setBirthdayMessage(String message) {
    final CoupleState next = state.couple.withBirthdayMessage(message);
    if (identical(next, state.couple)) return;
    state = state.withCouple(next);
    _persist();
  }

  // ── Haftalık bahis ───────────────────────────────────────────────────────

  void setStake(DuelStake stake) {
    if (state.couple.stake == stake) return;
    state = state.withCouple(state.couple.withStake(stake));
    _persist();
  }

  // ── Sıfırlama ────────────────────────────────────────────────────────────

  /// "Hedeflerimi sıfırla" — onboarding'e geri döner ve tüm ilerlemeyi siler.
  Future<void> resetJourney() async {
    state = const GameState();
    await ref.read(gameStoreProvider).clear();
  }

  /// Çift sürümünü tohum verisiyle yeniden başlatır (demo/hediye modu).
  Future<void> restartCoupleJourney() async {
    final GameState seeded = CoupleBootstrap.initialState();
    state = seeded;
    await ref.read(gameStoreProvider).save(seeded);
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  /// Partnerin profilini XP ile ödüller ve isteğe bağlı ek mutasyon uygular.
  XpAward? _awardPartner({
    required String partnerId,
    required StatKey stat,
    required int xp,
    required DateTime at,
    GameState Function(GameState current)? then,
  }) {
    final PartnerData data =
        state.partnerData(partnerId) ??
        (partnerId == state.activePartnerId
            ? state.activePartner
            : const PartnerData());
    final UserProfile? profile = data.profile;
    if (profile == null || xp <= 0) return null;

    final XpAward award = profile.completeQuest(stat: stat, xp: xp, at: at);
    GameState next = state.withPartner(
      partnerId,
      data.copyWith(profile: award.profile),
    );
    if (then != null) next = then(next);
    state = next;
    _persist();
    return award;
  }

  void _persist() {
    final GameStore store = ref.read(gameStoreProvider);
    final GameState snapshot = state;
    // Web'de localStorage kotası dolsa bile uygulama çalışmaya devam eder.
    unawaited(_saveQuietly(store, snapshot));
  }

  Future<void> _saveQuietly(GameStore store, GameState snapshot) async {
    try {
      await store.save(snapshot);
    } catch (_) {
      // Disk / kota hataları kullanıcı akışını kesmez.
    }
  }
}

/// Tüm ekranların dinlediği tek provider.
final NotifierProvider<GameController, GameState> gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Kısayol: onboarding tamamlandı mı?
final Provider<bool> isOnboardedProvider = Provider<bool>(
  (Ref ref) => ref.watch(gameProvider).isOnboarded,
);

/// Kısayol: aktif profil (onboarding öncesi `null`).
final Provider<UserProfile?> profileProvider = Provider<UserProfile?>(
  (Ref ref) => ref.watch(gameProvider).profile,
);

/// Aktif partnerin tam verisi (görevler dahil).
final Provider<PartnerData> activePartnerProvider = Provider<PartnerData>(
  (Ref ref) => ref.watch(gameProvider).activePartner,
);

/// Ekranda olmayan partnerin profili (üst bar / karşılaştırma kartları).
final Provider<UserProfile?> partnerProfileProvider = Provider<UserProfile?>((
  Ref ref,
) {
  final GameState state = ref.watch(gameProvider);
  return state.partnerData(CouplePartner.other(state.activePartnerId))?.profile;
});

/// Ortak çift durumu (sohbet, rubrik, bucket list).
final Provider<CoupleState> coupleStateProvider = Provider<CoupleState>(
  (Ref ref) => ref.watch(gameProvider).couple,
);

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
  (Ref ref) => ref.watch(gameProvider).couple.currentLoveNote,
);
