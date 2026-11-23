import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_mutation.dart';
import '../application/game_state.dart';
import '../domain/entities/entities.dart';
import 'app_settings.dart';
import 'supabase_sync_service.dart';
import 'sync_outbox.dart';

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
  }) : _outbox = outbox {
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

  SyncOutbox? _outbox;
  final Set<String> _knownMessageIds = <String>{};
  final Set<String> _syncedIds = <String>{};
  final Set<String> _pendingIds = <String>{};
  final Set<String> _knownTombstones = <String>{};
  Timer? _pushDebounce;
  bool _applyingRemote = false;
  bool _applyingHistory = false;
  bool _remoteApplyPending = false;
  bool _historyApplyPending = false;
  int _pushedRevision = 0;
  SyncConfig? _active;

  bool get isConnected => _service.isConnected;

  /// Şu an karşı telefondan gelen bir durum uygulanıyor mu?
  ///
  /// Senkron pencere + bir sonraki state bildirimine kadar taşınan "pending"
  /// bayrağı birlikte değerlendirilir. Böylece Riverpod dinleyicisi bir tick
  /// gecikse bile uzak mesaj yerel bildirim/push üretmez.
  bool get isApplyingRemote => _applyingRemote || _remoteApplyPending;

  /// Toplu geçmiş çekiliyor mu?
  bool get isApplyingHistory => _applyingHistory || _historyApplyPending;

  /// Bağlantı yokken gönderilen, sırada bekleyen mesaj sayısı.
  int get pendingMessageCount => _pendingIds.length;

  Future<SyncOutbox> _ensureOutbox() async {
    final SyncOutbox? existing = _outbox;
    if (existing != null) {
      await existing.load();
      return existing;
    }
    final LocalSyncOutbox opened = await LocalSyncOutbox.open();
    _outbox = opened;
    return opened;
  }

  Future<void> configure(AppSettings settings) async {
    final SyncOutbox outbox = await _ensureOutbox();
    _syncedIds
      ..clear()
      ..addAll(outbox.syncedMessageIds);
    _pendingIds
      ..clear()
      ..addAll(outbox.pendingMessages.map((ChatMessage message) => message.id));

    final SyncConfig config = SyncConfig.fromSettings(settings);
    if (!settings.isCloudConfigured) {
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
      unawaited(_flushOutbox());
      return;
    }

    _active = config;
    final bool ok = await _service.connect(config);
    if (!ok) return;
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
    // AppServices bu bayrakları okuyup bildirim/push kararını verir; ardından
    // bu metot çağrılır. Burada temizlemek güvenlidir.
    _remoteApplyPending = false;
    _historyApplyPending = false;
    final GameController controller = _ref.read(gameProvider.notifier);
    final MutationOrigin origin = controller.lastOrigin;

    for (final ChatMessage message in state.couple.messages) {
      if (_syncedIds.contains(message.id)) continue;
      if (_pendingIds.contains(message.id)) continue;
      if (!_knownMessageIds.add(message.id)) continue;
      // Bulut hiç kurulmadıysa mesajları kuyruğa almayız; bağlantı kurulunca
      // `_backfillLocalMessages` son 200 senkronize edilmemiş kaydı yükler.
      if (_active == null) continue;
      unawaited(_sendOrQueue(message));
    }

    // Yeni tombstone'ları buluta da yansıt: karşı cihaz gerçek zamanlı
    // `delete` olayını alır (durum paketi de tombstone taşır).
    for (final String id in state.couple.deletedMessageTombstones.keys) {
      if (!_knownTombstones.add(id)) continue;
      if (_active != null && _service.isConnected) {
        unawaited(_service.deleteMessage(id));
      }
    }

    if (_active == null) return;
    // Uzak paket uygulandıysa geri gönderme (echo önlenir).
    if (origin == MutationOrigin.remote) return;
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
      await outbox.markSynced(<String>[message.id]);
      await outbox.dequeueMessage(message.id);
      _pendingIds.remove(message.id);
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

  Future<void> _pushStateNow() async {
    final SyncOutbox outbox = await _ensureOutbox();
    final GameController controller = _ref.read(gameProvider.notifier);
    final int revision = controller.localRevision;
    if (revision <= _pushedRevision) return;
    final GameState state = _ref.read(gameProvider);
    if (!_service.isConnected) {
      await outbox.saveDirtyState(state);
      return;
    }
    final bool ok = await _service.pushState(state);
    if (ok) {
      _pushedRevision = revision;
      await outbox.clearDirtyState();
    } else {
      await outbox.saveDirtyState(state);
    }
  }

  /// Chat ekranındaki "⬆️ Daha Eski Mesajları Yükle" için.
  ///
  /// Dönen değer: eklenen mesaj sayısı; bağlantı yoksa `-1`; eski mesaj
  /// kalmadıysa `0`.
  Future<int> loadOlderMessages({int limit = 200}) async {
    if (!_service.isConnected) return -1;
    final List<ChatMessage> local = _ref.read(gameProvider).couple.messages;
    final DateTime? before = local.isEmpty ? null : local.first.createdAt;
    final List<ChatMessage> batch = await _service.fetchMessages(
      limit: limit,
      before: before,
    );
    if (batch.isEmpty) return 0;
    return _applyHistory(batch);
  }

  /// "Bağlantı kuruldu" anında son 200 mesajı açar / gerekirse yeniler.
  Future<List<ChatMessage>> pullFullHistory({int limit = 200}) async {
    final List<ChatMessage> history = await _service.pullFullHistory(
      limit: limit,
    );
    if (history.isNotEmpty) _applyHistory(history);
    return history;
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

  /// Kalıcı kuyruğu boşaltır: önce mesajlar, sonra kirli durum.
  Future<void> _flushOutbox() async {
    final SyncOutbox outbox = await _ensureOutbox();
    if (!_service.isConnected) return;
    // Çevrimdışıyken silinen mesajları (tombstone) buluta da uygula.
    for (final String id
        in _ref.read(gameProvider).couple.deletedMessageTombstones.keys) {
      if (!_knownTombstones.add(id)) continue;
      await _service.deleteMessage(id);
    }
    final List<ChatMessage> pending = outbox.pendingMessages;
    for (final ChatMessage message in pending) {
      final bool ok = await _service.insertMessage(message);
      if (!ok) continue;
      _syncedIds.add(message.id);
      _knownMessageIds.add(message.id);
      _pendingIds.remove(message.id);
      await outbox.dequeueMessage(message.id);
      await outbox.markSynced(<String>[message.id]);
    }
    final GameController controller = _ref.read(gameProvider.notifier);
    if (!outbox.hasDirtyState &&
        controller.localRevision <= _pushedRevision) {
      return;
    }
    final GameState state = _ref.read(gameProvider);
    final bool pushed = await _service.pushState(state);
    if (pushed) {
      _pushedRevision = controller.localRevision;
      await outbox.clearDirtyState();
    } else {
      await outbox.saveDirtyState(state);
    }
  }

  int _applyHistory(List<ChatMessage> history) {
    _applyingRemote = true;
    _applyingHistory = true;
    _remoteApplyPending = true;
    _historyApplyPending = true;
    int added = 0;
    try {
      added = _ref
          .read(gameProvider.notifier)
          .mergeRemoteMessages(history);
    } finally {
      // Sabit Timer yok: bayrak mutasyonun tam etrafında açılıp kapanır.
      _applyingRemote = false;
      _applyingHistory = false;
    }
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
    final List<ChatMessage> messages = _ref.read(gameProvider).couple.messages;
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
      } else {
        await _enqueue(message);
      }
    }
  }

  void _markSynced(Iterable<String> ids) {
    final List<String> list = <String>[
      for (final String id in ids)
        if (id.trim().isNotEmpty) id,
    ];
    if (list.isEmpty) return;
    _syncedIds.addAll(list);
    _knownMessageIds.addAll(list);
    unawaited(_ensureOutbox().then((SyncOutbox outbox) => outbox.markSynced(list)));
  }

  void _onRemoteHistory(List<ChatMessage> messages) {
    // Boş geçmişte de çalışır: yereldeki mesajları buluta geri doldurur.
    _applyHistory(messages);
  }

  void _onRemoteMessage(ChatMessage message) {
    _knownMessageIds.add(message.id);
    _markSynced(<String>[message.id]);
    _applyingRemote = true;
    _remoteApplyPending = true;
    _applyingHistory = false;
    try {
      _ref.read(gameProvider.notifier).receiveRemoteMessage(message);
    } finally {
      _applyingRemote = false;
    }
  }

  void _onRemoteMessageUpdate(ChatMessage message) {
    _markSynced(<String>[message.id]);
    _applyingRemote = true;
    _remoteApplyPending = true;
    try {
      _ref.read(gameProvider.notifier).mergeRemoteMessageUpdate(message);
    } finally {
      _applyingRemote = false;
    }
  }

  void _onRemoteMessageDeleted(String messageId) {
    _applyingRemote = true;
    _remoteApplyPending = true;
    _knownTombstones.add(messageId);
    try {
      _ref
          .read(gameProvider.notifier)
          .deleteMessage(messageId, origin: MutationOrigin.remote);
    } finally {
      _applyingRemote = false;
    }
  }

  void _onRemoteState(GameState remote) {
    _markSynced(remote.couple.messages.map((ChatMessage message) => message.id));
    _applyingRemote = true;
    _remoteApplyPending = true;
    _applyingHistory = false;
    try {
      final String role = _ref.read(appSettingsProvider).deviceRole;
      // Cihaz rolü kilitlidir: karşı telefonun aktif profili bu telefonu
      // değiştirmez (Yusuf'un telefonu Ceyda görünümüne geçmez).
      _ref
          .read(gameProvider.notifier)
          .applyRemoteState(remote, deviceRole: role);
    } finally {
      _applyingRemote = false;
    }
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
