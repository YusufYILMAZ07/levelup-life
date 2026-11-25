import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/game_state.dart';
import '../domain/entities/entities.dart';

/// Çevrimdışıyken biriken mesajlar ve "kirli" durum için kalıcı kuyruk.
///
/// v5'te `_pendingMessages` yalnızca RAM'deydi: uygulama çevrimdışıyken
/// kapatılırsa bekleyen mesajlar kayboluyordu. v6'da kuyruk `SharedPreferences`
/// üzerinde tutulur ve bağlantı gelince otomatik boşaltılır.
abstract interface class SyncOutbox {
  Future<void> load();

  List<ChatMessage> get pendingMessages;

  /// Buluta yazıldığı doğrulanmış mesaj kimlikleri (sınırlı LRU).
  Set<String> get syncedMessageIds;

  /// Partner push'u **başarıyla** gönderilmiş mesaj kimlikleri.
  ///
  /// `syncedMessageIds`'ten ayrıdır: Supabase'e yazılan her mesaj için push
  /// gönderilmeyebilir (partner çevrimiçi, push kapalı vb.). Bu küme aynı
  /// mesaj için ikinci kez Edge Function çağrılmasını engeller.
  Set<String> get pushedMessageIds;

  /// Push'u henüz kesinleşmemiş mesaj kimlikleri.
  ///
  /// Uygulama push gönderemeden kapansa bile açılışta son 50 mesaj içinden
  /// bu küme taranır ve push tamamlanır. Aynı küme çevrimdışı outbox
  /// mesajlarının bağlantı gelince push edilmesini de garanti eder.
  Set<String> get pendingPushMessageIds;

  /// Çevrimdışıyken silinip bağlantı gelince buluttan da silinmesi gereken
  /// mesaj kimlikleri.
  Set<String> get pendingDeletes;

  GameState? get dirtyState;

  bool get hasDirtyState;

  Future<void> enqueueMessage(ChatMessage message);

  Future<void> dequeueMessage(String messageId);

  Future<void> markSynced(Iterable<String> messageIds);

  Future<void> markPushPending(Iterable<String> messageIds);

  Future<void> markPushed(Iterable<String> messageIds);

  Future<void> enqueueDelete(String messageId);

  Future<void> dequeueDelete(String messageId);

  Future<void> saveDirtyState(GameState state);

  Future<void> clearDirtyState();

  Future<void> clear();
}

/// Testler için bellek içi outbox.
final class MemorySyncOutbox implements SyncOutbox {
  MemorySyncOutbox({
    List<ChatMessage> pending = const <ChatMessage>[],
    Set<String> synced = const <String>{},
    Set<String> pushed = const <String>{},
    Set<String> pushPending = const <String>{},
    Set<String> pendingDeletes = const <String>{},
    GameState? dirtyState,
  }) : _pending = <ChatMessage>[...pending],
       _synced = <String>{...synced},
       _pushed = <String>{...pushed},
       _pushPending = <String>{...pushPending},
       _pendingDeletes = <String>{...pendingDeletes},
       _dirty = dirtyState;

  final List<ChatMessage> _pending;
  final Set<String> _synced;
  final Set<String> _pushed;
  final Set<String> _pushPending;
  final Set<String> _pendingDeletes;
  GameState? _dirty;

  @override
  Future<void> load() async {}

  @override
  List<ChatMessage> get pendingMessages =>
      List<ChatMessage>.unmodifiable(_pending);

  @override
  Set<String> get syncedMessageIds => Set<String>.unmodifiable(_synced);

  @override
  Set<String> get pushedMessageIds => Set<String>.unmodifiable(_pushed);

  @override
  Set<String> get pendingPushMessageIds =>
      Set<String>.unmodifiable(_pushPending);

  @override
  Set<String> get pendingDeletes => Set<String>.unmodifiable(_pendingDeletes);

  @override
  GameState? get dirtyState => _dirty;

  @override
  bool get hasDirtyState => _dirty != null;

  @override
  Future<void> enqueueMessage(ChatMessage message) async {
    if (_pending.any((ChatMessage item) => item.id == message.id)) return;
    _pending.add(message);
  }

  @override
  Future<void> dequeueMessage(String messageId) async {
    _pending.removeWhere((ChatMessage item) => item.id == messageId);
  }

  @override
  Future<void> markSynced(Iterable<String> messageIds) async {
    _synced.addAll(messageIds);
    _trimToMaxSynced(_synced);
  }

  @override
  Future<void> markPushPending(Iterable<String> messageIds) async {
    _pushPending.addAll(messageIds);
  }

  @override
  Future<void> markPushed(Iterable<String> messageIds) async {
    _pushed.addAll(messageIds);
    _trimToMaxSynced(_pushed);
    _pushPending.removeAll(messageIds);
  }

  @override
  Future<void> enqueueDelete(String messageId) async {
    _pendingDeletes.add(messageId);
  }

  @override
  Future<void> dequeueDelete(String messageId) async {
    _pendingDeletes.remove(messageId);
  }

  @override
  Future<void> saveDirtyState(GameState state) async {
    _dirty = state;
  }

