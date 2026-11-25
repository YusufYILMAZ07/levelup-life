import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// PIN özetinde kullanılan algoritma.
///
/// * [sha256Legacy] — v6 ve öncesi kayıtlar (tek tur SHA-256). Yalnızca
///   **geriye dönük doğrulama + migrasyon** için tutulur.
/// * [pbkdf2Sha256] — v6.1 üretim standardı (PBKDF2-HMAC-SHA256, 100.000 tur).
enum PinAlgorithm {
  sha256Legacy('sha256'),
  pbkdf2Sha256('pbkdf2-sha256');

  const PinAlgorithm(this.id);

  /// JSON / güvenli depo anahtarında saklanan kimlik.
  final String id;

  static PinAlgorithm fromId(String? raw) {
    final String value = raw?.trim().toLowerCase() ?? '';
    return value == pbkdf2Sha256.id ? pbkdf2Sha256 : sha256Legacy;
  }
}

/// PIN türetme yardımcıları.
///
/// v6.1 sertleştirmeleri:
/// * giriş **katı** doğrulanır: tam 4 rakam değilse reddedilir (eski sürüm
///   `310199` gibi girişleri kırpıp kabul ediyordu),
/// * yeni PIN'ler PBKDF2-HMAC-SHA256 (100.000 tur) ile türetilir,
/// * ağır türetme `compute()` ile arka isolate'e taşınabilir
///   ([hashAsync]) — kilit ekranı donmaz,
/// * eski SHA-256 kayıtları başarılı girişten sonra sessizce yükseltilir.
abstract final class PinSecurity {
  /// Üretim varsayılanı.
  static const int defaultIterations = 100000;

  /// Alt/üst sınırlar — bozuk bir kayıt CPU'yu kilitlemesin.
  static const int minIterations = 1000;
  static const int maxIterations = 400000;

  static const int saltBytes = 16;

  /// Yalnızca testlerde düşürülür (100k tur testleri yavaşlatır).
  @visibleForTesting
  static int? iterationsOverride;

  /// Etkin tur sayısı.
  static int get iterations => (iterationsOverride ?? defaultIterations).clamp(
    minIterations,
    maxIterations,
  );

  static final RegExp _fourDigits = RegExp(r'^[0-9]{4}$');
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// **Katı** normalizasyon: yalnızca tam 4 rakam kabul edilir.
  ///
  /// Geçersiz girişte boş metin döner; böylece `310199` ya da `31a01`
  /// sessizce `3101`e kırpılıp yanlışlıkla kabul edilmez.
  static String normalize(String raw) {
    final String trimmed = raw.trim();
    return _fourDigits.hasMatch(trimmed) ? trimmed : '';
  }

  static bool isValidPin(String raw) => normalize(raw).isNotEmpty;

  /// v6 uyumluluğu: eski kayıtlı hash'i doğrulamak için **kırpan** normalizasyon.
  static String legacyNormalize(String raw) {
    final String digits = raw.replaceAll(_nonDigits, '');
    return digits.length > 4 ? digits.substring(0, 4) : digits;
  }

  /// 16 baytlık kriptografik rastgele tuz (32 hex karakter).
  static String randomSalt() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < saltBytes; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// v6 SHA-256 özeti (yalnızca eski kayıtları doğrulamak için).
  static String hashLegacy(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:${legacyNormalize(pin)}')).toString();

  /// PBKDF2-HMAC-SHA256 (tek blok = 32 bayt → 64 hex karakter).
  ///
  /// v6.2: **katı** normalizasyon kullanılır. Geçersiz PIN (tam 4 rakam
  /// değilse) sessizce kırpılıp `310199 → 3101` gibi bir çakışma üretmek
  /// yerine [ArgumentError] fırlatır.
  static String hashPbkdf2(String pin, String salt, {int? iterations}) {
    final int rounds = (iterations ?? PinSecurity.iterations).clamp(
      minIterations,
      maxIterations,
    );
    final String clean = normalize(pin);
    if (clean.isEmpty) {
      throw ArgumentError.value(pin, 'pin', 'PIN tam 4 rakam olmalı');
    }
    final Hmac hmac = Hmac(sha256, utf8.encode(clean));
    final List<int> block = <int>[...utf8.encode(salt), 0, 0, 0, 1];
    List<int> u = hmac.convert(block).bytes;
    final List<int> derived = List<int>.of(u);
    for (int i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < derived.length; j++) {
        derived[j] ^= u[j];
      }
    }
    return derived
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Algoritmaya göre senkron türetme.
  static String hash(
    String pin,
    String salt,
    PinAlgorithm algorithm, {
    int? iterations,
  }) => algorithm == PinAlgorithm.pbkdf2Sha256
      ? hashPbkdf2(pin, salt, iterations: iterations)
      : hashLegacy(pin, salt);

  /// Ağır PBKDF2 türetmesini `compute()` ile ana isolate'ten çıkarır.
  static Future<String> hashAsync(
    String pin,
    String salt,
    PinAlgorithm algorithm, {
    int? iterations,
  }) async {
    if (algorithm == PinAlgorithm.sha256Legacy) return hashLegacy(pin, salt);
    return compute(_pbkdf2Task, <String, Object?>{
      'pin': pin,
      'salt': salt,
      'iterations': iterations ?? PinSecurity.iterations,
    });
  }
}

/// `compute` için üst düzey giriş noktası (izolatlar arası taşınabilir argüman).
String _pbkdf2Task(Map<String, Object?> task) => PinSecurity.hashPbkdf2(
  task['pin']! as String,
  task['salt']! as String,
  iterations: task['iterations']! as int,
);

/// Tuzlanmış PIN kimliği.
///
/// PIN hiçbir zaman düz metin olarak saklanmaz: rastgele 16 baytlık tuz +
/// PBKDF2 (ya da eski kayıtlarda SHA-256) özeti tutulur. Karşılaştırma sabit
/// zamanlıdır (zamanlama sızıntısına karşı).
final class PinCredential {
  const PinCredential({
    required this.hash,
    required this.salt,
    this.algorithm = PinAlgorithm.pbkdf2Sha256,
    this.iterations = PinSecurity.defaultIterations,
  });

