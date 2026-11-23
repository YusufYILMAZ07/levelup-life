import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Dönen Future **gerçek disk yazımı tamamlanınca** resolve olur.
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

/// Şema sürümü — v6. Bilinmeyen/yeni sürümler bozuk sayılmaz; okunur.
const int gameStateSchemaVersion = 6;

/// Büyük JSON'u ana isolate'i bloklamadan çözer.
Map<String, dynamic>? _decodeStatePayload(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
          entry.key.toString(): entry.value,
      };
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// `shared_preferences` tabanlı yerel store.
///
/// Açılışta bir kez `await LocalGameStore.open()` edilir ve `ProviderScope`
/// override'ı ile verilir; böylece `GameController.build()` senkron kalır ve
/// uygulama "loading" ekranı göstermek zorunda olmaz.
///
/// v6 güvenlik/veri bütünlüğü:
/// * `save()` artık **gerçek disk yazımını** bekleyen bir Future döner
///   (`Completer`), böylece "yazdım" sanılan ama kaybolan veri olmaz,
/// * bozuk JSON sessizce yok sayılmaz: [corruptedBackupKey] anahtarına taşınır,
///   [lastLoadError] doldurulur ve temiz durumla devam edilir,
/// * kayda `schema_version` yazılır; eski (v5) kayıtlar otomatik okunur,
/// * büyük JSON `compute` (isolate) ile çözülür.
final class LocalGameStore implements GameStore {
  LocalGameStore._(this._preferences);

  static const Duration writeDebounce = Duration(milliseconds: 150);
  static const String corruptedBackupKey = 'cache.game_state.corrupted';
  static const int isolateThresholdBytes = 64 * 1024;

  final SharedPreferences _preferences;

  Timer? _writeTimer;
  GameState? _latest;
  GameState? _prime;
  bool _primed = false;
  String? _loadError;
  Future<void> _writeChain = Future<void>.value();
  final List<Completer<void>> _pendingWrites = <Completer<void>>[];

  /// Son yükleme hatası (ayarlar ekranı / teşhis için).
  String? get lastLoadError => _loadError;

  static Future<LocalGameStore> open() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    final LocalGameStore store = LocalGameStore._(preferences);
    await store._primeState();
    return store;
  }

  Future<void> _primeState() async {
    final String? raw = _preferences.getString(AppConstants.cacheGameState);
    if (raw == null || raw.isEmpty) {
      _primed = true;
      return;
    }
    try {
      final Map<String, dynamic>? decoded = raw.length >= isolateThresholdBytes
          ? await compute(_decodeStatePayload, raw)
          : _decodeStatePayload(raw);
      if (decoded == null) {
        await _quarantine(raw, 'JSON çözümlenemedi');
        _primed = true;
        return;
      }
      _prime = _fromPayload(decoded);
      _primed = true;
    } catch (error) {
      await _quarantine(raw, error.toString());
      _primed = true;
    }
  }

  GameState _fromPayload(Map<String, dynamic> payload) {
    final Object? version = payload['schema_version'];
    final Object? nested = payload['state'];
    final Map<String, dynamic> stateJson = nested is Map
        ? <String, dynamic>{
            for (final MapEntry<dynamic, dynamic> entry in nested.entries)
              entry.key.toString(): entry.value,
          }
        : payload;
    if (version is int && version > gameStateSchemaVersion) {
      // İleri sürümden gelen kayıt: bilinmeyen alanlar yok sayılır, veri
      // kaybını önlemek için yine de okunur.
      _loadError = 'Kayıt v$version sürümünden; v$gameStateSchemaVersion '
          'uyumluluk modunda okundu.';
    }
    return GameState.fromJson(stateJson);
  }

  @override
  GameState? load() {
    if (!_primed) return null;
    return _prime;
  }

  @override
  Future<void> save(GameState state) {
    _latest = state;
    final Completer<void> completer = Completer<void>();
    _pendingWrites.add(completer);
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDebounce, () {
      unawaited(_writeLatest());
    });
    return completer.future;
  }

  /// Uygulama arka plana girerken / kapanırken bekleyen yazımı zorlar.
  @override
  Future<void> flush() {
    _writeTimer?.cancel();
    _writeTimer = null;
    return _writeLatest();
  }

  Future<void> _writeLatest() async {
    final GameState? state = _latest;
    if (state == null) {
      _completePending();
      await _writeChain;
      return;
    }
    final String payload = jsonEncode(<String, dynamic>{
      'schema_version': gameStateSchemaVersion,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'state': state.toJson(),
    });
    _writeChain = _writeChain
        .catchError((Object _) {
          // Önceki yazım hatası sonraki denemeyi engellemesin.
        })
        .then((_) async {
          await _preferences.setString(AppConstants.cacheGameState, payload);
          _prime = state;
          _primed = true;
        });
    try {
      await _writeChain;
    } finally {
      _completePending();
    }
  }

  void _completePending() {
    final List<Completer<void>> pending = <Completer<void>>[..._pendingWrites];
    _pendingWrites.clear();
    for (final Completer<void> completer in pending) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _quarantine(String raw, String reason) async {
    _loadError =
        'Kayıt okunamadı ($reason) · yedek: $corruptedBackupKey';
    try {
      await _preferences.setString(corruptedBackupKey, raw);
      await _preferences.remove(AppConstants.cacheGameState);
    } catch (_) {
      // Yedekleme başarısız olsa da uygulama temiz durumla açılır.
    }
    debugPrint('[GameStore] $_loadError');
  }

  @override
  Future<void> clear() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    _latest = null;
    _prime = null;
    _primed = true;
    _completePending();
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
