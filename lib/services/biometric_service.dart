import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Biyometrik kimlik doğrulama sonucu.
enum BiometricStatus { success, failed, unavailable, notEnrolled, error }

final class BiometricResult {
  const BiometricResult(this.status, {this.message});

  final BiometricStatus status;
  final String? message;

  bool get isSuccess => status == BiometricStatus.success;
}

/// Face ID / Touch ID / Android parmak izi köprüsü.
///
/// * Desteklenmeyen platformda (Web/masaüstü) [BiometricStatus.unavailable]
/// * Kullanıcı iptalinde [BiometricStatus.failed]
/// * Donanım/izin hatasında [BiometricStatus.error] döner; asla exception
///   fırlatmaz.
final class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Cihazda kullanılabilir biyometri var mı?
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
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
    try {
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
    } on Exception catch (error) {
      final String text = error.toString().toLowerCase();
      if (text.contains('not available') || text.contains('no biometric')) {
        return const BiometricResult(
          BiometricStatus.unavailable,
          message: 'Biyometrik donanım bulunamadı.',
        );
      }
      if (text.contains('not enrolled') || text.contains('no enrolled')) {
        return const BiometricResult(
          BiometricStatus.notEnrolled,
          message: 'Önce telefon ayarlarından Face ID / parmak izi ekle.',
        );
      }
      return BiometricResult(
        BiometricStatus.error,
        message: 'Biyometrik doğrulama hatası · tekrar dene.',
      );
    }
  }
}

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((Ref ref) => BiometricService());
