import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/pin_lock_controller.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/biometric_service.dart';

void main() {
  AppSettings lockedSettings({int grace = 30, bool biometric = false}) =>
      const AppSettings(
        pinLockEnabled: true,
        lockGraceSeconds: 30,
        biometricEnabled: false,
      ).copyWith(lockGraceSeconds: grace, biometricEnabled: biometric)
          .withPin('2580');

  ProviderContainer containerWith(AppSettings settings) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          MemoryAppSettingsStore(settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('kilit açıkken başlangıçta kilitlidir ve doğru PIN açar', () {
    final ProviderContainer container = containerWith(lockedSettings());
    expect(container.read(pinLockProvider), isTrue);

    final PinLockController controller = container.read(
      pinLockProvider.notifier,
    );
    expect(controller.unlockWithPin('0000'), isFalse);
    expect(container.read(pinLockProvider), isTrue);
    expect(controller.unlockWithPin('2580'), isTrue);
    expect(container.read(pinLockProvider), isFalse);
  });

  test('5 hatalı denemeden sonra brute-force beklemesi uygulanır', () {
    final ProviderContainer container = containerWith(lockedSettings());
    final PinLockController controller = container.read(
      pinLockProvider.notifier,
    );

    for (int i = 0; i < 5; i++) {
      expect(controller.unlockWithPin('1111'), isFalse);
    }

    expect(controller.isLockedOut, isTrue);
    // Bekleme sırasında doğru PIN bile kabul edilmez.
    expect(controller.unlockWithPin('2580'), isFalse);
    expect(container.read(pinLockProvider), isTrue);
    expect(controller.lockoutRemaining, greaterThan(Duration.zero));
  });

  test('grace period içindeki dönüş kilitlemez, sonrasında kilitler', () {
    final ProviderContainer container = containerWith(lockedSettings());
    final PinLockController controller = container.read(
      pinLockProvider.notifier,
    );
    controller.unlock();
    expect(container.read(pinLockProvider), isFalse);

    final DateTime start = DateTime(2026, 11, 23, 20);
    controller.onAppPaused(at: start);
    controller.onAppResumed(at: start.add(const Duration(seconds: 10)));
    expect(container.read(pinLockProvider), isFalse);

    controller.onAppPaused(at: start.add(const Duration(minutes: 1)));
    controller.onAppResumed(at: start.add(const Duration(minutes: 1, seconds: 31)));
    expect(container.read(pinLockProvider), isTrue);
  });

  test('grace 0 iken ilk arka plan dönüşü hemen kilitler', () {
    final ProviderContainer container = containerWith(lockedSettings(grace: 0));
    final PinLockController controller = container.read(
      pinLockProvider.notifier,
    );
    controller.unlock();
    final DateTime start = DateTime(2026, 11, 23, 20);
    controller.onAppPaused(at: start);
    controller.onAppResumed(at: start);
    expect(container.read(pinLockProvider), isTrue);
  });

  test('ayar kapatılınca kilit reaktif olarak açılır', () async {
    final ProviderContainer container = containerWith(lockedSettings());
    expect(container.read(pinLockProvider), isTrue);

    container
        .read(appSettingsProvider.notifier)
        .setPinLockEnabled(false);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(pinLockProvider), isFalse);
  });

  test('biyometrik kilit kapalıyken doğrulama istenmez', () async {
    final ProviderContainer container = containerWith(lockedSettings());
    final BiometricResult result = await container
        .read(pinLockProvider.notifier)
        .unlockWithBiometrics();
    expect(result.status, BiometricStatus.unavailable);
    expect(container.read(pinLockProvider), isTrue);
  });
}
