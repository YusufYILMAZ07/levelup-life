import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/pin_security.dart';

void main() {
  group('AppSettings doğrulama yardımcıları', () {
    test('oda kodu büyük harfe çevrilir ve boşluklar tire olur', () {
      expect(
        AppSettings.normalizeRoomCode('  yusuf ceyda 2026 '),
        'YUSUF-CEYDA-2026',
      );
      expect(AppSettings.normalizeRoomCode(''), '');
      expect(AppSettings.defaultRoomCode, 'YUSUF-CEYDA-2026');
    });

    test('PIN yalnızca ilk 4 rakamı alır, düz metin saklanmaz', () {
      expect(AppSettings.normalizePin('31a01'), '3101');
      expect(AppSettings.normalizePin('310199'), '3101');
      expect(AppSettings.defaultPin, '3101');

      const AppSettings fresh = AppSettings();
      expect(fresh.hasPin, isFalse);
      // Hash yokken varsayılan yıldönümü PIN'i geçerlidir.
      expect(fresh.verifyPin('3101'), isTrue);
      expect(fresh.verifyPin('310'), isFalse);
      expect(fresh.verifyPin('3102'), isFalse);
    });

    test('withPin tuzlu SHA-256 üretir ve doğrular', () {
      final AppSettings settings = const AppSettings().withPin('2580');
      expect(settings.hasPin, isTrue);
      expect(settings.pinHash, hasLength(64));
      expect(settings.pinSalt, hasLength(32));
      expect(settings.pinHash.contains('2580'), isFalse);
      expect(settings.verifyPin('2580'), isTrue);
      expect(settings.verifyPin('3101'), isFalse);
    });
  });

  group('PIN ve güvenlik ayarları', () {
    test('JSON gidiş-dönüşü ayarları korur, hassas alanlar ayrılabilir', () {
      final AppSettings settings =
          const AppSettings().withPin('2580').copyWith(
            messageNotifications: false,
            planReminders: false,
            dailyCheckinHour: 22,
            dailyCheckinMinute: 15,
            doNotDisturbEnabled: true,
            quietStartMinutes: 23 * 60 + 30,
            quietEndMinutes: 7 * 60,
            pinLockEnabled: true,
            biometricEnabled: true,
            lockGraceSeconds: 60,
            supabaseUrl: 'https://demo.supabase.co',
            supabaseAnonKey: 'anon-key',
            roomCode: ' bizim-oda ',
            deviceRole: 'ceyda',
            lockToDeviceOwner: true,
            deviceOwnerConfigured: true,
            oneSignalAppId: 'os-app',
            avatarSources: <String, String>{
              'yusuf': 'data:image/png;base64,AAA',
              'ceyda': '/media/ceyda.jpg',
            },
          );

      final AppSettings restored = AppSettings.fromJson(settings.toJson());

      expect(restored.messageNotifications, isFalse);
      expect(restored.planReminders, isFalse);
      expect(restored.dailyCheckinHour, 22);
      expect(restored.dailyCheckinMinute, 15);
      expect(restored.doNotDisturbEnabled, isTrue);
      expect(restored.pinLockEnabled, isTrue);
      expect(restored.biometricEnabled, isTrue);
      expect(restored.lockGraceSeconds, 60);
      expect(restored.verifyPin('2580'), isTrue);
      expect(restored.roomCode, ' bizim-oda ');
      expect(restored.normalizedRoomCode, 'BIZIM-ODA');
      expect(restored.deviceRole, 'ceyda');
      expect(restored.lockToDeviceOwner, isTrue);
      expect(restored.oneSignalAppId, 'os-app');
      expect(restored.isPushConfigured, isTrue);
      expect(restored.avatarOf('yusuf'), 'data:image/png;base64,AAA');
      expect(restored.avatarOf('ceyda'), '/media/ceyda.jpg');
      expect(restored.isCloudConfigured, isTrue);

      final Map<String, dynamic> prefsJson = settings.toJson(
        includeSecrets: false,
      );
      expect(prefsJson.containsKey('pin_hash'), isFalse);
      expect(prefsJson.containsKey('pin_salt'), isFalse);
      expect(prefsJson.containsKey('pin_code'), isFalse);

      final Map<String, String> secrets = settings.sensitiveValues();
      expect(secrets['pin_hash'], settings.pinHash);
      expect(secrets['pin_salt'], settings.pinSalt);
    });

    test('v5 düz metin PIN kaydı hash’e taşınır', () {
      final AppSettings restored = AppSettings.fromJson(<String, dynamic>{
        'pin_code': '2580',
        'pin_lock_enabled': true,
      });
      expect(restored.hasPin, isTrue);
      expect(restored.verifyPin('2580'), isTrue);
      expect(restored.verifyPin('3101'), isFalse);
      expect(restored.toJson(includeSecrets: false).containsKey('pin_code'), isFalse);
    });

    test('eksik PIN varsayılana döner', () {
      final AppSettings restored = AppSettings.fromJson(<String, dynamic>{
        'pin_lock_enabled': true,
      });
      expect(restored.hasPin, isFalse);
      expect(restored.verifyPin(AppSettings.defaultPin), isTrue);
    });

    test('sessiz saatler gece yarısını aşan aralıkta doğru hesaplanır', () {
      const AppSettings settings = AppSettings(
        doNotDisturbEnabled: true,
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60,
      );
      expect(settings.isQuietAt(DateTime(2026, 11, 23, 23, 30)), isTrue);
      expect(settings.isQuietAt(DateTime(2026, 11, 24, 6, 59)), isTrue);
      expect(settings.isQuietAt(DateTime(2026, 11, 24, 7, 0)), isFalse);
      expect(settings.isQuietAt(DateTime(2026, 11, 24, 12, 0)), isFalse);
      expect(settings.shiftOutOfQuietHours(23 * 60 + 30), 7 * 60);
      expect(settings.shiftOutOfQuietHours(12 * 60), 12 * 60);
    });

    test('grace period 0..300 aralığına kırpılır', () {
      final AppSettings high = AppSettings.fromJson(<String, dynamic>{
        'lock_grace_seconds': 999,
      });
      final AppSettings low = AppSettings.fromJson(<String, dynamic>{
        'lock_grace_seconds': -10,
      });
      expect(high.lockGraceSeconds, AppSettings.maxLockGraceSeconds);
      expect(low.lockGraceSeconds, AppSettings.minLockGraceSeconds);
    });

    test('avatar ekleme ve kaldırma yeni kopya üretir', () {
      const AppSettings settings = AppSettings();
      final AppSettings withAvatar = settings.withAvatar(
        'yusuf',
        '/media/a.jpg',
      );
      expect(withAvatar.avatarOf('yusuf'), '/media/a.jpg');
      expect(settings.avatarOf('yusuf'), '');
      expect(withAvatar.withoutAvatar('yusuf').avatarOf('yusuf'), '');
    });
  });

  group('PinCredential', () {
    test('aynı PIN + aynı tuz aynı hash’i verir, farklı tuz farklı hash', () {
      final PinCredential a = PinCredential.create('1234', salt: 'abcd');
      final PinCredential b = PinCredential.create('1234', salt: 'abcd');
      final PinCredential c = PinCredential.create('1234', salt: 'abce');
      expect(a.hash, b.hash);
      expect(a.hash, isNot(c.hash));
      expect(a.matches('1234'), isTrue);
      expect(a.matches('4321'), isFalse);
    });

    test('brute-force beklemesi 5. hatadan sonra artar', () {
      expect(PinAttemptPolicy.lockoutFor(0), Duration.zero);
      expect(PinAttemptPolicy.lockoutFor(4), Duration.zero);
      expect(PinAttemptPolicy.lockoutFor(5), PinAttemptPolicy.baseLockout);
      expect(
        PinAttemptPolicy.lockoutFor(6),
        greaterThan(PinAttemptPolicy.lockoutFor(5)),
      );
      expect(PinAttemptPolicy.lockoutFor(50), PinAttemptPolicy.maxLockout);
    });
  });
}
