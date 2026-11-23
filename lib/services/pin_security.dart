import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Tuzlanmış PIN kimliği.
///
/// PIN hiçbir zaman düz metin olarak saklanmaz: rastgele 16 baytlık tuz +
/// SHA-256 özeti tutulur. Karşılaştırma sabit zamanlıdır (zamanlama sızıntısına
/// karşı).
final class PinCredential {
  const PinCredential({required this.hash, required this.salt});

  /// 64 karakterlik hex SHA-256 özeti.
  final String hash;

  /// 32 karakterlik hex tuz.
  final String salt;

  static const int saltBytes = 16;

  /// Yeni kimlik üretir. [salt] verilirse (migrasyon/test) yeniden kullanılır.
  factory PinCredential.create(String pin, {String? salt}) {
    final String cleanSalt = (salt == null || salt.trim().isEmpty)
        ? _randomSalt()
        : salt.trim();
    return PinCredential(hash: hashPin(pin, cleanSalt), salt: cleanSalt);
  }

  /// Girilen PIN bu kimlikle eşleşiyor mu?
  bool matches(String entered) {
    if (hash.trim().isEmpty || salt.trim().isEmpty) return false;
    final String pin = normalize(entered);
    if (pin.length != 4) return false;
    return _constantTimeEquals(hashPin(pin, salt), hash.trim());
  }

  static String hashPin(String pin, String salt) => sha256
      .convert(utf8.encode('$salt:${normalize(pin)}'))
      .toString();

  static String normalize(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 4 ? digits.substring(0, 4) : digits;
  }

  static String _randomSalt() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < saltBytes; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

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
    return Duration(
      seconds: min(seconds, maxLockout.inSeconds),
    );
  }
}
