import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/game_state.dart';
import '../core/constants/app_constants.dart';

/// Oyun durumunun kalıcılık sözleşmesi.
///
/// UI/controller yalnızca bu arayüzü bilir; testler [MemoryGameStore] ile
/// disk'e dokunmadan çalışır, üretimde [LocalGameStore] kullanılır.
abstract interface class GameStore {
  GameState? load();

  Future<void> save(GameState state);

  Future<void> clear();

  /// Bekleyen (debounce edilmiş) yazımı hemen tamamlar.
  Future<void> flush();
}

/// Bellek içi store — testler ve `ProviderScope` override'ları için.
final class MemoryGameStore implements GameStore {
  MemoryGameStore([this._state]);

  GameState? _state;

  @override
  GameState? load() => _state;

  @override
  Future<void> save(GameState state) async {
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = null;
  }

  @override
  Future<void> flush() async {}
}

/// `shared_preferences` tabanlı yerel store.
///
/// Açılışta bir kez `await LocalGameStore.open()` edilir ve `ProviderScope`
/// override'ı ile verilir; böylece `GameController.build()` senkron kalır ve
/// uygulama açılışta "loading" ekranı göstermek zorunda olmaz.
final class LocalGameStore implements GameStore {
  LocalGameStore._(this._preferences);

  static const Duration writeDebounce = Duration(milliseconds: 150);

  final SharedPreferences _preferences;

  Timer? _writeTimer;
  GameState? _latest;
  Future<void> _writeChain = Future<void>.value();

  static Future<LocalGameStore> open() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return LocalGameStore._(preferences);
  }

  @override
  GameState? load() {
    final String? raw = _preferences.getString(AppConstants.cacheGameState);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GameState.fromJson(decoded);
      }
      if (decoded is Map) {
        return GameState.fromJson(<String, dynamic>{
          for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
            entry.key.toString(): entry.value,
        });
      }
    } catch (_) {
      // Bozuk cache uygulamayı çökertmez: temiz başlangıç yapılır.
      return null;
    }
    return null;
  }

  @override
  Future<void> save(GameState state) {
    _latest = state;
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDebounce, () {
      unawaited(_writeLatest());
    });
    return _writeChain;
  }

  /// Uygulama arka plana girerken / kapanırken bekleyen yazımı zorlar.
  @override
  Future<void> flush() {
    _writeTimer?.cancel();
    _writeTimer = null;
    return _writeLatest();
  }

  Future<void> _writeLatest() {
    final GameState? state = _latest;
    if (state == null) return _writeChain;
    final String payload = jsonEncode(state.toJson());
    _writeChain = _writeChain
        .catchError((Object _) {
          // Önceki yazım hatası sonraki denemeyi engellemesin.
        })
        .then(
          (_) => _preferences.setString(AppConstants.cacheGameState, payload),
        );
    return _writeChain;
  }

  @override
  Future<void> clear() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    _latest = null;
    try {
      await _writeChain;
    } catch (_) {
      // Önceki hata temizliği engellemez.
    }
    await _preferences.remove(AppConstants.cacheGameState);
  }
}

/// Varsayılan: bellek içi (web/masaüstü testlerinde güvenli).
///
/// `main.dart` bunu [LocalGameStore] ile override eder.
final Provider<GameStore> gameStoreProvider = Provider<GameStore>(
  (Ref ref) => MemoryGameStore(),
);
