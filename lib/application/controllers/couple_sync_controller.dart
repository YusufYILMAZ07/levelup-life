
import '../../data/game_store.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../couple_bootstrap.dart';
import 'couple_chat_controller.dart';
import '../game_mutation.dart';
import '../game_state.dart';

/// Cihaz kimliği, partner geçişi ve bulut durum birleştirmesi.
final class CoupleSyncController {
  CoupleSyncController(this._game);

  final GameStateAccess _game;

  GameState get _state => _game.state;

  AppSettings get _settings => _game.ref.read(appSettingsProvider);

  // ── Partner geçişi ───────────────────────────────────────────────────────

  /// Üst bardaki segmentten partner değiştirir.
  ///
  /// Cihaz sahibi kilidi açıksa yalnızca kilitli profile geçilebilir; böylece
  /// yanlış isimle mesaj / puan girilmesi engellenir.
  void switchPartner(String partnerId) {
    final AppSettings settings = _settings;
    if (settings.lockToDeviceOwner && partnerId != settings.deviceRole) return;
    final GameState next = _state.activatePartner(partnerId);
    if (identical(next, _state)) return;
    // Telefonu devralan partner, karşı taraftan gelen mesajları görmüş olur.
    _game.commit(
      next.withCouple(next.couple.markMessagesRead(readerId: partnerId)),
    );
  }

  /// Yusuf ↔ Ceyda geçişi.
  void toggleActivePartner() =>
      switchPartner(CouplePartner.other(_state.activePartnerId));

  /// Cihaz sahibi kilidi açıksa aktif profili sahibe sabitler.
  void enforceDeviceOwner() {
    final AppSettings settings = _settings;
    if (!settings.lockToDeviceOwner || !_state.isCoupleEdition) return;
    if (!CouplePartner.isValid(settings.deviceRole)) return;
    if (_state.activePartnerId == settings.deviceRole) return;
    _game.commit(_state.activatePartner(settings.deviceRole));
  }

  // ── Uzak durum ───────────────────────────────────────────────────────────

  /// Karşı telefondan gelen tam durumu **tahribatsız** uygular.
  ///
  /// * mesajlar / kapsüller / plan blokları / hedefler birleştirilir,
  /// * tombstone'lar her iki taraftan birleşir; silinen içerik geri dirilmez,
  /// * **cihaza özgü kimlik korunur:** uzak `activePartnerId` bu telefonun
  ///   profilini değiştirmez ([deviceRole] veya mevcut aktif partner kalır).
  void applyRemoteState(GameState remote, {String? deviceRole}) {
    final GameState local = _state;
    final CoupleState base = remote.couple.mergeTombstones(local.couple);
    final CoupleState mergedNotes = base.mergeLoveNotes(
      local.couple.customLoveNotes,
    );
    final CoupleState merged = mergedNotes
        .copyWith(
          messages: CoupleChatController.mergeMessages(
            local: local.couple.messages,
            remote: remote.couple.messages,
            tombstones: mergedNotes.deletedMessageTombstones,
          ),
          rewardCapsules: _mergeCapsules(
            local.couple.rewardCapsules,
            remote.couple.rewardCapsules,
          ),
          scheduleBlocks: _mergeSchedules(
            local.couple.scheduleBlocks,
            remote.couple.scheduleBlocks,
          ),
          bucketGoals: _mergeBucketGoals(
            local.couple.bucketGoals,
            remote.couple.bucketGoals,
          ),
        )
        .pruneTombstones();

    final String role = _safeRole(deviceRole) ?? local.activePartnerId;
    GameState next = remote.withCouple(merged);
    if (next.isCoupleEdition && CouplePartner.isValid(role)) {
      next = next.activatePartner(role);
    }
    _game.commit(next, origin: MutationOrigin.remote);
  }

  // ── Sıfırlama ────────────────────────────────────────────────────────────

  /// "Hedeflerimi sıfırla" — onboarding'e geri döner ve tüm ilerlemeyi siler.
  Future<void> resetJourney() async {
    _game.commit(const GameState());
    await _game.ref.read(gameStoreProvider).clear();
  }

  /// Çift sürümünü tohum verisiyle yeniden başlatır (demo/hediye modu).
  Future<void> restartCoupleJourney() async {
    final GameState seeded = CoupleBootstrap.initialState();
    _game.commit(seeded);
    await _game.ref.read(gameStoreProvider).save(seeded);
  }

  /// Doğrulanmış yedeği tek hamlede uygular (geri yükleme).
  Future<void> importState(GameState state) async {
    _game.commit(state);
    await _game.ref.read(gameStoreProvider).save(state);
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  static String? _safeRole(String? role) =>
      role != null && CouplePartner.isValid(role) ? role : null;

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

  static List<BucketGoal> _mergeBucketGoals(
    List<BucketGoal> local,
    List<BucketGoal> remote,
  ) {
    if (remote.isEmpty) return local;
    final Map<String, BucketGoal> merged = <String, BucketGoal>{
      for (final BucketGoal goal in remote) goal.id: goal,
    };
    for (final BucketGoal goal in local) {
      merged.putIfAbsent(goal.id, () => goal);
    }
    return merged.values.toList(growable: false);
  }
}
