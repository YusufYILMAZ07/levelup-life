import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_state.dart';
import '../domain/entities/entities.dart';
import 'app_settings.dart';
import 'supabase_sync_service.dart';

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

/// Yerel durum ↔ Supabase köprüsü.
///
/// * yapılandırma yoksa hiçbir ağ çağrısı yapmaz,
/// * yeni mesajları tek tek `chat_messages`'a yazar,
/// * rubrik / plan / kapsül değişimlerini 900 ms debounce ile `couple_rooms`
///   tablosuna iter,
/// * karşı telefondan gelen mesajı yerel duruma ekler ve bildirim gösterir.
final class CloudSyncCoordinator {
  CloudSyncCoordinator(this._ref) {
    _service = SupabaseSyncService(
      onRemoteMessage: _onRemoteMessage,
      onRemoteState: _onRemoteState,
      onStatusChanged: _onStatusChanged,
      onRemoteHistory: _onRemoteHistory,
    );
  }

  final Ref _ref;
  late final SupabaseSyncService _service;

  final Set<String> _knownMessageIds = <String>{};
  final Set<String> _cloudMessageIds = <String>{};
  final List<ChatMessage> _pendingMessages = <ChatMessage>[];
  Timer? _pushDebounce;
  bool _applyingRemote = false;
  bool _applyingHistory = false;
  SyncConfig? _active;

  bool get isConnected => _service.isConnected;

  /// Şu an karşı telefondan gelen bir durum uygulanıyor mu?
  bool get isApplyingRemote => _applyingRemote;

  /// Toplu geçmiş çekiliyor mu? (bildirim yağmurunu engeller)
  bool get isApplyingHistory => _applyingHistory;

  /// Bağlantı yokken gönderilen, sırada bekleyen mesaj sayısı.
  int get pendingMessageCount => _pendingMessages.length;

  Future<void> configure(AppSettings settings) async {
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
    if (_active?.sameAs(config) == true && _service.isConnected) return;

    _active = config;
    final bool ok = await _service.connect(config);
    if (ok) {
      _knownMessageIds.addAll(
        _ref
            .read(gameProvider)
            .couple
            .messages
            .map((ChatMessage message) => message.id),
      );
      unawaited(_flushPendingMessages());
    }
  }

  /// Yerel değişiklikleri buluta taşır (yeni mesajlar + tam durum).
  void onLocalStateChanged(GameState state) {
    if (!_service.isConnected) {
      // Çevrimdışı gönderimler kaybolmaz: bağlantı gelince sırayla akar.
      for (final ChatMessage message in state.couple.messages) {
        if (_knownMessageIds.add(message.id)) {
          _pendingMessages.add(message);
        }
      }
      return;
    }
    for (final ChatMessage message in state.couple.messages) {
      if (_knownMessageIds.add(message.id)) {
        unawaited(
          _service.insertMessage(message).then((bool ok) {
            if (!ok) _pendingMessages.add(message);
          }),
        );
      }
    }
    if (_applyingRemote) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_service.pushState(_ref.read(gameProvider)));
    });
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

  int _applyHistory(List<ChatMessage> history) {
    _applyingRemote = true;
    _applyingHistory = true;
    _cloudMessageIds.addAll(history.map((ChatMessage message) => message.id));
    final int added = _ref
        .read(gameProvider.notifier)
        .mergeRemoteMessages(history);
    _knownMessageIds.addAll(
      _ref
          .read(gameProvider)
          .couple
          .messages
          .map((ChatMessage message) => message.id),
    );
    _backfillLocalMessages();
    unawaited(_flushPendingMessages());
    Timer(const Duration(milliseconds: 900), () {
      _applyingRemote = false;
      _applyingHistory = false;
    });
    return added;
  }

  /// Yerelde olup bulutta olmayan mesajları kalıcı olarak yükler.
  void _backfillLocalMessages() {
    for (final ChatMessage message in _ref.read(gameProvider).couple.messages) {
      if (!_cloudMessageIds.add(message.id)) continue;
      unawaited(_service.insertMessage(message));
    }
  }

  Future<void> _flushPendingMessages() async {
    if (!_service.isConnected || _pendingMessages.isEmpty) return;
    final List<ChatMessage> batch = <ChatMessage>[..._pendingMessages];
    _pendingMessages.clear();
    for (final ChatMessage message in batch) {
      final bool ok = await _service.insertMessage(message);
      if (!ok) _pendingMessages.add(message);
    }
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
    _active = null;
    await _service.disconnect();
    _ref
        .read(syncStatusProvider.notifier)
        .set(SyncStatus.disabled, 'Yerel mod · bulut kapalı');
  }

  void _onRemoteHistory(List<ChatMessage> messages) {
    // Boş geçmişte de çalışır: yereldeki mesajları buluta geri doldurur.
    _applyHistory(messages);
  }

  void _onRemoteMessage(ChatMessage message) {
    // Geçmiş uygulamasının 900 ms'lik sessizlik penceresi canlı mesajı
    // yutmasın: gerçek zamanlı paket geldiğinde pencereyi hemen kapat.
    _applyingRemote = false;
    _applyingHistory = false;
    _knownMessageIds.add(message.id);
    _cloudMessageIds.add(message.id);
    // Bildirim tek kaynaktan (AppServices) yönetilir; burada tekrarlanmaz.
    _ref.read(gameProvider.notifier).receiveRemoteMessage(message);
  }

  void _onRemoteState(GameState remote) {
    _applyingRemote = true;
    _knownMessageIds.addAll(
      remote.couple.messages.map((ChatMessage message) => message.id),
    );
    // Cihaz rolü kilitlidir: karşı telefonun aktif profili bu telefonu
    // değiştirmez (Yusuf'un telefonu Ceyda görünümüne geçmez).
    final String role = _ref.read(appSettingsProvider).deviceRole;
    final GameState next = remote.activePartnerId == role
        ? remote
        : remote.activatePartner(role);
    _ref.read(gameProvider.notifier).applyRemoteState(next);
    _knownMessageIds.addAll(
      _ref
          .read(gameProvider)
          .couple
          .messages
          .map((ChatMessage message) => message.id),
    );
    Timer(const Duration(milliseconds: 700), () {
      _applyingRemote = false;
    });
  }

  void _onStatusChanged(SyncStatus status, String message) {
    _ref.read(syncStatusProvider.notifier).set(status, message);
    if (status == SyncStatus.connected) {
      // Bağlantı yeni kuruldu: çevrimdışı kuyruğu hemen boşalt.
      unawaited(_flushPendingMessages());
    }
  }
}

final Provider<CloudSyncCoordinator> cloudSyncProvider =
    Provider<CloudSyncCoordinator>(CloudSyncCoordinator.new);
