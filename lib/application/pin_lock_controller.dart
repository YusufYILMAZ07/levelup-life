import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_settings.dart';

/// Özel alan kilidinin açık/kapalı durumu.
///
/// Ayarlar `pinLockEnabled` anahtarını tutar; bu controller yalnızca **o an
/// kilitli mi** sorusunu yönetir (açılış, uygulamaya geri dönüş, "hemen kilitle").
final class PinLockController extends Notifier<bool> {
  @override
  bool build() => ref.read(appSettingsProvider).pinLockEnabled;

  void lock() => state = true;

  void unlock() => state = false;

  /// Ayar değiştiğinde çağrılır: kilit kapalıysa ekranı serbest bırakır.
  void syncWithSettings() {
    final bool enabled = ref.read(appSettingsProvider).pinLockEnabled;
    if (!enabled) state = false;
  }

  /// Uygulama arka plandan döndüğünde çağrılır.
  void lockIfEnabled() {
    if (ref.read(appSettingsProvider).pinLockEnabled) state = true;
  }

  bool verify(String pin) =>
      AppSettings.matchesPin(pin, ref.read(appSettingsProvider).pinCode);

  /// Doğruysa kilidi açar ve `true` döner.
  bool unlockWithPin(String pin) {
    if (!verify(pin)) return false;
    state = false;
    return true;
  }
}

final NotifierProvider<PinLockController, bool> pinLockProvider =
    NotifierProvider<PinLockController, bool>(PinLockController.new);
