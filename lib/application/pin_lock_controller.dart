import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_settings.dart';
import '../services/biometric_service.dart';
import '../services/pin_security.dart';

/// Özel alan kilidinin açık/kapalı durumu.
///
/// v6 sertleştirmeleri:
/// * `build()` artık **reaktif**: ayarlardaki `pinLockEnabled` değişince kilit
///   durumu kendiliğinden güncellenir,
/// * kamera/galeri/sistem izin pencereleri için **grace period** (varsayılan
///   30 sn) vardır; kısa arka plan geçişleri kilidi tetiklemez,
/// * 5 hatalı denemeden sonra **artan bekleme** (brute-force koruması) uygular,
/// * biyometrik kilit (`local_auth`) desteklenir.
final class PinLockController extends Notifier<bool> {
  int _failures = 0;
  DateTime? _lockedUntil;
  DateTime? _backgroundAt;

  @override
  bool build() {
    final bool enabled = ref.watch(
      appSettingsProvider.select(
        (AppSettings settings) => settings.pinLockEnabled,
      ),
    );
    // Kilit kapalıysa ekran asla kilitli kalmaz.
    return enabled;
  }

  AppSettings get _settings => ref.read(appSettingsProvider);

  void lock() {
    if (!_settings.pinLockEnabled) return;
    _backgroundAt = null;
    state = true;
  }

  void unlock() {
    _failures = 0;
    _lockedUntil = null;
    _backgroundAt = null;
    state = false;
  }

  /// Ayar değiştiğinde çağrılır (v5 API'si; `build` artık reaktif olduğu için
  /// yalnızca kapanışta ekranı serbest bırakır).
  void syncWithSettings() {
    if (!_settings.pinLockEnabled) {
      _failures = 0;
      _lockedUntil = null;
      _backgroundAt = null;
      state = false;
    }
  }

  // ── Grace period ─────────────────────────────────────────────────────────

  /// Uygulama arka plana geçtiğinde çağrılır (zaman damgası tutulur).
  void onAppPaused({DateTime? at}) {
    if (!_settings.pinLockEnabled) return;
    _backgroundAt ??= at ?? DateTime.now();
  }

  /// Uygulama geri geldiğinde çağrılır.
  ///
  /// Arka planda kalma süresi [AppSettings.lockGraceSeconds] sınırını aştıysa
  /// kilit devreye girer; aksi hâlde (kamera/galeri hızlı dönüş) ekran açık
  /// kalır.
  void onAppResumed({DateTime? at}) {
    if (!_settings.pinLockEnabled) return;
    final DateTime? pausedAt = _backgroundAt;
    _backgroundAt = null;
    if (pausedAt == null) return;
    final Duration elapsed = (at ?? DateTime.now()).difference(pausedAt);
    final Duration grace = Duration(
      seconds: _settings.lockGraceSeconds.clamp(
        AppSettings.minLockGraceSeconds,
        AppSettings.maxLockGraceSeconds,
      ),
    );
    if (elapsed >= grace) state = true;
  }

  /// v5 uyumluluğu: arka plana geçişte doğrudan çağrılırsa grace'i uygular.
  void lockIfEnabled({DateTime? at}) => onAppPaused(at: at);

  // ── Doğrulama ────────────────────────────────────────────────────────────

  /// Şu an brute-force bekleme süresi var mı?
  bool get isLockedOut {
    final DateTime? until = _lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// Bekleme bitene kadar kalan süre.
  Duration get lockoutRemaining {
    final DateTime? until = _lockedUntil;
    if (until == null) return Duration.zero;
    final Duration remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get failedAttempts => _failures;

  /// PIN'i doğrular (hash varsa hash, yoksa varsayılan 3101).
  bool verify(String pin) => _settings.verifyPin(pin);

  bool unlockWithPin(String pin) {
    if (isLockedOut) return false;
    if (!verify(pin)) {
      _registerFailure();
      return false;
    }
    unlock();
    return true;
  }

  /// Biyometrik doğrulama ile kilidi açar.
  Future<BiometricResult> unlockWithBiometrics() async {
    if (!_settings.pinLockEnabled || !_settings.biometricEnabled) {
      return const BiometricResult(
        BiometricStatus.unavailable,
        message: 'Biyometrik kilit ayarlardan açılmamış.',
      );
    }
    final BiometricResult result = await ref
        .read(biometricServiceProvider)
        .authenticate();
    if (result.isSuccess) unlock();
    return result;
  }

  void _registerFailure() {
    _failures++;
    final Duration lockout = PinAttemptPolicy.lockoutFor(_failures);
    if (lockout > Duration.zero) {
      _lockedUntil = DateTime.now().add(lockout);
    }
  }
}

final NotifierProvider<PinLockController, bool> pinLockProvider =
    NotifierProvider<PinLockController, bool>(PinLockController.new);
