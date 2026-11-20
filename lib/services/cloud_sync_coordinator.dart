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
    );
  }

  final Ref _ref;
  late final SupabaseSyncService _service;

  final Set<String> _knownMessageIds = <String>{};
  Timer? _pushDebounce;
  bool _applyingRemote = false;
  SyncConfig? _active;
  bool _connectedOnce = false;

  bool get isConnected => _service.isConnected;

  /// Şu an karşı telefondan gelen bir durum uygulanıyor mu?
  bool get isApplyingRemote => _applyingRemote;

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
      _knownMessageIds
        ..clear()
        ..addAll(
          _ref
              .read(gameProvider)
              .couple
              .messages
              .map((ChatMessage message) => message.id),
        );
    }
  }

  /// Yerel değişiklikleri buluta taşır (yeni mesajlar + tam durum).
  void onLocalStateChanged(GameState state) {
    if (!_service.isConnected) return;
    for (final ChatMessage message in state.couple.messages) {
      if (_knownMessageIds.add(message.id)) {
        unawaited(_service.insertMessage(message));
      }
    }
    if (_applyingRemote) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_service.pushState(_ref.read(gameProvider)));
    });
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

  void _onRemoteMessage(ChatMessage message) {
    _knownMessageIds.add(message.id);
    // Bildirim tek kaynaktan (AppServices) yönetilir; burada tekrarlanmaz.
    _ref.read(gameProvider.notifier).receiveRemoteMessage(message);
  }

  void _onRemoteState(GameState remote) {
    _applyingRemote = true;
    _knownMessageIds
      ..clear()
      ..addAll(remote.couple.messages.map((ChatMessage message) => message.id));
    // Cihaz rolü kilitlidir: karşı telefonun aktif profili bu telefonu
    // değiştirmez (Yusuf'un telefonu Ceyda görünümüne geçmez).
    final String role = _ref.read(appSettingsProvider).deviceRole;
    final GameState next = remote.activePartnerId == role
        ? remote
        : remote.activatePartner(role);
    _ref.read(gameProvider.notifier).applyRemoteState(next);
    Timer(const Duration(milliseconds: 700), () {
      _applyingRemote = false;
    });
  }

  void _onStatusChanged(SyncStatus status, String message) {
    _ref.read(syncStatusProvider.notifier).set(status, message);
    if (status == SyncStatus.connected && !_connectedOnce) {
      _connectedOnce = true;
      unawaited(_service.pushState(_ref.read(gameProvider)));
    }
  }
}

final Provider<CloudSyncCoordinator> cloudSyncProvider =
    Provider<CloudSyncCoordinator>(CloudSyncCoordinator.new);
