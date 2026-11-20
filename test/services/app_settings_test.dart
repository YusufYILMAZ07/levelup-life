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

    test('PIN yalnızca ilk 4 rakamı alır', () {
      expect(AppSettings.normalizePin('14a02'), '1402');
      expect(AppSettings.normalizePin('140299'), '1402');
      expect(AppSettings.matchesPin('1402', AppSettings.defaultPin), isTrue);
      expect(AppSettings.matchesPin('140', AppSettings.defaultPin), isFalse);
      expect(AppSettings.matchesPin('1403', AppSettings.defaultPin), isFalse);
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