  /// 64 karakterlik hex özet.
  final String hash;

  /// 32 karakterlik hex tuz.
  final String salt;

  final PinAlgorithm algorithm;

  /// PBKDF2 tur sayısı (SHA-256 kayıtlarında 0).
  final int iterations;

  static const int saltBytes = PinSecurity.saltBytes;

  /// Yeni kimlik üretir. [salt] verilirse (migrasyon/test) yeniden kullanılır.
  ///
  /// Geçersiz (tam 4 rakam olmayan) PIN'de [ArgumentError] fırlatır.
  factory PinCredential.create(
    String pin, {
    String? salt,
    int? iterations,
    PinAlgorithm algorithm = PinAlgorithm.pbkdf2Sha256,
  }) {
    final String clean = PinSecurity.normalize(pin);
    if (clean.isEmpty) {
      throw ArgumentError.value(pin, 'pin', 'PIN tam 4 rakam olmalı');
    }
    final String useSalt = (salt == null || salt.trim().isEmpty)
        ? PinSecurity.randomSalt()
        : salt.trim();
    final int rounds = _roundsFor(algorithm, iterations);
    return PinCredential(
      hash: PinSecurity.hash(clean, useSalt, algorithm, iterations: rounds),
      salt: useSalt,
      algorithm: algorithm,
      iterations: rounds,
    );
  }

  /// [create]'in ana isolate'i bloklamayan sürümü (üretimde tercih edilir).
  static Future<PinCredential> createAsync(
    String pin, {
    String? salt,
    int? iterations,
    PinAlgorithm algorithm = PinAlgorithm.pbkdf2Sha256,
  }) async {
    final String clean = PinSecurity.normalize(pin);
    if (clean.isEmpty) {
      throw ArgumentError.value(pin, 'pin', 'PIN tam 4 rakam olmalı');
    }
    final String useSalt = (salt == null || salt.trim().isEmpty)
        ? PinSecurity.randomSalt()
        : salt.trim();
    final int rounds = _roundsFor(algorithm, iterations);
    final String derived = await PinSecurity.hashAsync(
      clean,
      useSalt,
      algorithm,
      iterations: rounds,
    );
    return PinCredential(
      hash: derived,
      salt: useSalt,
      algorithm: algorithm,
      iterations: rounds,
    );
  }

  /// Girilen PIN bu kimlikle eşleşiyor mu? Geçersiz giriş her zaman `false`.
  bool matches(String entered) {
    if (hash.trim().isEmpty || salt.trim().isEmpty) return false;
    final String pin = PinSecurity.normalize(entered);
    if (pin.isEmpty) return false;
    final String computed = PinSecurity.hash(
      pin,
      salt,
      algorithm,
      iterations: _effectiveIterations,
    );
    return _constantTimeEquals(computed, hash.trim().toLowerCase());
  }

  /// [matches]'in ana isolate'i bloklamayan sürümü.
  Future<bool> matchesAsync(String entered) async {
    if (hash.trim().isEmpty || salt.trim().isEmpty) return false;
    final String pin = PinSecurity.normalize(entered);
    if (pin.isEmpty) return false;
    final String computed = await PinSecurity.hashAsync(
      pin,
      salt,
      algorithm,
      iterations: _effectiveIterations,
    );
    return _constantTimeEquals(computed, hash.trim().toLowerCase());
  }

  int get _effectiveIterations => iterations > 0
      ? iterations.clamp(PinSecurity.minIterations, PinSecurity.maxIterations)
      : PinSecurity.defaultIterations;

  static int _roundsFor(PinAlgorithm algorithm, int? iterations) =>
      algorithm == PinAlgorithm.pbkdf2Sha256
      ? (iterations ?? PinSecurity.iterations).clamp(
          PinSecurity.minIterations,
          PinSecurity.maxIterations,
        )
      : 0;

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// PIN deneme sınırı ve artan bekleme süresi.
///
/// * İlk [freeAttempts] hata → kısa [mistakeDelay] (kullanıcıya düzeltme şansı)
/// * Sonrasında her hata bekleme süresini ikiye katlar, [maxLockout]'ta durur.
abstract final class PinAttemptPolicy {
  static const int freeAttempts = 5;
  static const Duration mistakeDelay = Duration(milliseconds: 350);
  static const Duration baseLockout = Duration(seconds: 30);
  static const Duration maxLockout = Duration(minutes: 15);

  /// [failures] hatalı denemeden sonra kilitli kalınacak süre.
  static Duration lockoutFor(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final int step = failures - freeAttempts;
    final int factor = 1 << step.clamp(0, 5);
    final int seconds = baseLockout.inSeconds * factor;
    return Duration(seconds: min(seconds, maxLockout.inSeconds));
  }

  /// Bekleme sonrası kalan deneme hakkı (0 = kilitli).
  static int remainingAttempts(int failures) =>
      (freeAttempts - failures).clamp(0, freeAttempts);
}
