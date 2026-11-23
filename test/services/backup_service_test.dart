import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/services/backup_service.dart';

void main() {
  group('BackupService', () {
    test('export → parse tüm durumu korur', () {
      final GameState state = CoupleBootstrap.initialState();
      final String raw = BackupService.export(
        state,
        at: DateTime.utc(2026, 11, 23, 12),
      );

      final BackupRestore restore = BackupService.parse(raw);

      expect(restore.schemaVersion, BackupService.supportedSchema);
      expect(restore.exportedAt.toUtc(), DateTime.utc(2026, 11, 23, 12));
      expect(restore.state.isCoupleEdition, isTrue);
      expect(
        restore.state.couple.messages.length,
        state.couple.messages.length,
      );
      expect(
        restore.state.partnerData('yusuf')?.profile?.totalXp,
        state.partnerData('yusuf')?.profile?.totalXp,
      );
    });

    test('boş metin / bozuk JSON reddedilir', () {
      expect(() => BackupService.parse('  '), throwsA(isA<BackupException>()));
      expect(
        () => BackupService.parse('{bozuk'),
        throwsA(isA<BackupException>()),
      );
    });

    test('başka uygulamanın yedeği reddedilir', () {
      expect(
        () => BackupService.parse(
          '{"app":"baska-uygulama","state":{"couple":{},"partners":{}}}',
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('eksik çift/partner verisi reddedilir', () {
      expect(
        () => BackupService.parse(
          '{"app":"levelup-life","schema_version":6,'
          '"state":{"partners":{"yusuf":{}}}}',
        ),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => BackupService.parse(
          '{"app":"levelup-life","schema_version":6,'
          '"state":{"couple":{}}}',
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('gelecek şema sürümü reddedilir', () {
      final String raw = BackupService.export(CoupleBootstrap.initialState())
          .replaceFirst('"schema_version": 6', '"schema_version": 99');
      expect(
        () => BackupService.parse(raw),
        throwsA(
          isA<BackupException>().having(
            (BackupException error) => error.message,
            'message',
            contains('yeni bir sürüm'),
          ),
        ),
      );
    });
  });
}
