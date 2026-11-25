import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Biyometrik kimlik doğrulama sonucu.
enum BiometricStatus {
  success,
  failed,
  unavailable,
  notEnrolled,
  lockedOut,
  error,
}

final class BiometricResult {
  const BiometricResult(this.status, {this.message});

  final BiometricStatus status;
  final String? message;

  bool get isSuccess => status == BiometricStatus.success;

  /// Kullanıcıya tekrar denemesini söylemek anlamsız (donanım/kayıt yok).
  bool get isPermanent => status == BiometricStatus.unavailable;
}

/// Face ID / Touch ID / Android parmak izi köprüsü.
///
/// v6.1 sertleştirmeleri:
/// * önce `canCheckBiometrics` **ve** kayıtlı biyometri listesi kontrol edilir;
///   kayıt yoksa kullanıcıya net "telefon ayarlarından ekle" mesajı verilir,
/// * `PlatformException` kodları tek tek eşlenir (`lockedOut`,
///   `permanentlyLockedOut`, `passcodeNotSet`, `notEnrolled`, …),
/// * aynı anda iki sistem istemi açılmaz (`_inFlight`),
/// * hiçbir zaman exception fırlatmaz.
final class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  bool _inFlight = false;

  /// Sistem istemi açık mı? (kilit ekranı butonunu kilitlemek için)
  bool get isPrompting => _inFlight;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Cihazda **kayıtlı** biyometri var mı?
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isNotEmpty) return true;
      // Bazı Android üreticileri `getAvailableBiometrics` boş döner ama
      // donanım desteklidir; yine de kayıt olmadan istem açamayız.
      return await _auth.isDeviceSupported() && canCheck && enrolled.isNotEmpty;
    } on PlatformException catch (error) {
      debugPrint('[Biometric] isAvailable ${error.code}: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('[Biometric] isAvailable: $error');
      return false;
    }
  }

  /// Kullanıcıdan biyometrik doğrulama ister.
  Future<BiometricResult> authenticate({
    String reason = 'LevelUp Life · özel alanı aç',
  }) async {
    if (!isSupported) {
      return const BiometricResult(
        BiometricStatus.unavailable,
        message: 'Bu cihazda biyometrik kilit desteklenmiyor.',
      );
    }
    if (_inFlight) {
      return const BiometricResult(
        BiometricStatus.failed,
        message: 'Biyometrik doğrulama zaten açık.',
      );
    }
    _inFlight = true;
    try {
      if (!await isAvailable()) {
        return const BiometricResult(
          BiometricStatus.notEnrolled,
          message:
              'Kayıtlı Face ID / parmak izi yok · telefon ayarlarından ekle.',
        );
      }
      final bool ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok
          ? const BiometricResult(BiometricStatus.success)
          : const BiometricResult(
              BiometricStatus.failed,
              message: 'Biyometrik doğrulama tamamlanmadı.',
            );
    } on PlatformException catch (error) {
      return _mapPlatformError(error);
    } catch (error) {
      debugPrint('[Biometric] authenticate: $error');
      return const BiometricResult(
        BiometricStatus.error,
        message: 'Biyometrik doğrulama hatası · tekrar dene.',
      );
    } finally {
      _inFlight = false;
    }
  }

  /// `local_auth` hata kodlarını Türkçe, eyleme dönük mesajlara çevirir.
  static BiometricResult _mapPlatformError(PlatformException error) {
    final String code = error.code.toLowerCase();
    if (code.contains('permanentlylockedout') ||
        code.contains('permanently_locked_out') ||
        code.contains('biometriconlynotsupported')) {
      return const BiometricResult(
        BiometricStatus.lockedOut,
        message: 'Biyometri kalıcı olarak kilitlendi · PIN ile aç.',
      );
    }
    if (code.contains('lockedout') || code.contains('lock_out')) {
      return const BiometricResult(
        BiometricStatus.lockedOut,
        message: 'Çok fazla deneme · biraz sonra ya da PIN ile dene.',
      );
    }
    if (code.contains('notenrolled') || code.contains('not_enrolled')) {
      return const BiometricResult(
        BiometricStatus.notEnrolled,
        message: 'Önce telefon ayarlarından Face ID / parmak izi ekle.',
      );
    }
    if (code.contains('passcodenotset') || code.contains('passcode_not_set')) {
      return const BiometricResult(
        BiometricStatus.notEnrolled,
        message: 'Önce telefona bir ekran kilidi kodu belirle.',
      );
    }
    if (code.contains('notavailable') ||
        code.contains('not_available') ||
        code.contains('notsupported') ||
        code.contains('devicenotsupported')) {
      return const BiometricResult(
        BiometricStatus.unavailable,
        message: 'Biyometrik donanım bulunamadı.',
      );
    }
    debugPrint('[Biometric] ${error.code}: ${error.message}');
    return const BiometricResult(
      BiometricStatus.error,
      message: 'Biyometrik doğrulama hatası · tekrar dene.',
    );
  }
}

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((Ref ref) => BiometricService());
