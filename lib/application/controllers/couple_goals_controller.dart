import '../../domain/entities/entities.dart';
import '../game_mutation.dart';
import '../game_state.dart';
import '../game_outcomes.dart';

/// Bucket list, haftalık plan/bahis, özel günler ve canlı durum.
final class CoupleGoalsController {
  CoupleGoalsController(this._game);

  final GameStateAccess _game;

  int _sequence = 0;

  GameState get _state => _game.state;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  // ── Canlı durum ──────────────────────────────────────────────────────────

  /// Üst bardaki canlı durum seçimi.
  void setLiveStatus(LiveStatus status, {String? partnerId}) {
    final String id = partnerId ?? _state.activePartnerId;
    if (_state.couple.liveStatusOf(id) == status) return;
    _game.commit(_state.withCouple(_state.couple.withLiveStatus(id, status)));
  }

  // ── Bucket list (ortak hedefler) ─────────────────────────────────────────

  /// Ortak hedefi açar/kapatır.
  ///
  /// **v6:** Co-Op XP'si hedef başına yalnızca bir kez verilir
  /// ([BucketGoal.rewardClaimed]). v5'te hedefi kapatıp yeniden açmak her
  /// seferinde iki tarafa tekrar XP yazıyordu (sınırsız XP istismarı).
  bool toggleBucketGoal(String goalId) {
    BucketGoal? target;
    for (final BucketGoal goal in _state.couple.bucketGoals) {
      if (goal.id == goalId) target = goal;
    }
    if (target == null) return false;

    final DateTime now = DateTime.now();
    final bool completing = !target.isDone;
    final bool shouldReward = completing && !target.rewardClaimed;
    GameState next = _state.withCouple(
      _state.couple.toggleBucketGoal(goalId, now: now),
    );
    if (shouldReward) {
      next = next.grantBoth(
        stat: StatKey.willpower,
        xp: target.rewardPoints,
        at: now,
      );
    }
    _game.commit(next);
    return completing;
  }

  // ── Haftalık plan (senkron program) ──────────────────────────────────────

  /// Plan bloğunu **bugün için** tamamlar.
  ///
  /// Partnerin bloğun kategorisine karşılık gelen statına +25 XP verilir ve
  /// sohbete kanıt rozeti düşülür. Aynı blok aynı gün ikinci kez
  /// tamamlanırsa XP verilmez (puan avcılığını engeller).
  ScheduleOutcome? completeScheduleBlock(String blockId, {DateTime? day}) {
    final ScheduleBlock? block = _state.couple.blockById(blockId);
    if (block == null) return null;

    final DateTime now = day ?? DateTime.now();
    final bool alreadyCompleted = block.isCompletedOn(now);
    if (alreadyCompleted) {
      final CoupleState reset = _state.couple.completeScheduleBlock(
        blockId,
        now,
      );
      if (!identical(reset, _state.couple)) {
        _game.commit(_state.withCouple(reset));
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
      id: _newId('plan'),
      senderId: block.partnerId,
      createdAt: now,
      text: '${block.title} planını tamamladım! 💪',
      questBadgeTitle: block.title,
      earnedPoints: SchedulePlanner.completionXp,
      kind: ChatMessageKind.questShare,
    );

    final XpAward? award = _game.awardPartner(
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
    _game.commit(_state.withCouple(_state.couple.addScheduleBlocks(valid)));
    return valid.length;
  }

  void removeScheduleBlock(String blockId) {
    final CoupleState next = _state.couple.removeScheduleBlock(blockId);
    if (identical(next, _state.couple)) return;
    _game.commit(_state.withCouple(next));
  }

  // ── Haftalık bahis ───────────────────────────────────────────────────────

  void setStake(DuelStake stake) {
    if (_state.couple.stake == stake) return;
    _game.commit(_state.withCouple(_state.couple.withStake(stake)));
  }

  // ── Aşk notları / doğum günü ─────────────────────────────────────────────

  /// Doğum günü için kişisel not ekler.
  bool addLoveNote(String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) return false;
    if (_state.couple.isLoveNoteTombstoned(trimmed)) return false;
    _game.commit(_state.withCouple(_state.couple.addLoveNote(trimmed)));
    return true;
  }

  /// Kişisel notu siler ve tombstone bırakır (uzak birleştirme diriltemez).
  bool deleteLoveNote(String note) {
    final CoupleState next = _state.couple.deleteLoveNote(note);
    if (identical(next, _state.couple)) return false;
    _game.commit(_state.withCouple(next));
    return true;
  }

  /// Yusuf'un doğum günü mektubunu kişiselleştirir.
  void setBirthdayMessage(String message) {
    final CoupleState next = _state.couple.withBirthdayMessage(message);
    if (identical(next, _state.couple)) return;
    _game.commit(_state.withCouple(next));
  }
}
