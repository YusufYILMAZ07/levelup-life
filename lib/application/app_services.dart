import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import '../application/game_state.dart';
import '../application/pin_lock_controller.dart';
import '../domain/entities/entities.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_coordinator.dart';
import '../services/notification_service.dart';

/// Uygulama yaşam döngüsüne bağlı yan etkiler:
///
/// * yeni partner mesajı → gerçek OS bildirimi
/// * plan saatleri → 10 dk önce haftalık hatırlatıcı
/// * 21:30 akşam puanı hatırlatıcısı
/// * Supabase ayarları değişince bağlan / kop
/// * arka plana geçince PIN kilidi
class AppServices extends ConsumerStatefulWidget {
  const AppServices({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppServices> createState() => _AppServicesState();
}

class _AppServicesState extends ConsumerState<AppServices>
    with WidgetsBindingObserver {
  String _planSignature = '';
  Set<String> _openedCapsules = <String>{};
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _openedCapsules = ref
        .read(gameProvider)
        .couple
        .rewardCapsules
        .where((RewardCapsule capsule) => capsule.isOpened)
        .map((RewardCapsule capsule) => capsule.id)
        .toSet();

    final AppSettings settings = ref.read(appSettingsProvider);
    final bool ready = await NotificationService.instance.init();
    if (ready &&
        (settings.messageNotifications ||
            settings.planReminders ||
            settings.dailyCheckinReminder)) {
      await NotificationService.instance.requestPermissions();
    }
    _booted = true;
    if (!mounted) return;
    _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
    await ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(pinLockProvider.notifier).lockIfEnabled();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _syncSchedules(ref.read(gameProvider), ref.read(appSettingsProvider));
      unawaited(
        ref.read(cloudSyncProvider).configure(ref.read(appSettingsProvider)),
      );
    }
  }

  void _handleNewMessages(GameState previous, GameState next) {
    if (!ref.read(appSettingsProvider).messageNotifications) return;
    final Set<String> known = previous.couple.messages
        .map((ChatMessage message) => message.id)
        .toSet();
    for (final ChatMessage message in next.couple.messages) {
      if (known.contains(message.id)) continue;
      // Kendi gönderdiğim mesaj için bildirim çıkarmayız.
      if (message.senderId == next.activePartnerId) continue;
      unawaited(NotificationService.instance.showPartnerMessage(message));
    }
  }

  void _handleCapsules(GameState previous, GameState next) {
    final Set<String> opened = next.couple.rewardCapsules
        .where((RewardCapsule capsule) => capsule.isOpened)
        .map((RewardCapsule capsule) => capsule.id)
        .toSet();
    final Set<String> fresh = opened.difference(_openedCapsules);
    _openedCapsules = opened;
    if (fresh.isEmpty || !ref.read(appSettingsProvider).messageNotifications) {
      return;
    }
    // Toplu geçmiş çekiminde bildirim yağmuru olmasın: yalnızca en son açılan.
    RewardCapsule? latest;
    for (final RewardCapsule capsule in next.couple.rewardCapsules) {
      if (!fresh.contains(capsule.id)) continue;
      final DateTime at =
          capsule.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime best =
          latest?.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latest == null || at.isAfter(best)) latest = capsule;
    }
    if (latest != null) {
      unawaited(NotificationService.instance.showCapsuleUnlocked(latest));
    }
  }

  /// Karşı telefondan gelen rubrik / plan değişimlerini sessizce bildirir.
  void _handleRemoteActivity(GameState previous, GameState next) {
    final AppSettings settings = ref.read(appSettingsProvider);
    if (!settings.messageNotifications) return;
    final String partnerId = CouplePartner.other(settings.deviceRole);
    if (!_sameScores(previous.couple.rubricScores, next.couple.rubricScores)) {
      unawaited(
        NotificationService.instance.showPartnerActivity(
          partnerId: partnerId,
          body: 'Gelişim puanlarını güncelledi ⭐',
          payload: 'sync-rubric',
        ),
      );
    }
    if (_planSignatureOf(previous) != _planSignatureOf(next)) {
      unawaited(
        NotificationService.instance.showPartnerActivity(
          partnerId: partnerId,
          body: 'Haftalık planını güncelledi 📅',
          payload: 'sync-plan',
        ),
      );
    }
  }

  static bool _sameScores(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, int> entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static String _planSignatureOf(GameState state) => state.couple.scheduleBlocks
      .map(
        (ScheduleBlock block) =>
            '${block.id}:${block.weekday}:${block.startMinutes}:'
            '${block.title}',
      )
      .join('|');

  void _syncSchedules(GameState state, AppSettings settings) {
    final List<ScheduleBlock> blocks = state.couple.scheduleBlocks;
    final String signature = <String>[
      settings.planReminders.toString(),
      settings.dailyCheckinReminder.toString(),
      state.activePartnerId,
      for (final ScheduleBlock block in blocks)
        '${block.id}:${block.startMinutes}:${block.title}',
    ].join('|');
    if (signature == _planSignature || !_booted) return;
    _planSignature = signature;

    if (settings.planReminders) {
      unawaited(
        NotificationService.instance.syncPlanReminders(
          partnerId: state.activePartnerId,
          blocks: blocks,
        ),
      );
    } else {
      unawaited(NotificationService.instance.cancelPlanReminders());
    }
    if (settings.dailyCheckinReminder) {
      unawaited(NotificationService.instance.scheduleDailyCheckin());
    } else {
      unawaited(NotificationService.instance.cancelDailyCheckin());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameProvider, (GameState? previous, GameState next) {
      if (previous == null) return;
      final CloudSyncCoordinator cloud = ref.read(cloudSyncProvider);
      if (cloud.isApplyingRemote) {
        // Geçmiş toplu çekilirken her mesaj için bildirim gösterilmez.
        _handleRemoteActivity(previous, next);
      } else {
        _handleNewMessages(previous, next);
      }
      _handleCapsules(previous, next);
      _syncSchedules(next, ref.read(appSettingsProvider));
      cloud.onLocalStateChanged(next);
    });

    ref.listen<AppSettings>(appSettingsProvider, (
      AppSettings? previous,
      AppSettings next,
    ) {
      if (previous == null) return;
      ref.read(pinLockProvider.notifier).syncWithSettings();
      _syncSchedules(ref.read(gameProvider), next);
      unawaited(ref.read(cloudSyncProvider).configure(next));
    });

    return widget.child;
  }
}
