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

  GameState? get dirtyState;

  bool get hasDirtyState;

  Future<void> enqueueMessage(ChatMessage message);

  Future<void> dequeueMessage(String messageId);

  Future<void> markSynced(Iterable<String> messageIds);

  Future<void> saveDirtyState(GameState state);

  Future<void> clearDirtyState();

  Future<void> clear();
}

/// Testler için bellek içi outbox.
final class MemorySyncOutbox implements SyncOutbox {
  MemorySyncOutbox({
    List<ChatMessage> pending = const <ChatMessage>[],
    Set<String> synced = const <String>{},
    GameState? dirtyState,
  }) : _pending = <ChatMessage>[...pending],
       _synced = <String>{...synced},
       _dirty = dirtyState;

  final List<ChatMessage> _pending;
  final Set<String> _synced;
  GameState? _dirty;

  @override
  Future<void> load() async {}

  @override
  List<ChatMessage> get pendingMessages =>
      List<ChatMessage>.unmodifiable(_pending);

  @override
  Set<String> get syncedMessageIds => Set<String>.unmodifiable(_synced);

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
  }

  @override
  Future<void> saveDirtyState(GameState state) async {
    _dirty = state;
  }

  @override
  Future<void> clearDirtyState() async {
    _dirty = null;
  }

  @override
  Future<void> clear() async {
    _pending.clear();
    _synced.clear();
    _dirty = null;
  }
}

/// `SharedPreferences` tabanlı kalıcı outbox.
final class LocalSyncOutbox implements SyncOutbox {
  LocalSyncOutbox._(this._preferences);

  static const String pendingKey = 'sync.outbox.pending_messages';
  static const String syncedKey = 'sync.outbox.synced_message_ids';
  static const String dirtyKey = 'sync.outbox.dirty_state';
  static const int maxSyncedIds = 1500;

  final SharedPreferences _preferences;
  final List<ChatMessage> _pending = <ChatMessage>[];
  final Set<String> _synced = <String>{};
  GameState? _dirty;
  bool _loaded = false;

  static Future<LocalSyncOutbox> open() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
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
              final ChatMessage message = ChatMessage.fromJson(
                <String, dynamic>{
                  for (final MapEntry<dynamic, dynamic> entry in item.entries)
                    entry.key.toString(): entry.value,
                },
              );
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
  Future<void> saveDirtyState(GameState state) async {
    _dirty = state;
    await _preferences.setString(dirtyKey, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clearDirtyState() async {
    if (_dirty == null) return;
    _dirty = null;
    await _preferences.remove(dirtyKey);
  }

  @override
  Future<void> clear() async {
    _pending.clear();
    _synced.clear();
    _dirty = null;
    await _preferences.remove(pendingKey);
    await _preferences.remove(syncedKey);
    await _preferences.remove(dirtyKey);
  }

  Future<void> _persistPending() => _preferences.setString(
    pendingKey,
    jsonEncode(<Map<String, dynamic>>[
      for (final ChatMessage message in _pending) message.toJson(),
    ]),
  );
}
