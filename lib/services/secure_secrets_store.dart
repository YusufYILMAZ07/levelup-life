import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hassas anahtarların (PIN hash/tuz, oturum token'ları) güvenli deposu.
abstract interface class SecureSecretsStore {
  String? read(String key);

  Future<void> write(String key, String? value);

  Future<void> delete(String key);
}

/// Testler ve güvenli depo bulunmayan platformlar için bellek içi store.
final class MemorySecureSecretsStore implements SecureSecretsStore {
  MemorySecureSecretsStore([Map<String, String>? seed])
    : _values = <String, String>{...?seed};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    final String? clean = value?.trim();
    if (clean == null || clean.isEmpty) {
      _values.remove(key);
    } else {
      _values[key] = clean;
    }
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// `flutter_secure_storage` (iOS Keychain / Android Keystore) tabanlı store.
///
/// Açılışta bilinen anahtarlar belleğe alınır; böylece `AppSettingsStore.load`
/// senkron kalabilir. Platform desteklemiyorsa (Web'de kripto yoksa) sessizce
/// bellek içi moda düşer — uygulama asla çökmez.
final class LocalSecureSecretsStore implements SecureSecretsStore {
  LocalSecureSecretsStore._(this._storage, this._cache);

  static const List<String> knownKeys = <String>['pin_hash', 'pin_salt'];

  static const FlutterSecureStorage _options = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final FlutterSecureStorage _storage;
  final Map<String, String> _cache;

  static Future<SecureSecretsStore> open() async {
    try {
      final Map<String, String> cache = <String, String>{};
      for (final String key in knownKeys) {
        final String? value = await _options.read(key: key);
        if (value != null && value.isNotEmpty) cache[key] = value;
      }
      return LocalSecureSecretsStore._(_options, cache);
    } catch (_) {
      return MemorySecureSecretsStore();
    }
  }

  @override
  String? read(String key) => _cache[key];

  @override
  Future<void> write(String key, String? value) async {
    final String? clean = value?.trim();
    try {
      if (clean == null || clean.isEmpty) {
        await _storage.delete(key: key);
        _cache.remove(key);
      } else {
        await _storage.write(key: key, value: clean);
        _cache[key] = clean;
      }
    } catch (_) {
      // Güvenli depo yazamazsa yalnızca oturum içi değer korunur.
      if (clean == null || clean.isEmpty) {
        _cache.remove(key);
      } else {
        _cache[key] = clean;
      }
    }
  }

  @override
  Future<void> delete(String key) => write(key, null);
}
