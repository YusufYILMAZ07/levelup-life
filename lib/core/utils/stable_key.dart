/// Süreçler arasında **değişmeyen** karma (hash) yardımcıları.
///
/// Dart'ın `String.hashCode` değeri aynı süreç içinde kararlıdır ancak
/// süreç/derleme değişince garanti edilmez. Bildirim kimlikleri, tombstone
/// anahtarları ve senkron parmak izleri uygulama yeniden açıldığında da aynı
/// olmak zorunda olduğu için burada FNV-1a tabanlı sabit bir karma kullanılır.
abstract final class StableKey {
  static const int _fnvOffset32 = 0x811C9DC5;
  static const int _fnvOffset32B = 0x9E3779B9;
  static const int _fnvPrime32 = 0x01000193;
  static const int _mask32 = 0xFFFFFFFF;
  static const int _mask16 = 0xFFFF;

  /// 32 bit işaretsiz FNV-1a (0 .. 4 294 967 295).
  ///
  /// Çarpma 16 bit parçalara bölünür: Dart'ın Web derlemesinde `int` 53 bit
  /// IEEE-754 double'dır; doğrudan `hash * prime` 2^53'ü aşıp hassasiyet
  /// kaybeder. Bu sürüm `dart2js`/`wasm` dahil tüm platformlarda aynı sonucu
  /// verir.
  static int hash32(String input, {int seed = _fnvOffset32}) {
    int hash = seed & _mask32;
    for (final int unit in input.codeUnits) {
      hash = _fnvStep(hash ^ (unit & 0xFF));
      hash = _fnvStep(hash ^ ((unit >> 8) & 0xFF));
    }
    return hash & _mask32;
  }

  static int _fnvStep(int hash) {
    final int low = hash & _mask16;
    final int high = (hash >> 16) & _mask16;
    final int productLow = low * _fnvPrime32;
    final int productHigh = high * _fnvPrime32;
    return (productLow + ((productHigh & _mask16) << 16)) & _mask32;
  }

  /// İki bağımsız 32 bit özetten 16 karakterlik hex anahtar.
  static String hash64Hex(String input) {
    final String a = hash32(input).toRadixString(16).padLeft(8, '0');
    final String b = hash32(
      input,
      seed: _fnvOffset32B,
    ).toRadixString(16).padLeft(8, '0');
    return '$a$b';
  }

  /// [namespace] içinde deterministik bildirim kimliği üretir.
  ///
  /// Kimlik her zaman `[start, end)` aralığında kalır; böylece bir bildirim
  /// ailesi (plan hatırlatıcıları, mesajlar…) tek aralıkta iptal edilebilir.
  static int namespacedId({
    required String key,
    required int start,
    required int size,
  }) {
    if (size <= 0) return start;
    return start + (hash32(key) % size);
  }

  /// Metni tombstone anahtarına çevirir (boşluklar tekilleştirilir).
  static String tombstoneKey(String text) =>
      hash64Hex(text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase());
}
