import '../../domain/entities/entities.dart';
import '../game_mutation.dart';
import '../game_state.dart';

/// Sohbet, anı albümü, dürtme, medya, tepkiler ve tombstone yönetimi.
final class CoupleChatController {
  CoupleChatController(this._game);

  final GameStateAccess _game;

  int _sequence = 0;

  GameState get _state => _game.state;

  // ── Mesaj üretimi ────────────────────────────────────────────────────────

  String _newMessageId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  ChatMessage _appendMessage(ChatMessage message) {
    _game.commit(_state.withCouple(_state.couple.addMessage(message)));
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
        senderId: _state.activePartnerId,
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
        senderId: _state.activePartnerId,
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

  /// Şu anki (yoksa sıradaki) plan bloğunu sohbete görsel kanıt olarak atar.
  ChatMessage? sendScheduleProof({
    String? partnerId,
    String? blockId,
    ChatMessage? replyTo,
  }) {
    final String id = partnerId ?? _state.activePartnerId;
    final DateTime now = DateTime.now();
    final ScheduleBlock? block = blockId != null
        ? _state.couple.blockById(blockId)
        : _state.couple.currentBlockFor(id, now) ??
              _state.couple.nextBlockFor(id, now);
    if (block == null) return null;

    final bool live = block.isActiveAt(now);
    return _appendMessage(
      ChatMessage(
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
        replyToMessageId: replyTo?.id,
        replyPreviewText: replyTo?.preview,
      ),
    );
  }

  // ── Silme / düzenleme / tepkiler ─────────────────────────────────────────

  /// Sohbetten bir mesajı siler ve tombstone bırakır (v6).
  bool deleteMessage(
    String messageId, {
    MutationOrigin origin = MutationOrigin.local,
  }) {
    if (messageId.trim().isEmpty) return false;
    final CoupleState next = _state.couple.deleteMessage(messageId);
    if (identical(next, _state.couple)) return false;
    _game.commit(_state.withCouple(next), origin: origin);
    return true;
  }

  /// Yalnızca aktif partnerin metin mesajını düzenler.
  bool editMessage(String messageId, String text) {
    final ChatMessage? current = _state.couple.messageById(messageId);
    if (current == null || current.hasMedia) return false;
    if (current.senderId != _state.activePartnerId) return false;
    final ChatMessage edited = current.withEdit(text: text, at: DateTime.now());
    if (edited == current) return false;
    _game.commit(_state.withCouple(_state.couple.upsertMessage(edited)));
    return true;
  }

  /// Aktif partner adına emoji tepkisi bırakır/kaldırır.
  bool reactToMessage(String messageId, String emoji) {
    final ChatMessage? current = _state.couple.messageById(messageId);
    if (current == null) return false;
    final ChatMessage reacted = current.toggleReaction(
      emoji: emoji,
      partnerId: _state.activePartnerId,
    );
    if (reacted == current) return false;
    _game.commit(_state.withCouple(_state.couple.upsertMessage(reacted)));
    return true;
  }

  /// Fotoğrafı beğenir/beğeniyi kaldırır (galeri kalbi).
  void likeMessage(String messageId) {
    _game.commit(_state.withCouple(_state.couple.toggleMessageLike(messageId)));
  }

  /// Mesajı yerinde günceller (okundu vb.). Silinmiş mesaj geri dirilmez.
  void patchMessage(ChatMessage message) {
    if (_state.couple.isMessageTombstoned(message.id)) return;
    final ChatMessage? current = _state.couple.messageById(message.id);
    if (current == null || current == message) return;
    _game.commit(_state.withCouple(_state.couple.upsertMessage(message)));
  }

  /// Aktif partner sohbeti okudu → karşı tarafın mesajlarına ✓✓.
  void markConversationRead({String? readerId}) {
    final String reader = readerId ?? _state.activePartnerId;
    final CoupleState next = _state.couple.markMessagesRead(readerId: reader);
    if (identical(next, _state.couple)) return;
    _game.commit(_state.withCouple(next));
  }

  // ── Uzak senkron ─────────────────────────────────────────────────────────

  /// Realtime'dan gelen mesajı yerel duruma işler (id + tombstone dedupe).
  bool receiveRemoteMessage(ChatMessage message) {
    if (_state.couple.isMessageTombstoned(message.id)) return false;
    if (_state.couple.messageById(message.id) != null) return false;
    _game.commit(
      _state.withCouple(_state.couple.addMessage(message)),
      origin: MutationOrigin.remote,
    );
    return true;
  }

  /// Uzak bir mesajın düzenleme/tepki güncellemesini uygular.
  bool mergeRemoteMessageUpdate(ChatMessage message) {
    if (_state.couple.isMessageTombstoned(message.id)) return false;
    final ChatMessage? local = _state.couple.messageById(message.id);
    if (local == null) return receiveRemoteMessage(message);
    // Realtime UPDATE, RPC sonrası sunucunun tam tepki anlık görüntüsüdür.
    // Union yerine sunucu kümesini esas al; böylece bir emoji geri alındığında
    // (toggle off) karşı cihazda da kaybolur.
    final ChatMessage merged = mergeMessage(
      local,
      message,
    ).copyWith(reactions: message.reactions);
    if (merged == local) return false;
    _game.commit(
      _state.withCouple(_state.couple.upsertMessage(merged)),
      origin: MutationOrigin.remote,
    );
    return true;
  }

  /// Geçmişten gelen mesajları yereldeki mesajlarla birleştirir.
  ///
  /// Hiçbir yerel mesaj silinmez; tombstone'lu kimlikler eklenmez.
  int mergeRemoteMessages(
    List<ChatMessage> incoming, {
    MutationOrigin origin = MutationOrigin.remote,
  }) {
    if (incoming.isEmpty) return 0;
    final List<ChatMessage> merged = mergeMessages(
      local: _state.couple.messages,
      remote: incoming,
      tombstones: _state.couple.deletedMessageTombstones,
    );
    if (merged.length == _state.couple.messages.length) return 0;
    final int added = merged.length - _state.couple.messages.length;
    _game.commit(
      _state.withCouple(_state.couple.copyWith(messages: merged)),
      origin: origin,
    );
    return added;
  }

  /// Mesaj listelerini birleştirir: tombstone'lar kazanır, yerel okundu/beğeni
  /// durumu korunur, uzak düzenleme daha yeniyse metni günceller.
  static List<ChatMessage> mergeMessages({
    required List<ChatMessage> local,
    required List<ChatMessage> remote,
    Map<String, DateTime> tombstones = const <String, DateTime>{},
  }) {
    final Map<String, ChatMessage> byId = <String, ChatMessage>{
      for (final ChatMessage message in local)
        if (!tombstones.containsKey(message.id)) message.id: message,
    };
    for (final ChatMessage message in remote) {
      if (tombstones.containsKey(message.id)) continue;
      final ChatMessage? current = byId[message.id];
      byId[message.id] = current == null
          ? message
          : mergeMessage(current, message);
    }
    final List<ChatMessage> merged = byId.values.toList(growable: false);
    merged.sort((ChatMessage a, ChatMessage b) {
      final int byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return merged;
  }

  /// Tek mesajı yerel ve uzak kopyadan birleştirir.
  static ChatMessage mergeMessage(ChatMessage local, ChatMessage remote) {
    ChatMessage base = local;
    final DateTime? remoteEdit = remote.editedAt;
    final DateTime? localEdit = local.editedAt;
    if (remoteEdit != null &&
        (localEdit == null || remoteEdit.isAfter(localEdit))) {
      base = local.copyWith(text: remote.text, editedAt: remoteEdit);
    }
    final Map<String, Set<String>> reactions = <String, Set<String>>{
      for (final MapEntry<String, Set<String>> entry in local.reactions.entries)
        entry.key: <String>{...entry.value},
    };
    for (final MapEntry<String, Set<String>> entry
        in remote.reactions.entries) {
      reactions[entry.key] = <String>{
        ...(reactions[entry.key] ?? const <String>{}),
        ...entry.value,
      };
    }
    return base.copyWith(
      // Okundu/beğeni cihaz üstünde daha güncel olabilir; yerel kazanır.
      isRead: local.isRead || remote.isRead,
      isLiked: local.isLiked,
      reactions: reactions,
    );
  }

  // ── Dürtme / aşk notları / görev paylaşımı ───────────────────────────────

  /// Dürtme spam'ini önleyen bekleme süresi.
  static const Duration nudgeCooldown = Duration(minutes: 1);

  /// Son dürtmeden bu yana kalan bekleme (0 → gönderilebilir).
  Duration nudgeCooldownRemaining({String? partnerId}) {
    final String me = partnerId ?? _state.activePartnerId;
    DateTime? last;
    for (final ChatMessage message in _state.couple.messages) {
      if (message.kind != ChatMessageKind.nudge) continue;
      if (message.senderId != me) continue;
      if (last == null || message.createdAt.isAfter(last)) {
        last = message.createdAt;
      }
    }
    if (last == null) return Duration.zero;
    final Duration remaining = nudgeCooldown - DateTime.now().difference(last);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Partnerine dürtme gönderir ve küçük bir disiplin XP'si kazanır.
  ///
  /// Bekleme süresi dolmadıysa `null` döner (UI kalan süreyi gösterir).
  ChatMessage? nudgePartner() {
    if (nudgeCooldownRemaining().inSeconds > 0) return null;
    final String me = _state.activePartnerId;
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
    );
    _game.awardPartner(
      partnerId: me,
      stat: StatKey.willpower,
      xp: CoupleState.nudgeXp,
      at: DateTime.now(),
    );
    return message;
  }

  /// Üreticideki aşk notunu gönderip bir sonrakine geçer.
  ChatMessage? sendLoveNote() {
    final String note = _state.couple.currentLoveNote;
    if (note.isEmpty) return null;
    final ChatMessage message = _appendMessage(
      ChatMessage(
        id: _newMessageId('love'),
        senderId: _state.activePartnerId,
        createdAt: DateTime.now(),
        text: note,
        kind: ChatMessageKind.loveNote,
      ),
    );
    _game.commit(_state.withCouple(_state.couple.cycleLoveNote()));
    return message;
  }

  /// Duygu kapsüllerinden seçilen metni aşk notu olarak sohbete gönderir.
  ChatMessage? sendLoveMessage(String text) {
    final String note = text.trim();
    if (note.isEmpty) return null;
    return _appendMessage(
      ChatMessage(
        id: _newMessageId('love'),
        senderId: _state.activePartnerId,
        createdAt: DateTime.now(),
        text: note,
        kind: ChatMessageKind.loveNote,
      ),
    );
  }

  /// Üretici imlecini kaydırmadan sonraki notu gösterir.
  void cycleLoveNote() {
    _game.commit(_state.withCouple(_state.couple.cycleLoveNote()));
  }

  /// Tamamlanan görevi sohbette paylaşır (rozetli balon).
  ChatMessage? shareQuest(Quest quest, {int earnedPoints = 0}) =>
      _appendMessage(
        ChatMessage(
          id: _newMessageId('quest'),
          senderId: _state.activePartnerId,
          createdAt: DateTime.now(),
          text: '${quest.effectiveTitle} görevini tamamladım!',
          questBadgeTitle: quest.effectiveTitle,
          earnedPoints: earnedPoints,
          kind: ChatMessageKind.questShare,
        ),
      );
}
