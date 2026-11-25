import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/cloud_sync_coordinator.dart';
import 'package:levelup_life/services/push_service.dart';
import 'package:levelup_life/services/supabase_sync_service.dart';
import 'package:levelup_life/services/sync_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeBackend implements CloudSyncBackend {
  _FakeBackend({this.connected = false});

  bool connected;
  final List<ChatMessage> inserted = <ChatMessage>[];
  final List<GameState> pushed = <GameState>[];
  final List<String> deleted = <String>[];
  final List<bool> typingEvents = <bool>[];
  final List<String> readMessageIds = <String>[];
  final List<String> reactionEvents = <String>[];
  final List<bool> memberHealthPushes = <bool>[];

  @override
  bool get isConnected => connected;

  @override
  Future<bool> connect(SyncConfig config) async {
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    deleted.add(messageId);
    return true;
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    int limit = 200,
    DateTime? before,
  }) async => const <ChatMessage>[];

  @override
  Future<bool> insertMessage(ChatMessage message) async {
    inserted.add(message);
    return true;
  }

  @override
  Future<List<ChatMessage>> pullFullHistory({int limit = 200}) async =>
      const <ChatMessage>[];

  @override
  Future<bool> pushState(GameState state) async {
    pushed.add(state);
    return true;
  }

  @override
  Future<bool> setTyping(bool typing) async {
    typingEvents.add(typing);
    return true;
  }

  @override
  Future<String?> uploadMediaBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async => null;

  @override
  Future<int> markMessagesRead(DateTime upTo) async {
    readMessageIds.add(upTo.toIso8601String());
    return 1;
  }

  @override
  Future<bool> toggleMessageReaction(String messageId, String emoji) async {
    reactionEvents.add('$messageId:$emoji');
    return true;
  }

  @override
  Future<void> updateMemberHealth({
    required bool pushEnabled,
    required int? quietStartMinute,
    required int? quietEndMinute,
    required int utcOffsetMinutes,
  }) async {
    memberHealthPushes.add(pushEnabled);
  }

  @override
  Future<bool> refreshSessionAndMembership() async => true;
}

const AppSettings _cloudSettings = AppSettings(
  supabaseUrl: 'https://demo.supabase.co',
  supabaseAnonKey: 'anon-key',
  roomCode: 'YUSUF-CEYDA-2026',
  deviceRole: CouplePartner.yusufId,
);

const AppSettings _pushSettings = AppSettings(
  supabaseUrl: 'https://demo.supabase.co',
  supabaseAnonKey: 'anon-key',
  roomCode: 'YUSUF-CEYDA-2026',
  deviceRole: CouplePartner.yusufId,
  oneSignalAppId: 'onesignal-app-id',
);

CloudSyncCoordinator _coordinator(
  ProviderContainer container,
  CloudSyncBackend backend,
  SyncOutbox outbox, {
  ChatPushDispatcher? pushDispatcher,
}) {
  final Provider<CloudSyncCoordinator> provider =
      Provider<CloudSyncCoordinator>(
        (Ref ref) => CloudSyncCoordinator(
          ref,
          backend: backend,
          outbox: outbox,
          pushDispatcher: pushDispatcher,
        ),
      );
  return container.read(provider);
}

