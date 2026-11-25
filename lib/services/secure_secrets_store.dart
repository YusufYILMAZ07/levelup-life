import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Güvenli depo yazımı başarısız olduğunda fırlatılır.
///
/// v6.1: hata **sessizce yutulmaz**; PIN hash'i yazılamadıysa kullanıcı bunu
/// bilir (aksi hâlde "PIN değişti" sanıp hiçbir zaman kilit açılamazdı).
final class SecureSecretsException implements Exception {
  const SecureSecretsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hassas anahtarların (PIN hash/tuz, oturum token'ları) güvenli deposu.
abstract interface class SecureSecretsStore {
  /// Platform deposu (iOS Keychain / Android Keystore) kullanılabilir mi?
  ///
  /// `false` iken okuma boş, yazma ise [SecureSecretsException] döner. Böylece
  /// bozuk bir Keystore, PIN'in varsayılana sessizce dönmesine yol açmaz.
  bool get isOperational;

  String? read(String key);

  Future<void> write(String key, String? value);

  Future<void> delete(String key);
}

/// Testler ve güvenli depo bulunmayan platformlar için bellek içi store.
final class MemorySecureSecretsStore implements SecureSecretsStore {
  MemorySecureSecretsStore([Map<String, String>? seed])
    : _values = <String, String>{...?seed};

  final Map<String, String> _values;

  /// Testlerde Keystore hatasını taklit etmek için `false` yapılabilir.
  bool available = true;

  @override
  bool get isOperational => available;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (!available) {
      throw const SecureSecretsException(
        'Güvenli depo kullanılamıyor · değer kaydedilemedi.',
      );
    }
    final String? clean = value?.trim();
    if (clean == null || clean.isEmpty) {
      _values.remove(key);
    } else {
      _values[key] = clean;
    }
  }

  @override
  Future<void> delete(String key) => write(key, null);
}

/// `flutter_secure_storage` (iOS Keychain / Android Keystore) tabanlı store.
///
/// * Açılışta **tüm** anahtarlar belleğe alınır (`readAll`); böylece
///   `AppSettingsStore.load` senkron kalır ve yeni anahtarlar (pin_algorithm,
///   pin_iterations) da okunur.
/// * Yazmalar **seri kuyrukta** çalışır: hızlı art arda gelen ayar
///   güncellemeleri platform kanalında yarışmaz.
/// * Yazma hatası yutulmaz: çağırana iletilir ve store `isOperational=false`
///   olarak işaretlenir.
final class LocalSecureSecretsStore implements SecureSecretsStore {
  LocalSecureSecretsStore._(this._storage, this._cache, this._operational);

  static const FlutterSecureStorage _options = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final FlutterSecureStorage _storage;
  final Map<String, String> _cache;
  bool _operational;
  Future<void> _writeChain = Future<void>.value();

  /// Erişilemeyen anahtarlar burada tutulur (teşhis / ayarlar ekranı).
  String? lastError;

  @override
  bool get isOperational => _operational;

  /// Keychain / Keystore'u açar ve tüm değerleri cache'e alır.
  ///
  /// Başarısızlıkta **bellek moduna düşüp boş cache döndürmüyoruz**; store
  /// "operational değil" olarak işaretlenir ve `AppSettingsStore` PIN kilidini
  /// güvenli biçimde devre dışı bırakıp kullanıcıya bildirir.
  static Future<LocalSecureSecretsStore> open() async {
    try {
      final Map<String, String> all = await _options.readAll();
      final Map<String, String> cache = <String, String>{
        for (final MapEntry<String, String> entry in all.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };
      return LocalSecureSecretsStore._(_options, cache, true);
    } catch (error) {
      debugPrint('[SecureSecrets] Güvenli depo açılamadı: $error');
      final LocalSecureSecretsStore store = LocalSecureSecretsStore._(
        _options,
        <String, String>{},
        false,
      );
      store.lastError = 'Güvenli depo (Keychain/Keystore) açılamadı: $error';
      return store;
    }
  }

  @override
  String? read(String key) => _cache[key];

  @override
  Future<void> write(String key, String? value) {
    if (!_operational) {
      return Future<void>.error(
        const SecureSecretsException(
          'Güvenli depo açılamadı · değer kaydedilemedi. Cihaz kilidini '
          'açıp tekrar dene.',
        ),
      );
    }
    final String? clean = value?.trim();
    // Seri kuyruk: önceki yazma bitmeden yenisi başlamaz.
    final Future<void> next = _writeChain.then((_) async {
      try {
        if (clean == null || clean.isEmpty) {
          await _storage.delete(key: key);
          _cache.remove(key);
        } else {
          await _storage.write(key: key, value: clean);
          _cache[key] = clean;
        }
      } catch (error) {
        _operational = false;
        lastError = 'Güvenli depo yazımı başarısız: $error';
        throw SecureSecretsException(lastError!);
      }
    });
    // Kuyruk kırılmasın: hata çağırana gider, zincir devam eder.
    _writeChain = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> delete(String key) => write(key, null);

  /// Cihaz kilidi açıldıktan sonra yeniden bağlanmayı dener.
  Future<bool> reconnect() async {
    if (_operational) return true;
    try {
      final Map<String, String> all = await _options.readAll();
      _cache
        ..clear()
        ..addAll(<String, String>{
          for (final MapEntry<String, String> entry in all.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value,
        });
      _operational = true;
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'Güvenli depo hâlâ açılamıyor: $error';
      return false;
    }
  }
}
