import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_settings.dart';
import '../services/biometric_service.dart';
import '../services/pin_security.dart';

/// Özel alan kilidinin açık/kapalı durumu.
///
/// v6.1 sertleştirmeleri:
/// * `build()` reaktif: ayarlardaki `pinLockEnabled` değişince kilit durumu
///   güncellenir, **ancak** kullanıcı bu oturumda açtıysa ayar değişiklikleri
///   ekranı yeniden kilitlemez,
/// * kamera/galeri izin pencereleri için grace period (varsayılan 30 sn),
/// * hatalı deneme sayacı ve bekleme zamanı **kalıcıdır** (uygulama kapanıp
///   açılsa da sıfırlanmaz),
/// * biyometrik istem de bekleme sırasında kilitlidir,
/// * v6 SHA-256 PIN kayıtları başarılı girişte PBKDF2'ye yükseltilir.
final class PinLockController extends Notifier<bool> {
  int _failures = 0;
  DateTime? _lockedUntil;
  DateTime? _backgroundAt;
  bool _initialized = false;

  /// Kullanıcı bu oturumda kilidi açtı mı? (ayar değişimi re-lock etmesin)
  bool _unlocked = false;

  @override
  bool build() {
    final AppSettings settings = ref.read(appSettingsProvider);
    if (!_initialized) {
      _initialized = true;
      _failures = settings.pinFailedAttempts;
      _lockedUntil = settings.pinLockedUntil;
    }
    final bool enabled = ref.watch(
      appSettingsProvider.select((AppSettings value) => value.pinLockEnabled),
    );
    if (!enabled) {
      _unlocked = false;
      return false;
    }
    return !_unlocked;
  }

  AppSettings get _settings => ref.read(appSettingsProvider);

  void lock() {
    if (!_settings.pinLockEnabled) return;
    _backgroundAt = null;
    _unlocked = false;
    state = true;
  }

  void unlock() {
    final bool needsPersist = _failures != 0 || _lockedUntil != null;
    _failures = 0;
    _lockedUntil = null;
    _backgroundAt = null;
    _unlocked = true;
    state = false;
    if (needsPersist) {
      ref.read(appSettingsProvider.notifier).clearPinFailures();
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
    if (elapsed >= grace) lock();
  }

  /// v5 uyumluluğu: arka plana geçişte doğrudan çağrılırsa grace'i uygular.
  void lockIfEnabled({DateTime? at}) => onAppPaused(at: at);

  // ── Doğrulama ────────────────────────────────────────────────────────────

  /// Şu an brute-force bekleme süresi var mı?
  bool get isLockedOut {
    final DateTime? until = _lockedUntil;
    if (until == null) return false;
    if (!until.isAfter(DateTime.now())) {
      _lockedUntil = null;
      return false;
    }
    return true;
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
    if (_settings.needsPinMigration) unawaited(_upgradeLegacyPin(pin));
    unlock();
    return true;
  }

  /// Kilit ekranının kullandığı, ana isolate'i bloklamayan sürüm.
  Future<bool> unlockWithPinAsync(String pin) async {
    if (isLockedOut) return false;
    final AppSettings settings = _settings;
    final bool ok = await settings.verifyPinAsync(pin);
    if (!ok) {
      _registerFailure();
      return false;
    }
    final bool upgrade = settings.needsPinMigration;
    unlock();
    // Tek seferlik yükseltme: yazımın tamamlanmasını bekle (sessiz veri kaybı
    // olmasın); UI bu sırada zaten kilidi açmış durumda.
    if (upgrade) await _upgradeLegacyPin(pin);
    return true;
  }

  /// Biyometrik doğrulama ile kilidi açar.
  ///
  /// Brute-force beklemesi sırasında biyometri de kabul edilmez (aksi hâlde PIN
  /// deneme sınırı atlatılabilirdi).
  Future<BiometricResult> unlockWithBiometrics() async {
    if (!_settings.pinLockEnabled || !_settings.biometricEnabled) {
      return const BiometricResult(
        BiometricStatus.unavailable,
        message: 'Biyometrik kilit ayarlardan açılmamış.',
      );
    }
    if (isLockedOut) {
      // `inSeconds` kırpıldığı için son saniyede 0 görünebilir; kullanıcıya
      // "0 sn sonra dene" yazmamak için 1..3600 aralığına sabitle.
      final int seconds = lockoutRemaining.inSeconds.clamp(1, 3600);
      return BiometricResult(
        BiometricStatus.lockedOut,
        message: 'Çok fazla hatalı deneme · $seconds sn sonra dene',
      );
    }
    final BiometricResult result = await ref
        .read(biometricServiceProvider)
        .authenticate();
    if (result.isSuccess) unlock();
    return result;
  }

  Future<void> _upgradeLegacyPin(String pin) async {
    try {
      await ref.read(appSettingsProvider.notifier).migratePinAsync(pin);
    } catch (_) {
      // Migrasyon başarısız olsa da giriş geçerlidir; eski hash çalışmaya
      // devam eder ve bir sonraki girişte yeniden denenir.
    }
  }

  void _registerFailure() {
    _failures++;
    final Duration lockout = PinAttemptPolicy.lockoutFor(_failures);
    _lockedUntil = lockout > Duration.zero ? DateTime.now().add(lockout) : null;
    ref
        .read(appSettingsProvider.notifier)
        .recordPinFailure(attempts: _failures, lockedUntil: _lockedUntil);
  }
}

final NotifierProvider<PinLockController, bool> pinLockProvider =
    NotifierProvider<PinLockController, bool>(PinLockController.new);
