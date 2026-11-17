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
}

/// `shared_preferences` tabanlı yerel store.
///
/// Açılışta bir kez `await LocalGameStore.open()` edilir ve `ProviderScope`
/// override'ı ile verilir; böylece `GameController.build()` senkron kalır ve
/// uygulama açılışta "loading" ekranı göstermek zorunda olmaz.
final class LocalGameStore implements GameStore {
  LocalGameStore._(this._preferences);

  final SharedPreferences _preferences;

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
        return GameState.fromJson(
          <String, dynamic>{
            for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
              entry.key.toString(): entry.value,
          },
        );
      }
    } catch (_) {
      // Bozuk cache uygulamayı çökertmez: temiz başlangıç yapılır.
      return null;
    }
    return null;
  }

  @override
  Future<void> save(GameState state) async {
    await _preferences.setString(
      AppConstants.cacheGameState,
      jsonEncode(state.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(AppConstants.cacheGameState);
  }
}

/// Varsayılan: bellek içi (web/masaüstü testlerinde güvenli).
///
/// `main.dart` bunu [LocalGameStore] ile override eder.
final Provider<GameStore> gameStoreProvider = Provider<GameStore>(
  (Ref ref) => MemoryGameStore(),
);