  @override
  Future<void> clearDirtyState() async {
    _dirty = null;
  }

  static const int maxSyncedIds = 1500;

  static void _trimToMaxSynced(Set<String> ids) {
    if (ids.length <= maxSyncedIds) return;
    final List<String> trimmed = ids.toList(growable: false);
    final List<String> kept = trimmed.sublist(trimmed.length - maxSyncedIds);
    ids
      ..clear()
      ..addAll(kept);
  }

  @override
  Future<void> clear() async {
    _pending.clear();
    _synced.clear();
    _pushed.clear();
    _pushPending.clear();
    _pendingDeletes.clear();
    _dirty = null;
  }
}

/// `SharedPreferences` tabanlı kalıcı outbox.
final class LocalSyncOutbox implements SyncOutbox {
  LocalSyncOutbox._(this._preferences);

  static const String pendingKey = 'sync.outbox.pending_messages';
  static const String syncedKey = 'sync.outbox.synced_message_ids';
  static const String pushedKey = 'sync.outbox.pushed_message_ids';
  static const String pushPendingKey = 'sync.outbox.pending_push_message_ids';
  static const String pendingDeletesKey = 'sync.outbox.pending_deletes';
  static const String dirtyKey = 'sync.outbox.dirty_state';
  static const int maxSyncedIds = 1500;

  final SharedPreferences _preferences;
  final List<ChatMessage> _pending = <ChatMessage>[];
  final Set<String> _synced = <String>{};
  final Set<String> _pushed = <String>{};
  final Set<String> _pushPending = <String>{};
  final Set<String> _pendingDeletes = <String>{};
  GameState? _dirty;
  bool _loaded = false;
  Future<void> _dirtyWriteChain = Future<void>.value();

