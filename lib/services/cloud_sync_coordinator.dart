import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_mutation.dart';
import '../application/game_state.dart';
import '../domain/entities/entities.dart';
import 'app_settings.dart';
import 'message_delivery_policy.dart';
import 'push_service.dart';
import 'supabase_sync_service.dart';
import 'sync_outbox.dart';

/// Testlerde sahte push gönderici enjekte etmek için.
typedef ChatPushDispatcher =
    Future<PushResult> Function({
      required AppSettings settings,
      required ChatMessage message,
    });

/// Ayarlar ekranında gösterilen canlı bağlantı durumu.
final class SyncStatusInfo {
  const SyncStatusInfo({
    this.status = SyncStatus.disabled,
    this.message = 'Yerel mod · bulut kapalı',
  });

  final SyncStatus status;
  final String message;

  bool get isConnected => status == SyncStatus.connected;

  bool get isBusy => status == SyncStatus.connecting;
}

final class SyncStatusController extends Notifier<SyncStatusInfo> {
  @override
  SyncStatusInfo build() => const SyncStatusInfo();

  void set(SyncStatus status, String message) {
    state = SyncStatusInfo(status: status, message: message);
  }
}

final NotifierProvider<SyncStatusController, SyncStatusInfo>
syncStatusProvider = NotifierProvider<SyncStatusController, SyncStatusInfo>(
  SyncStatusController.new,
);

/// Partnerin çevrimiçi / yazıyor durumu (Supabase Presence + broadcast).
final class SyncPresence {
  const SyncPresence({this.partnerOnline = false, this.partnerTyping = false});

  final bool partnerOnline;
  final bool partnerTyping;

  SyncPresence copyWith({bool? partnerOnline, bool? partnerTyping}) =>
      SyncPresence(
        partnerOnline: partnerOnline ?? this.partnerOnline,
        partnerTyping: partnerTyping ?? this.partnerTyping,
      );
}

final class SyncPresenceController extends Notifier<SyncPresence> {
  @override
  SyncPresence build() => const SyncPresence();

  void setOnline(bool online) {
    state = state.copyWith(
      partnerOnline: online,
      partnerTyping: online ? state.partnerTyping : false,
    );
  }

  void setTyping(bool typing) {
    state = state.copyWith(partnerTyping: typing && state.partnerOnline);
  }
}

final NotifierProvider<SyncPresenceController, SyncPresence>
syncPresenceProvider = NotifierProvider<SyncPresenceController, SyncPresence>(
  SyncPresenceController.new,
);

/// Yerel durum ↔ Supabase köprüsü.
///
/// v6 tasarımı:
/// * **Kalıcı Outbox:** bekleyen mesajlar ve "kirli" durum diskte tutulur;
///   uygulama çevrimdışıyken kapansa bile bağlantı gelince gönderilir.
/// * **Race condition yok:** `_applyingRemote` için 700–900 ms sabit Timer
///   kaldırıldı. Mesajların ve durumun buluta geri gönderilip gönderilmeyeceği
///   `MutationOrigin` etiketi + monoton `localRevision` ile deterministik
///   biçimde belirlenir.
/// * **Tekrar gönderim yok:** her mesajın `syncedMessageIds` durumu kalıcıdır;
///   `_backfill` yalnızca gerçekten senkronize edilmemiş son 200 mesajı yükler.
final class CloudSyncCoordinator {
  CloudSyncCoordinator(
    this._ref, {
    CloudSyncBackend? backend,
    SyncOutbox? outbox,
    ChatPushDispatcher? pushDispatcher,
  }) : _outbox = outbox,
       _pushDispatcher =
           pushDispatcher ?? PushService.instance.sendChatMessage {
    _service =
        backend ??
        SupabaseSyncService(
          callbacks: SyncCallbacks(
            onRemoteMessage: _onRemoteMessage,
            onRemoteMessageUpdate: _onRemoteMessageUpdate,
            onRemoteMessageDeleted: _onRemoteMessageDeleted,
            onRemoteState: _onRemoteState,
            onRemoteHistory: _onRemoteHistory,
            onStatusChanged: _onStatusChanged,
            onPresenceChanged: _onPresenceChanged,
            onTypingChanged: _onTypingChanged,
          ),
        );
  }

  final Ref _ref;
  late final CloudSyncBackend _service;

  final ChatPushDispatcher _pushDispatcher;

