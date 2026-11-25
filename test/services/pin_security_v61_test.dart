import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/pin_lock_controller.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/biometric_service.dart';
import 'package:levelup_life/services/pin_security.dart';
import 'package:levelup_life/services/secure_secrets_store.dart';

/// v6.1 PIN güvenliği: katı 4 hane, PBKDF2, v6 SHA-256 migrasyonu ve kalıcı
/// brute-force sayacı.
void main() {
  setUp(() {
    // 100.000 tur testleri yavaşlatır; tek bir test varsayılanı doğrular.
    PinSecurity.iterationsOverride = 1200;
  });

  tearDown(() => PinSecurity.iterationsOverride = null);

  group('PinSecurity · katı giriş', () {
    test('yalnızca tam 4 rakam kabul edilir', () {
      expect(PinSecurity.normalize('3101'), '3101');
      expect(PinSecurity.normalize(' 3101 '), '3101');
      expect(PinSecurity.normalize('310199'), '');
      expect(PinSecurity.normalize('31a01'), '');
      expect(PinSecurity.normalize('310'), '');
      expect(PinSecurity.normalize(''), '');
      expect(PinSecurity.isValidPin('3101'), isTrue);
      expect(PinSecurity.isValidPin('310199'), isFalse);
    });

    test('geçersiz PIN ile kimlik üretilmez', () {
      expect(
        () => PinCredential.create('310199'),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => PinCredential.create('abcd'), throwsA(isA<ArgumentError>()));
    });

    test('fazla haneli giriş kayıtlı PIN’i açmaz', () {
      final AppSettings settings = const AppSettings().withPin('2580');
      expect(settings.verifyPin('2580'), isTrue);
      // v6 öncesi kırpma davranışı: artık kabul edilmez.
      expect(settings.verifyPin('258099'), isFalse);
      expect(settings.verifyPin('25801'), isFalse);
    });
  });

  group('PinSecurity · PBKDF2', () {
    test('varsayılan 100.000 tur ve PBKDF2 algoritması kullanılır', () {
      expect(PinSecurity.defaultIterations, 100000);
      PinSecurity.iterationsOverride = null;
      final PinCredential credential = PinCredential.create(
        '1234',
        salt: 'aabbccddeeff00112233445566778899',
      );
      expect(credential.algorithm, PinAlgorithm.pbkdf2Sha256);
      expect(credential.iterations, 100000);
      expect(credential.hash, hasLength(64));
      expect(credential.matches('1234'), isTrue);
      expect(credential.matches('4321'), isFalse);
    });

    test('PBKDF2 özeti v6 SHA-256 özetinden farklıdır', () {
      const String salt = 'aabbccddeeff00112233445566778899';
      final PinCredential legacy = PinCredential.create(
        '1234',
        salt: salt,
        algorithm: PinAlgorithm.sha256Legacy,
      );
      final PinCredential modern = PinCredential.create('1234', salt: salt);
      expect(legacy.hash, isNot(modern.hash));
      expect(legacy.algorithm, PinAlgorithm.sha256Legacy);
      expect(legacy.iterations, 0);
    });

    test('aynı tuz + aynı PIN deterministik, farklı tuz farklı özet', () {
      PinCredential create(String salt) =>
          PinCredential.create('9876', salt: salt);
      expect(create('aa11').hash, create('aa11').hash);
      expect(create('aa11').hash, isNot(create('bb22').hash));
    });
  });

  group('PinSecurity · v6 SHA-256 migrasyonu', () {
    test('eski kayıt doğrulanır ve PBKDF2’ye yükseltilir', () async {
      final PinCredential legacy = PinCredential.create(
        '2580',
        salt: 'abcd1234abcd1234abcd1234abcd1234',
        algorithm: PinAlgorithm.sha256Legacy,
      );
      final AppSettings legacySettings = AppSettings(
        pinLockEnabled: true,
        pinHash: legacy.hash,
        pinSalt: legacy.salt,
        pinAlgorithm: PinAlgorithm.sha256Legacy.id,
      );
      expect(legacySettings.verifyPin('2580'), isTrue);
      expect(legacySettings.needsPinMigration, isTrue);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            MemoryAppSettingsStore(legacySettings),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(appSettingsProvider.notifier)
          .migratePinAsync('2580');
      final AppSettings migrated = container.read(appSettingsProvider);
      expect(migrated.pinAlgorithm, PinAlgorithm.pbkdf2Sha256.id);
      // Tuz korunur (başka cihazla karşılaştırılabilirlik).
      expect(migrated.pinSalt, legacy.salt);
      expect(migrated.needsPinMigration, isFalse);
      expect(migrated.verifyPin('2580'), isTrue);
      expect(migrated.verifyPin('258099'), isFalse);
    });

    test('algoritma alanı olmayan v6 kaydı SHA-256 sayılır', () {
      final PinCredential legacy = PinCredential.create(
        '4444',
        salt: '00112233445566778899aabbccddeeff',
        algorithm: PinAlgorithm.sha256Legacy,
      );
      final AppSettings restored = AppSettings.fromJson(<String, dynamic>{
        'pin_lock_enabled': true,
        'pin_hash': legacy.hash,
        'pin_salt': legacy.salt,
      });
      expect(restored.hasPin, isTrue);
      expect(restored.needsPinMigration, isTrue);
      expect(restored.verifyPin('4444'), isTrue);
    });

    test('giriş başarılıysa kilit açılır ve kayıt yükseltilir', () async {
      final PinCredential legacy = PinCredential.create(
        '2580',
        salt: 'ffeeddccbbaa99887766554433221100',
        algorithm: PinAlgorithm.sha256Legacy,
      );
      final AppSettings legacySettings = AppSettings(
        pinLockEnabled: true,
        pinHash: legacy.hash,
        pinSalt: legacy.salt,
        pinAlgorithm: PinAlgorithm.sha256Legacy.id,
      );
      final MemoryAppSettingsStore store = MemoryAppSettingsStore(
        legacySettings,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final PinLockController controller = container.read(
        pinLockProvider.notifier,
      );
      expect(await controller.unlockWithPinAsync('2580'), isTrue);
      expect(container.read(pinLockProvider), isFalse);
      await container.read(appSettingsProvider.notifier).flush();
      expect(store.load().needsPinMigration, isFalse);
    });
  });

  group('PinLockController · kalıcı brute-force', () {
    AppSettings lockedSettings({bool biometric = false}) => const AppSettings(
      pinLockEnabled: true,
    ).copyWith(biometricEnabled: biometric).withPin('2580');

    test('5 hatalı deneme kalıcıdır ve yeni oturumda da kilitlidir', () async {
      final MemoryAppSettingsStore store = MemoryAppSettingsStore(
        lockedSettings(),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final PinLockController controller = container.read(
        pinLockProvider.notifier,
      );
      for (int i = 0; i < PinAttemptPolicy.freeAttempts; i++) {
        expect(await controller.unlockWithPinAsync('1111'), isFalse);
      }
      await container.read(appSettingsProvider.notifier).flush();

      expect(store.load().pinFailedAttempts, PinAttemptPolicy.freeAttempts);
      expect(store.load().isPinLockedOut, isTrue);

      // Yeni uygulama oturumu: sayaç sıfırlanmaz.
      final ProviderContainer restarted = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restarted.dispose);
      final PinLockController reborn = restarted.read(pinLockProvider.notifier);
      expect(reborn.isLockedOut, isTrue);
      expect(reborn.lockoutRemaining, greaterThan(Duration.zero));
      expect(await reborn.unlockWithPinAsync('2580'), isFalse);
    });

    test('bekleme sırasında biyometrik kilit de reddedilir', () async {
      final MemoryAppSettingsStore store = MemoryAppSettingsStore(
        lockedSettings(biometric: true),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final PinLockController controller = container.read(
        pinLockProvider.notifier,
      );
      for (int i = 0; i < PinAttemptPolicy.freeAttempts; i++) {
        await controller.unlockWithPinAsync('0000');
      }
      expect(controller.isLockedOut, isTrue);
      final BiometricResult result = await controller.unlockWithBiometrics();
      expect(result.status, BiometricStatus.lockedOut);
      expect(container.read(pinLockProvider), isTrue);
    });

    test('kilit ilk açıldığında varsayılan PIN hash’lenir', () {
      final MemoryAppSettingsStore store = MemoryAppSettingsStore(
        const AppSettings(),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(appSettingsProvider.notifier).setPinLockEnabled(true);
      final AppSettings settings = container.read(appSettingsProvider);
      expect(settings.pinLockEnabled, isTrue);
      expect(settings.hasPin, isTrue);
      expect(settings.pinAlgorithm, PinAlgorithm.pbkdf2Sha256.id);
      expect(settings.verifyPin(AppSettings.defaultPin), isTrue);
    });
  });

  group('Hassas ayarlar · maskeleme ve güvenli depo', () {
    test('oda kodu / anon key / App ID maskelenir', () {
      const AppSettings settings = AppSettings(
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig',
        roomCode: 'YUSUF-CEYDA-2026',
        oneSignalAppId: '12345678-abcd-ef00-1122-334455667788',
      );
      expect(settings.maskedRoomCode, 'YUS•••26');
      expect(settings.maskedRoomCode.contains('CEYDA'), isFalse);
      expect(settings.maskedAnonKey, '••••.sig');
      expect(settings.maskedOneSignalAppId, '1234••••');
      expect(settings.redactedSummary.contains('YUSUF-CEYDA'), isFalse);
    });

    test('güvenli depo yazma hatası sessizce yutulmaz', () async {
      final MemorySecureSecretsStore secrets = MemorySecureSecretsStore()
        ..available = false;
      await expectLater(
        secrets.write('pin_hash', 'abc'),
        throwsA(isA<SecureSecretsException>()),
      );
      expect(secrets.read('pin_hash'), isNull);
    });
  });
}