  static Future<LocalSyncOutbox> open() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LocalSyncOutbox outbox = LocalSyncOutbox._(preferences);
    await outbox.load();
    return outbox;
  }

  @override
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final String? rawPending = _preferences.getString(pendingKey);
    if (rawPending != null && rawPending.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawPending);
        if (decoded is List) {
          for (final Object? item in decoded) {
            if (item is! Map) continue;
            try {
              final ChatMessage message =
                  ChatMessage.fromJson(<String, dynamic>{
                    for (final MapEntry<dynamic, dynamic> entry in item.entries)
                      entry.key.toString(): entry.value,
                  });
              if (message.id.trim().isNotEmpty) _pending.add(message);
            } catch (_) {
              // Tek bozuk satır kuyruğun tamamını düşürmez.
            }
          }
        }
      } catch (_) {
        // Bozuk kuyruk temizlenir.
      }
    }
    final String? rawSynced = _preferences.getString(syncedKey);
    if (rawSynced != null && rawSynced.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawSynced);
        if (decoded is List) {
          for (final Object? item in decoded) {
            final String id = item?.toString().trim() ?? '';
            if (id.isNotEmpty) _synced.add(id);
          }
        }
      } catch (_) {
        // Sessiz.
      }
    }
    final String? rawPushed = _preferences.getString(pushedKey);
    if (rawPushed != null && rawPushed.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawPushed);
        if (decoded is List) {
          for (final Object? item in decoded) {
            final String id = item?.toString().trim() ?? '';
            if (id.isNotEmpty) _pushed.add(id);
          }
        }
      } catch (_) {
        // Sessiz.
      }
    }
    final String? rawPushPending = _preferences.getString(pushPendingKey);
    if (rawPushPending != null && rawPushPending.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawPushPending);
        if (decoded is List) {
          for (final Object? item in decoded) {
            final String id = item?.toString().trim() ?? '';
            if (id.isNotEmpty) _pushPending.add(id);
          }
        }
      } catch (_) {
        // Sessiz.
      }
    }
    final String? rawPendingDeletes = _preferences.getString(pendingDeletesKey);
    if (rawPendingDeletes != null && rawPendingDeletes.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawPendingDeletes);
        if (decoded is List) {
          for (final Object? item in decoded) {
            final String id = item?.toString().trim() ?? '';
            if (id.isNotEmpty) _pendingDeletes.add(id);
          }
        }
      } catch (_) {
        // Sessiz.
      }
    }
    final String? rawDirty = _preferences.getString(dirtyKey);
    if (rawDirty != null && rawDirty.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawDirty);
        if (decoded is Map) {
          _dirty = GameState.fromJson(<String, dynamic>{
            for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
              entry.key.toString(): entry.value,
          });
        }
      } catch (_) {
        // Bozuk taslak yok sayılır.
      }
    }
  }

  @override
  List<ChatMessage> get pendingMessages =>
      List<ChatMessage>.unmodifiable(_pending);

  @override
  Set<String> get syncedMessageIds => Set<String>.unmodifiable(_synced);

  @override
  Set<String> get pushedMessageIds => Set<String>.unmodifiable(_pushed);

  @override
  Set<String> get pendingPushMessageIds =>
      Set<String>.unmodifiable(_pushPending);

  @override
  Set<String> get pendingDeletes => Set<String>.unmodifiable(_pendingDeletes);

  @override
  GameState? get dirtyState => _dirty;

  @override
  bool get hasDirtyState => _dirty != null;

  @override
  Future<void> enqueueMessage(ChatMessage message) async {
    if (_pending.any((ChatMessage item) => item.id == message.id)) return;
    _pending.add(message);
    await _persistPending();
  }

  @override
  Future<void> dequeueMessage(String messageId) async {
    final int before = _pending.length;
    _pending.removeWhere((ChatMessage item) => item.id == messageId);
    if (_pending.length != before) await _persistPending();
  }

  @override
  Future<void> markSynced(Iterable<String> messageIds) async {
    final int before = _synced.length;
    _synced.addAll(messageIds);
    if (_synced.length == before) return;
    if (_synced.length > maxSyncedIds) {
      final List<String> trimmed = _synced.toList(growable: false);
      final List<String> kept = trimmed.sublist(trimmed.length - maxSyncedIds);
      _synced
        ..clear()
        ..addAll(kept);
    }
    await _preferences.setString(syncedKey, jsonEncode(_synced.toList()));
  }

  @override
  Future<void> markPushPending(Iterable<String> messageIds) async {
    final int before = _pushPending.length;
    _pushPending.addAll(messageIds);
    if (_pushPending.length == before) return;
    if (_pushPending.length > maxSyncedIds) {
      final List<String> trimmed = _pushPending.toList(growable: false);
      final List<String> kept = trimmed.sublist(trimmed.length - maxSyncedIds);
      _pushPending
        ..clear()
        ..addAll(kept);
    }
    await _preferences.setString(
      pushPendingKey,
      jsonEncode(_pushPending.toList()),
    );
  }

  @override
  Future<void> markPushed(Iterable<String> messageIds) async {
    final int before = _pushed.length;
    _pushed.addAll(messageIds);
    _pushPending.removeAll(messageIds);
    if (_pushed.length != before) {
      if (_pushed.length > maxSyncedIds) {
        final List<String> trimmed = _pushed.toList(growable: false);
        final List<String> kept = trimmed.sublist(
          trimmed.length - maxSyncedIds,
        );
        _pushed
          ..clear()
          ..addAll(kept);
      }
      await _preferences.setString(pushedKey, jsonEncode(_pushed.toList()));
    }
    await _preferences.setString(
      pushPendingKey,
      jsonEncode(_pushPending.toList()),
    );
  }

  @override
  Future<void> enqueueDelete(String messageId) async {
    final String id = messageId.trim();
    if (id.isEmpty || !_pendingDeletes.add(id)) return;
    await _preferences.setString(
      pendingDeletesKey,
      jsonEncode(_pendingDeletes.toList()),
    );
  }

  @override
  Future<void> dequeueDelete(String messageId) async {
    final String id = messageId.trim();
    if (id.isEmpty) return;
    final bool removed = _pendingDeletes.remove(id);
    if (!removed) return;
    await _preferences.setString(
      pendingDeletesKey,
      jsonEncode(_pendingDeletes.toList()),
    );
  }

  @override
  Future<void> saveDirtyState(GameState state) {
    _dirty = state;
    // Dirty state yazımları seri kuyrukla korunur: sonraki yazım öncekini
    // ezmez, kapatma anında da flush güvenli olur.
    _dirtyWriteChain = _dirtyWriteChain.catchError((Object _) {}).then((
      _,
    ) async {
      await _preferences.setString(dirtyKey, jsonEncode(state.toJson()));
    });
    return _dirtyWriteChain;
  }

  @override
  Future<void> clearDirtyState() {
    // v6.2: `_dirty` zaten null olsa bile **sırada bekleyen** yazımın
    // (saveDirtyState) tamamlanmasını bekle; aksi hâlde erken `Future.value()`
    // dönen çağıran, diskteki kirli taslağın silindiğini sanır.
    _dirty = null;
    _dirtyWriteChain = _dirtyWriteChain.catchError((Object _) {}).then((
      _,
    ) async {
      await _preferences.remove(dirtyKey);
    });
    return _dirtyWriteChain;
  }

  @override
  Future<void> clear() async {
    _pending.clear();
    _synced.clear();
    _pushed.clear();
    _pushPending.clear();
    _pendingDeletes.clear();
    _dirty = null;
    // Dirty yazımları tek kuyrukta serileştiği için silme de kuyruğa girer:
    // bekleyen `saveDirtyState` bitmeden `remove(dirtyKey)` çalışmaz, böylece
    // clear() sonrasında anahtar yeniden oluşmaz.
    _dirtyWriteChain = _dirtyWriteChain.catchError((Object _) {}).then((
      _,
    ) async {
      await _preferences.remove(dirtyKey);
    });
    await _preferences.remove(pendingKey);
    await _preferences.remove(syncedKey);
    await _preferences.remove(pushedKey);
    await _preferences.remove(pushPendingKey);
    await _preferences.remove(pendingDeletesKey);
    await _dirtyWriteChain;
  }

  Future<void> _persistPending() => _preferences.setString(
    pendingKey,
    jsonEncode(<Map<String, dynamic>>[
      for (final ChatMessage message in _pending) message.toJson(),
    ]),
  );
}