void main() {
  group('MemorySyncOutbox', () {
    test('mesaj kuyruğu, senkron kümesi ve kirli durum ayrı tutulur', () async {
      final MemorySyncOutbox outbox = MemorySyncOutbox();
      final ChatMessage message = ChatMessage(
        id: 'm1',
        senderId: CouplePartner.yusufId,
        createdAt: DateTime(2026, 11, 23),
        text: 'çevrimdışı',
      );

      await outbox.enqueueMessage(message);
      await outbox.enqueueMessage(message);
      expect(outbox.pendingMessages, hasLength(1));
      expect(outbox.syncedMessageIds, isEmpty);

      await outbox.markSynced(<String>['m1']);
      await outbox.dequeueMessage('m1');
      expect(outbox.pendingMessages, isEmpty);
      expect(outbox.syncedMessageIds, contains('m1'));

      await outbox.saveDirtyState(CoupleBootstrap.initialState());
      expect(outbox.hasDirtyState, isTrue);
      await outbox.clearDirtyState();
      expect(outbox.hasDirtyState, isFalse);
    });
  });

  group('LocalSyncOutbox kalıcılığı', () {
    test(
      'uygulama yeniden açılsa bile bekleyen mesaj ve senkron kümesi kalır',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final ChatMessage message = ChatMessage(
          id: 'persist-1',
          senderId: CouplePartner.yusufId,
          createdAt: DateTime(2026, 11, 23),
          text: 'kapanmadan önce',
        );

        final LocalSyncOutbox first = await LocalSyncOutbox.open();
        await first.enqueueMessage(message);
        await first.markSynced(<String>['old-1']);
        await first.markPushPending(<String>['persist-1']);
        await first.saveDirtyState(CoupleBootstrap.initialState());

        final LocalSyncOutbox reopened = await LocalSyncOutbox.open();
        expect(
          reopened.pendingMessages.map((ChatMessage m) => m.id),
          contains('persist-1'),
        );
        expect(reopened.syncedMessageIds, contains('old-1'));
        expect(reopened.pendingPushMessageIds, contains('persist-1'));
        expect(reopened.hasDirtyState, isTrue);

        await reopened.markPushed(<String>['persist-1']);
        expect(reopened.pendingPushMessageIds, isEmpty);
        expect(reopened.pushedMessageIds, contains('persist-1'));

        await reopened.clear();
        final LocalSyncOutbox cleared = await LocalSyncOutbox.open();
        expect(cleared.pendingMessages, isEmpty);
        expect(cleared.syncedMessageIds, isEmpty);
        expect(cleared.hasDirtyState, isFalse);
      },
    );
  });

  group('CloudSyncCoordinator outbox akışı', () {
    late GameState seed;
    late ProviderContainer container;
    late _FakeBackend backend;

    setUp(() {
      seed = CoupleBootstrap.initialState();
      backend = _FakeBackend(connected: false);
      container = ProviderContainer(
        overrides: [gameStoreProvider.overrideWithValue(MemoryGameStore(seed))],
      );
      addTearDown(container.dispose);
    });

    test(
      'bağlantı gelince bekleyen mesajlar ve kirli durum gönderilir',
      () async {
        final ChatMessage pending = ChatMessage(
          id: 'offline-1',
          senderId: CouplePartner.yusufId,
          createdAt: DateTime(2026, 11, 23, 10),
          text: 'çevrimdışı yazıldı',
        );
        final MemorySyncOutbox outbox = MemorySyncOutbox(
          pending: <ChatMessage>[pending],
          dirtyState: seed,
        );
        final CloudSyncCoordinator coordinator = _coordinator(
          container,
          backend,
          outbox,
        );

        await coordinator.configure(_cloudSettings);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          backend.inserted.map((ChatMessage m) => m.id),
          contains('offline-1'),
        );
        expect(outbox.pendingMessages, isEmpty);
        expect(outbox.syncedMessageIds, contains('offline-1'));
        expect(backend.pushed, isNotEmpty);
      },
    );

    test('çevrimdışı yeni mesaj kalıcı kuyruğa yazılır', () async {
      final MemorySyncOutbox outbox = MemorySyncOutbox();
      final CloudSyncCoordinator coordinator = _coordinator(
        container,
        backend,
        outbox,
      );
      // Bağlantı bir kez kurulur (geçmiş bilinir), sonra kopar.
      await coordinator.configure(_cloudSettings);
      // Konfigürasyon sonrası backfill'in tamamlanmasını bekle.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      backend.connected = false;
      backend.inserted.clear();

      final ChatMessage fresh = container
          .read(gameProvider.notifier)
          .sendMessage('kuyruğa gir')!;
      final GameState state = container.read(gameProvider);

      coordinator.onLocalStateChanged(state);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        outbox.pendingMessages.map((ChatMessage m) => m.id),
        contains(fresh.id),
      );
      expect(coordinator.pendingMessageCount, 1);
      expect(backend.inserted, isEmpty);
      expect(outbox.hasDirtyState, isTrue);
    });

    test('bağlantı kopunca durum diske "kirli" olarak yazılır', () async {
      final MemorySyncOutbox outbox = MemorySyncOutbox();
      final CloudSyncCoordinator coordinator = _coordinator(
        container,
        backend,
        outbox,
      );
      await coordinator.configure(_cloudSettings);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      backend.connected = false;
      await coordinator.disconnect();

      expect(outbox.hasDirtyState, isTrue);
      expect(coordinator.isConnected, isFalse);
    });

    test(
      'gönderenin sessiz saati / kapalı bildirimi partner push’unu engellemez',
      () async {
        const AppSettings senderDnd = AppSettings(
          supabaseUrl: 'https://demo.supabase.co',
          supabaseAnonKey: 'anon-key',
          roomCode: 'YUSUF-CEYDA-2026',
          deviceRole: CouplePartner.yusufId,
          oneSignalAppId: 'onesignal-app-id',
          messageNotifications: false,
          doNotDisturbEnabled: true,
          quietStartMinutes: 0,
          quietEndMinutes: 1439,
        );
        final ProviderContainer local = ProviderContainer(
          overrides: [
            gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
            appSettingsStoreProvider.overrideWithValue(
              MemoryAppSettingsStore(senderDnd),
            ),
          ],
        );
        addTearDown(local.dispose);
        final _FakeBackend localBackend = _FakeBackend(connected: false);
        final List<ChatMessage> pushed = <ChatMessage>[];
        final CloudSyncCoordinator coordinator = _coordinator(
          local,
          localBackend,
          MemorySyncOutbox(),
          pushDispatcher:
              ({
                required AppSettings settings,
                required ChatMessage message,
              }) async {
                pushed.add(message);
                return const PushResult(
                  ok: true,
                  statusCode: 200,
                  message: 'ok',
                );
              },
        );

        await coordinator.configure(senderDnd);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final ChatMessage message = local
            .read(gameProvider.notifier)
            .sendMessage('sessiz saatte gönderildi')!;
        coordinator.onLocalStateChanged(local.read(gameProvider));
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(
          localBackend.inserted.map((ChatMessage item) => item.id),
          contains(message.id),
        );
        expect(pushed.map((ChatMessage item) => item.id), <String>[message.id]);

        // Debounce Timer'ını test bitmeden iptal et.
        await coordinator.disconnect();
      },
    );

    test(
      'çevrimdışı mesaj bağlantı gelince yazılır ve push tam 1 kez gider',
      () async {
        final ProviderContainer local = ProviderContainer(
          overrides: [
            gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
            appSettingsStoreProvider.overrideWithValue(
              MemoryAppSettingsStore(_pushSettings),
            ),
          ],
        );
        addTearDown(local.dispose);
        final _FakeBackend localBackend = _FakeBackend(connected: false);
        final MemorySyncOutbox outbox = MemorySyncOutbox();
        final List<ChatMessage> pushed = <ChatMessage>[];
        final CloudSyncCoordinator coordinator = _coordinator(
          local,
          localBackend,
          outbox,
          pushDispatcher:
              ({
                required AppSettings settings,
                required ChatMessage message,
              }) async {
                pushed.add(message);
                return const PushResult(
                  ok: true,
                  statusCode: 200,
                  message: 'ok',
                );
              },
        );

        await coordinator.configure(_pushSettings);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        localBackend.connected = false;
        localBackend.inserted.clear();

        final ChatMessage offline = local
            .read(gameProvider.notifier)
            .sendMessage('uçak modunda')!;
        coordinator.onLocalStateChanged(local.read(gameProvider));
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(
          outbox.pendingMessages.map((ChatMessage item) => item.id),
          contains(offline.id),
        );
        expect(pushed, isEmpty);

        localBackend.connected = true;
        await coordinator.configure(_pushSettings);
        await Future<void>.delayed(const Duration(milliseconds: 160));
        expect(
          localBackend.inserted.map((ChatMessage item) => item.id),
          <String>[offline.id],
        );
        expect(pushed.map((ChatMessage item) => item.id), <String>[offline.id]);
        expect(outbox.pushedMessageIds, contains(offline.id));

        // Tekrar configure / flush aynı mesajı ikinci kez push etmez.
        await coordinator.configure(_pushSettings);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(pushed, hasLength(1));
      },
    );

    test(
      'boş/tekrarlı uzak olay sonrası yerel değişiklik buluta gider',
      () async {
        final ProviderContainer local = ProviderContainer(
          overrides: [
            gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
            appSettingsStoreProvider.overrideWithValue(
              MemoryAppSettingsStore(_cloudSettings),
            ),
          ],
        );
        addTearDown(local.dispose);
        final _FakeBackend localBackend = _FakeBackend(connected: false);
        final CloudSyncCoordinator coordinator = _coordinator(
          local,
          localBackend,
          MemorySyncOutbox(),
        );
        await coordinator.configure(_cloudSettings);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final ChatMessage remote = ChatMessage(
          id: 'remote-1',
          senderId: CouplePartner.ceydaId,
          createdAt: DateTime(2026, 11, 23, 11),
          text: 'uzaktan',
        );
        expect(
          local.read(gameProvider.notifier).receiveRemoteMessage(remote),
          isTrue,
        );
        // Aynı uzak mesaj tekrar gelir ve state değişmez.
        expect(
          local.read(gameProvider.notifier).receiveRemoteMessage(remote),
          isFalse,
        );
        final int pushedBefore = localBackend.pushed.length;

        final ChatMessage localMessage = local
            .read(gameProvider.notifier)
            .sendMessage('uzak olaydan sonra yerel')!;
        coordinator.onLocalStateChanged(local.read(gameProvider));
        // Durum push'u 900 ms debounce sonrasında tetiklenir.
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        expect(
          localBackend.inserted.map((ChatMessage item) => item.id),
          contains(localMessage.id),
        );
        expect(localBackend.pushed.length, greaterThan(pushedBefore));

        await coordinator.disconnect();
      },
    );

    test('çevrimdışı silme bağlantı gelince buluttan silinir', () async {
      final ProviderContainer local = ProviderContainer(
        overrides: [
          gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
          appSettingsStoreProvider.overrideWithValue(
            MemoryAppSettingsStore(_cloudSettings),
          ),
        ],
      );
      addTearDown(local.dispose);
      final _FakeBackend localBackend = _FakeBackend(connected: false);
      final MemorySyncOutbox outbox = MemorySyncOutbox();
      final CloudSyncCoordinator coordinator = _coordinator(
        local,
        localBackend,
        outbox,
      );
      await coordinator.configure(_cloudSettings);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      localBackend.connected = false;
      localBackend.inserted.clear();

      final ChatMessage message = local
          .read(gameProvider.notifier)
          .sendMessage('silinecek')!;
      coordinator.onLocalStateChanged(local.read(gameProvider));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      local.read(gameProvider.notifier).deleteMessage(message.id);
      coordinator.onLocalStateChanged(local.read(gameProvider));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(outbox.pendingDeletes, contains(message.id));
      expect(localBackend.deleted, isEmpty);

      localBackend.connected = true;
      await coordinator.configure(_cloudSettings);
      await Future<void>.delayed(const Duration(milliseconds: 160));

      expect(localBackend.deleted, contains(message.id));
      expect(outbox.pendingDeletes, isEmpty);
    });

    test(
      'ilk push kilidi açılır: art arda iki yerel değişiklik de buluta gider',
      () async {
        final ProviderContainer local = ProviderContainer(
          overrides: [
            gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
            appSettingsStoreProvider.overrideWithValue(
              MemoryAppSettingsStore(_cloudSettings),
            ),
          ],
        );
        addTearDown(local.dispose);
        final _FakeBackend localBackend = _FakeBackend(connected: false);
        final CloudSyncCoordinator coordinator = _coordinator(
          local,
          localBackend,
          MemorySyncOutbox(),
        );
        await coordinator.configure(_cloudSettings);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        // Bağlantı kurulumu ilk tam durum push'unu yapar.
        expect(localBackend.pushed, isNotEmpty);
        final int afterFirstPush = localBackend.pushed.length;

        // 1) Birinci yerel değişiklik → 900 ms debounce → push.
        final ChatMessage first = local
            .read(gameProvider.notifier)
            .sendMessage('birinci değişiklik')!;
        coordinator.onLocalStateChanged(local.read(gameProvider));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        expect(
          localBackend.pushed.length,
          greaterThan(afterFirstPush),
          reason: 'ilk yerel değişiklik buluta yazılmalı',
        );
        final int afterSecondPush = localBackend.pushed.length;

        // 2) İkinci yerel değişiklik: `_statePushInFlight` sıfırlanmazsa bu push
        //    sessizce yutulur (v6.1 regresyonu).
        final ChatMessage second = local
            .read(gameProvider.notifier)
            .sendMessage('ikinci değişiklik')!;
        coordinator.onLocalStateChanged(local.read(gameProvider));
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        expect(
          localBackend.pushed.length,
          greaterThan(afterSecondPush),
          reason: 'push kilidi ilk gönderimden sonra açılmalı',
        );
        final Iterable<String> lastPushMessageIds = localBackend
            .pushed
            .last
            .couple
            .messages
            .map((ChatMessage message) => message.id);
        expect(lastPushMessageIds, contains(first.id));
        expect(lastPushMessageIds, contains(second.id));

        await coordinator.disconnect();
      },
    );
  });
}