  SyncOutbox? _outbox;
  final Set<String> _knownMessageIds = <String>{};
  final Set<String> _syncedIds = <String>{};
  final Set<String> _pushedIds = <String>{};
  final Set<String> _pendingIds = <String>{};
  final Set<String> _pushRequestedIds = <String>{};
  final Set<String> _pushInFlight = <String>{};
  final Set<String> _knownTombstones = <String>{};
  final Set<String> _pendingDeletes = <String>{};
  Future<SyncOutbox>? _outboxFuture;
  Timer? _pushDebounce;
  Future<void>? _statePushInFlight;
  int _pushedRevision = 0;
  SyncConfig? _active;

  bool get isConnected => _service.isConnected;

  /// Bağlantı yokken gönderilen, sırada bekleyen mesaj sayısı.
  int get pendingMessageCount => _pendingIds.length;

  /// Bağlantı yokken silinen, sırada bekleyen mesaj kimliği sayısı.
  int get pendingDeleteCount => _pendingDeletes.length;

  Future<SyncOutbox> _ensureOutbox() {
    final SyncOutbox? existing = _outbox;
    if (existing != null) {
      return existing.load().then((_) => existing);
    }
    final Future<SyncOutbox>? pending = _outboxFuture;
    if (pending != null) return pending;
    final Future<SyncOutbox> future = LocalSyncOutbox.open().then((opened) {
      _outbox = opened;
      return opened;
    });
    _outboxFuture = future;
    return future;
  }

  Future<void> configure(AppSettings settings) async {
    final SyncOutbox outbox = await _ensureOutbox();
    _syncedIds
      ..clear()
      ..addAll(outbox.syncedMessageIds);
    _pushedIds
      ..clear()
      ..addAll(outbox.pushedMessageIds);
    _pendingIds
      ..clear()
      ..addAll(outbox.pendingMessages.map((ChatMessage message) => message.id));
    _pendingDeletes
      ..clear()
      ..addAll(outbox.pendingDeletes);

    final SyncConfig config = SyncConfig.fromSettings(settings);
    if (!settings.isCloudConfigured) {
      _pushDebounce?.cancel();
      _pushDebounce = null;
      if (_active != null) {
        await _service.disconnect();
        _active = null;
      } else {
        _ref
            .read(syncStatusProvider.notifier)
            .set(SyncStatus.disabled, 'Yerel mod · bulut kapalı');
      }
      return;
    }
    if (_active?.sameAs(config) == true && _service.isConnected) {
      await _syncMemberHealth(settings);
      unawaited(_flushOutbox());
      return;
    }

    final bool ok = await _service.connect(config);
    if (!ok) return;
    // `_active` yalnızca bağlantı kesinleşince atanır; başarısız deneme eski
    // durumu bozmaz.
    _active = config;
    await _syncMemberHealth(settings);
    _knownMessageIds.addAll(
      _ref
          .read(gameProvider)
          .couple
          .messages
          .map((ChatMessage message) => message.id),
    );
    // İlk bağlantıda tam durum da buluta yazılmalı: aksi hâlde boş bir odaya
    // bağlanan cihaz yalnızca mesajları yükler, rubrik/plan kaybolur.
    _pushedRevision = -1;
    unawaited(_backfillLocalMessages());
    // Bağlantı kuruldu: önce bekleyen kuyruk, sonra kirli durum.
    unawaited(_flushOutbox());
  }

  /// Yerel değişiklikleri buluta taşır (yeni mesajlar + tam durum).
  void onLocalStateChanged(GameState state) {
    final GameController controller = _ref.read(gameProvider.notifier);
    final MutationOrigin origin = controller.lastOrigin;

    for (final ChatMessage message in state.couple.messages) {
      if (_syncedIds.contains(message.id)) continue;
      if (_pendingIds.contains(message.id)) continue;
      if (!_knownMessageIds.add(message.id)) continue;
      // Bulut hiç kurulmadıysa mesajları kuyruğa almayız; bağlantı kurulunca
      // `_backfillLocalMessages` senkronize edilmemiş kayıtları yükler.
      if (_active == null) continue;
      unawaited(_sendOrQueue(message));
    }

    // Yeni tombstone'lar: bağlıyken hemen, çevrimdışıyken kalıcı kuyruğa.
    for (final String id in state.couple.deletedMessageTombstones.keys) {
      if (!_knownTombstones.add(id)) continue;
      if (_active != null && _service.isConnected) {
        unawaited(_service.deleteMessage(id));
      } else {
        unawaited(_queueDelete(id));
      }
    }

    if (_active == null) return;
    // Uzak paket uygulandıysa geri gönderme (echo önlenir).
    if (origin == MutationOrigin.remote || origin == MutationOrigin.history) {
      return;
    }
    // Gönderilecek yeni bir yerel değişiklik yoksa boşuna ağ çağrısı yapma.
    if (controller.localRevision <= _pushedRevision) return;

    if (!_service.isConnected) {
      // Çevrimdışı: değişiklik anında kalıcı "kirli" taslağa yazılır.
      // Timer kurulmaz (widget testleri ve pil tüketimi için).
      unawaited(
        _ensureOutbox().then(
          (SyncOutbox outbox) => outbox.saveDirtyState(state),
        ),
      );
      return;
    }
    _schedulePush();
  }

