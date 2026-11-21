import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/services/app_settings.dart';

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

    test('PIN yalnızca ilk 4 rakamı alır ve varsayılan 3101’dir', () {
      expect(AppSettings.normalizePin('31a01'), '3101');
      expect(AppSettings.normalizePin('310199'), '3101');
      expect(AppSettings.defaultPin, '3101');
      expect(AppSettings.matchesPin('3101', AppSettings.defaultPin), isTrue);
      expect(AppSettings.matchesPin('310', AppSettings.defaultPin), isFalse);
      expect(AppSettings.matchesPin('3102', AppSettings.defaultPin), isFalse);
    });

    test('JSON gidiş-dönüşü avatarları ve bulut bilgisini korur', () {
      const AppSettings settings = AppSettings(
        messageNotifications: false,
        planReminders: false,
        dailyCheckinReminder: true,
        pinLockEnabled: true,
        pinCode: '2580',
        supabaseUrl: 'https://demo.supabase.co',
        supabaseAnonKey: 'anon-key',
        roomCode: ' bizim-oda ',
        deviceRole: 'ceyda',
        lockToDeviceOwner: true,
        deviceOwnerConfigured: true,
        oneSignalAppId: 'os-app',
        oneSignalRestApiKey: 'os-key',
        avatarSources: <String, String>{
          'yusuf': 'data:image/png;base64,AAA',
          'ceyda': '/media/ceyda.jpg',
        },
      );

      final AppSettings restored = AppSettings.fromJson(settings.toJson());

      expect(restored.messageNotifications, isFalse);
      expect(restored.planReminders, isFalse);
      expect(restored.pinLockEnabled, isTrue);
      expect(restored.pinCode, '2580');
      expect(restored.roomCode, ' bizim-oda ');
      expect(restored.normalizedRoomCode, 'BIZIM-ODA');
      expect(restored.deviceRole, 'ceyda');
      expect(restored.lockToDeviceOwner, isTrue);
      expect(restored.deviceOwnerConfigured, isTrue);
      expect(restored.oneSignalAppId, 'os-app');
      expect(restored.oneSignalRestApiKey, 'os-key');
      expect(restored.isPushConfigured, isTrue);
      expect(restored.avatarOf('yusuf'), 'data:image/png;base64,AAA');
      expect(restored.avatarOf('ceyda'), '/media/ceyda.jpg');
      expect(restored.isCloudConfigured, isTrue);
      expect(restored.hasAnyAvatar, isTrue);
    });

    test('bozuk PIN varsayılana döner', () {
      final AppSettings restored = AppSettings.fromJson(<String, dynamic>{
        'pin_code': '12',
        'pin_lock_enabled': true,
      });
      expect(restored.pinCode, AppSettings.defaultPin);
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
}