  Future<void> _sendOrQueue(ChatMessage message) async {
    if (!_service.isConnected) {
      await _enqueue(message);
      return;
    }
    final bool ok = await _service.insertMessage(message);
    if (ok) {
      _syncedIds.add(message.id);
      final SyncOutbox outbox = await _ensureOutbox();
      // Push niyeti senkron işaretinden ÖNCE diske yazılır: arada uygulama
      // kapatılsa bile açılışta "synced + push bekliyor" durumu bulunur.
      await outbox.markPushPending(<String>[message.id]);
      await outbox.markSynced(<String>[message.id]);
      await outbox.dequeueMessage(message.id);
      _pendingIds.remove(message.id);
      // Satır Supabase'de kesinleştikten SONRA push: Edge Function mesajı
      // idempotency tablosunda bulabilir ve çift bildirim üretmez.
      await _pushMessageOnce(message);
    } else {
      await _enqueue(message);
    }
  }

  Future<void> _enqueue(ChatMessage message) async {
    if (!_pendingIds.add(message.id)) return;
    final SyncOutbox outbox = await _ensureOutbox();
    await outbox.enqueueMessage(message);
  }

  void _schedulePush() {
    _pushDebounce?.cancel();
    // Debounce yalnızca ağ çağrılarını birleştirir; doğruluk kararı
    // `localRevision` karşılaştırmasındadır (v5'teki 900 ms "sessizlik
    // penceresi" değildir).
    _pushDebounce = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_pushStateNow()),
    );
  }

  /// Durum push'larını single-flight kuyrukla serileştirir.
  Future<void> _pushStateNow() {
    final Future<void>? inFlight = _statePushInFlight;
    if (inFlight != null) return inFlight;
    final Future<void> future = _pushStateNowLocked();
    _statePushInFlight = future.whenComplete(() {
      if (identical(_statePushInFlight, future)) {
        _statePushInFlight = null;
      }
    });
    return _statePushInFlight!;
  }

  Future<void> _pushStateNowLocked() async {
    final SyncOutbox outbox = await _ensureOutbox();
    final GameController controller = _ref.read(gameProvider.notifier);
    final int targetRevision = controller.localRevision;
    if (targetRevision <= _pushedRevision) return;
    final GameState state = _ref.read(gameProvider);
    if (!_service.isConnected) {
      await outbox.saveDirtyState(state);
      return;
    }
    final bool ok = await _service.pushState(state);
    // Push sırasında yeni yerel değişiklik geldiyse dirty state'i temizleme;
    // aradaki değişiklik yeniden planlanır.
    if (ok && controller.localRevision == targetRevision) {
      _pushedRevision = targetRevision;
      await outbox.clearDirtyState();
    } else {
      await outbox.saveDirtyState(state);
      if (controller.localRevision > targetRevision) {
        _schedulePush();
      }
    }
  }

  /// Chat ekranındaki "⬆️ Daha Eski Mesajları Yükle" için.
  ///
  /// Dönen değer: eklenen mesaj sayısı; bağlantı yoksa `-1`; eski mesaj
  /// kalmadıysa `0`.
  Future<int> loadOlderMessages({int limit = 200}) async {
    if (!_service.isConnected) return -1;
    final List<ChatMessage> local = _ref.read(gameProvider).couple.messages;
    final DateTime? before = _oldestCreatedAt(local);
    try {
      final List<ChatMessage> batch = await _service.fetchMessages(
        limit: limit,
        before: before,
      );
      if (batch.isEmpty) return 0;
      return _applyHistory(batch);
    } catch (_) {
      return -1;
    }
  }

  /// "Bağlantı kuruldu" anında son 200 mesajı açar / gerekirse yeniler.
  Future<List<ChatMessage>> pullFullHistory({int limit = 200}) async {
    if (!_service.isConnected) return const <ChatMessage>[];
    try {
      final List<ChatMessage> history = await _service.pullFullHistory(
        limit: limit,
      );
      if (history.isNotEmpty) _applyHistory(history);
      return history;
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  DateTime? _oldestCreatedAt(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    return messages
        .map((ChatMessage message) => message.createdAt)
        .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
  }

  /// "yazıyor…" göstergesini karşı tarafa iletir.
  void setTyping(bool typing) {
    if (!_service.isConnected) return;
    unawaited(_service.setTyping(typing));
  }

  Future<String?> uploadMediaBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    if (!_service.isConnected) return Future<String?>.value();
    return _service.uploadMediaBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<void> disconnect() async {
    _pushDebounce?.cancel();
    final SyncOutbox outbox = await _ensureOutbox();
    if (!_service.isConnected) {
      await outbox.saveDirtyState(_ref.read(gameProvider));
    }
    _active = null;
    await _service.disconnect();
    _ref
        .read(syncStatusProvider.notifier)
        .set(SyncStatus.disabled, 'Yerel mod · bulut kapalı');
  }

  /// Kalıcı kuyruğu boşaltır: önce silmeler, sonra mesajlar, sonra kirli durum.
  Future<void> _flushOutbox() async {
    if (!_service.isConnected) return;
    final SyncOutbox outbox = await _ensureOutbox();
    try {
      // Çevrimdışıyken silinen mesajları buluta uygula.
      final List<String> pendingDeletes = outbox.pendingDeletes.toList(
        growable: false,
      );
      for (final String id in pendingDeletes) {
        final bool ok = await _service.deleteMessage(id);
        if (ok) {
          _pendingDeletes.remove(id);
          await outbox.dequeueDelete(id);
        }
      }

      final List<ChatMessage> pending = outbox.pendingMessages;
      for (final ChatMessage message in pending) {
        final bool ok = await _service.insertMessage(message);
        if (!ok) continue;
        _syncedIds.add(message.id);
        _knownMessageIds.add(message.id);
        _pendingIds.remove(message.id);
        await outbox.markPushPending(<String>[message.id]);
        await outbox.markSynced(<String>[message.id]);
        await outbox.dequeueMessage(message.id);
        // Çevrimdışıyken yazılan mesaj bağlantı gelince tam bir kez push edilir.
        await _pushMessageOnce(message);
      }

      // Önceki denemede ağ/401/403/kapanma nedeniyle gönderilemeyen push'ları,
      // bağlantı yeniden kurulduğunda TÜM yerel mesajlar içinden tamamla.
      final Set<String> pendingPushes = outbox.pendingPushMessageIds;
      if (pendingPushes.isNotEmpty) {
        final List<ChatMessage> allMessages = _ref
            .read(gameProvider)
            .couple
            .messages;
        for (final ChatMessage message in allMessages.reversed) {
          if (!pendingPushes.contains(message.id)) continue;
          if (!_syncedIds.contains(message.id)) continue;
          if (_pushedIds.contains(message.id)) continue;
          await _pushMessageOnce(message);
        }
      }

      final GameController controller = _ref.read(gameProvider.notifier);
      if (!outbox.hasDirtyState &&
          controller.localRevision <= _pushedRevision) {
        return;
      }
      final int targetRevision = controller.localRevision;
      final GameState state = _ref.read(gameProvider);
      final bool pushed = await _service.pushState(state);
      // Push sırasında yeni yerel değişiklik geldiyse dirty state korunur.
      if (pushed && controller.localRevision == targetRevision) {
        _pushedRevision = targetRevision;
        await outbox.clearDirtyState();
      } else {
        await outbox.saveDirtyState(state);
      }
    } catch (_) {
      // Tek bir kuyruk öğesi başarısız olsa bile sıradaki öğeler etkilenmez;
      // sonraki configure/resume denemesinde yeniden denenir.
    }
  }

  int _applyHistory(List<ChatMessage> history) {
    final int added = _ref
        .read(gameProvider.notifier)
        .mergeRemoteMessages(history, origin: MutationOrigin.history);
    _markSynced(history.map((ChatMessage message) => message.id));
    unawaited(_backfillLocalMessages());
    unawaited(_flushOutbox());
    return added;
  }

  /// Yerelde olup buluta **hiç yazılmamış** son 200 mesajı yükler.
  ///
  /// v5 her geçmiş çekiminde tüm yerel mesajları yeniden `insertMessage` ile
  /// gönderiyordu. v6'da `syncedMessageIds` kalıcıdır: yalnızca gerçekten
  /// senkronize edilmemiş mesajlar ve son 200 kayıt taranır.
  Future<void> _backfillLocalMessages() async {
    if (!_service.isConnected) return;
    try {
      final List<ChatMessage> messages = _ref
          .read(gameProvider)
          .couple
          .messages;
      final int start = messages.length > 200 ? messages.length - 200 : 0;
      for (int i = start; i < messages.length; i++) {
        final ChatMessage message = messages[i];
        if (_syncedIds.contains(message.id)) continue;
        if (_pendingIds.contains(message.id)) continue;
        final bool ok = await _service.insertMessage(message);
        if (ok) {
          _syncedIds.add(message.id);
          final SyncOutbox outbox = await _ensureOutbox();
          await outbox.markSynced(<String>[message.id]);
          // Backfill eski seed mesajlarını push etmez; yalnızca outbox'ta
          // push bekleyen (requestPushFor / çevrimdışı kuyruk) mesajları iletir.
          if (outbox.pendingPushMessageIds.contains(message.id) ||
              _pushRequestedIds.contains(message.id)) {
            await _pushMessageOnce(message);
          }
        } else {
          await _enqueue(message);
        }
      }
    } catch (_) {
      // Tek mesaj başarısız olsa bile sıradaki kayıtlar etkilenmez.
    }
  }

  /// AppServices'in `own == true` dalından çağrılır.
  ///
  /// Ağ isteği **hemen** yapılmaz: önce mesajın Supabase satırı kesinleşir,
  /// sonra [_pushMessageOnce] tam bir kez çalışır. Böylece Edge Function
  /// idempotency kontrolü mesajı bulabilir ve gönderenin sessiz saati /
  /// kapalı bildirim ayarı partnerin push'unu engelleyemez.
  Future<void> requestPushFor(ChatMessage message) async {
    final AppSettings settings = _ref.read(appSettingsProvider);
    if (message.senderId != settings.deviceRole) return;
    _pushRequestedIds.add(message.id);
    final SyncOutbox outbox = await _ensureOutbox();
    if (outbox.pushedMessageIds.contains(message.id) ||
        _pushedIds.contains(message.id)) {
      return;
    }
    await outbox.markPushPending(<String>[message.id]);
    if (_syncedIds.contains(message.id)) {
      await _pushMessageOnce(message);
    }
  }

  Future<void> _pushMessageOnce(ChatMessage message) async {
    final AppSettings settings = _ref.read(appSettingsProvider);
    if (message.senderId != settings.deviceRole) return;
    if (!MessageDeliveryPolicy.shouldPushOutgoing(settings: settings)) return;
    if (_pushedIds.contains(message.id) || !_pushInFlight.add(message.id)) {
      return;
    }
    try {
      final SyncOutbox outbox = await _ensureOutbox();
      if (outbox.pushedMessageIds.contains(message.id)) {
        _pushedIds.add(message.id);
        return;
      }
      final PushResult result = await _pushDispatcher(
        settings: settings,
        message: message,
      );
      // 401/403 retry'ı PushService içinde **bir kez** yapılır; oturum + oda
      // üyeliği `refreshMembership` köprüsüyle (AppServices) tazelenir.
      if (result.ok) {
        _pushedIds.add(message.id);
        _pushRequestedIds.remove(message.id);
        await outbox.markPushed(<String>[message.id]);
      } else {
        // Yapılandırılmış tanı: sağlık paneli + sohbet uyarısı aynı sonucu
        // gösterir; geliştirici logu da mesaj ve HTTP kodunu taşır.
        debugPrint(
          'push failed · message=${message.id} · '
          'http=${result.statusCode} · ${result.message}',
        );
      }
      _ref.read(pushHealthProvider.notifier).set(result);
    } finally {
      _pushInFlight.remove(message.id);
    }
  }

  /// Sohbet ekranı okundu bilgisini güvenli RPC'ye taşır.
  ///
  /// `p_up_to` anlamına gelir: o ana kadar partnerden gelen tüm okunmamış
  /// mesajlar `mark_messages_read` ile işaretlenir.
  Future<void> markMessagesRead(DateTime upTo) async {
    if (!_service.isConnected) return;
    await _service.markMessagesRead(upTo);
  }

  Future<void> _queueDelete(String messageId) async {
    if (!_pendingDeletes.add(messageId)) return;
    final SyncOutbox outbox = await _ensureOutbox();
    await outbox.enqueueDelete(messageId);
  }

  /// Emoji tepkisini güvenli RPC'ye taşır.
  Future<void> toggleMessageReaction(String messageId, String emoji) async {
    if (!_service.isConnected) return;
    await _service.toggleMessageReaction(messageId, emoji);
  }

  /// Push 401/403 retry'ı öncesi oturum + oda üyeliğini tazeler.
  Future<bool> refreshSessionAndMembership() =>
      _service.refreshSessionAndMembership();

  Future<void> _syncMemberHealth(AppSettings settings) async {
    if (!_service.isConnected) return;
    await _service.updateMemberHealth(
      pushEnabled: settings.isPushConfigured && settings.messageNotifications,
      // DND kapalıysa sunucu sessiz saat uygulamamalı.
      quietStartMinute: settings.doNotDisturbEnabled
          ? settings.quietStartMinutes
          : null,
      quietEndMinute: settings.doNotDisturbEnabled
          ? settings.quietEndMinutes
          : null,
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }

  void _markSynced(Iterable<String> ids) {
    final List<String> list = <String>[
      for (final String id in ids)
        if (id.trim().isNotEmpty) id,
    ];
    if (list.isEmpty) return;
    _syncedIds.addAll(list);
    _knownMessageIds.addAll(list);
    unawaited(
      _ensureOutbox().then((SyncOutbox outbox) => outbox.markSynced(list)),
    );
  }

  void _onRemoteHistory(List<ChatMessage> messages) {
    // Boş geçmişte de çalışır: yereldeki mesajları buluta geri doldurur.
    _applyHistory(messages);
  }

  void _onRemoteMessage(ChatMessage message) {
    _knownMessageIds.add(message.id);
    _markSynced(<String>[message.id]);
    _ref.read(gameProvider.notifier).receiveRemoteMessage(message);
  }

  void _onRemoteMessageUpdate(ChatMessage message) {
    _markSynced(<String>[message.id]);
    _ref.read(gameProvider.notifier).mergeRemoteMessageUpdate(message);
  }

  void _onRemoteMessageDeleted(String messageId) {
    _knownTombstones.add(messageId);
    _ref
        .read(gameProvider.notifier)
        .deleteMessage(messageId, origin: MutationOrigin.remote);
  }

  void _onRemoteState(GameState remote) {
    _markSynced(
      remote.couple.messages.map((ChatMessage message) => message.id),
    );
    final String role = _ref.read(appSettingsProvider).deviceRole;
    // Cihaz rolü kilitlidir: karşı telefonun aktif profili bu telefonu
    // değiştirmez (Yusuf'un telefonu Ceyda görünümüne geçmez).
    _ref.read(gameProvider.notifier).applyRemoteState(remote, deviceRole: role);
    // Uzak durum uygulandı; `localRevision` artmadığı için echo oluşmaz.
    // Ancak yerelde biriken mesajlar varsa kuyruk yine boşaltılır.
    unawaited(_flushOutbox());
  }

  void _onStatusChanged(SyncStatus status, String message) {
    _ref.read(syncStatusProvider.notifier).set(status, message);
    if (status == SyncStatus.connected) {
      // Bağlantı yeni kuruldu: çevrimdışı kuyruğu hemen boşalt.
      unawaited(_flushOutbox());
    }
  }

  void _onPresenceChanged(bool online) {
    _ref.read(syncPresenceProvider.notifier).setOnline(online);
  }

  Timer? _typingClearTimer;

  void _onTypingChanged(bool typing) {
    final SyncPresenceController controller = _ref.read(
      syncPresenceProvider.notifier,
    );
    _typingClearTimer?.cancel();
    controller.setTyping(typing);
    if (typing) {
      _typingClearTimer = Timer(const Duration(seconds: 4), () {
        controller.setTyping(false);
      });
    }
  }
}

final Provider<CloudSyncCoordinator> cloudSyncProvider =
    Provider<CloudSyncCoordinator>(CloudSyncCoordinator.new);
