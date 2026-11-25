import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/services/supabase_sync_service.dart';

/// v6.3: kurtarma RPC sonuçlarının anlamlı sonuç/mesaja eşlenmesi.
void main() {
  group('RoleReclaimResult', () {
    test('yalnızca ok sonucu başarı sayılır', () {
      for (final RoleReclaimOutcome outcome in RoleReclaimOutcome.values) {
        expect(
          RoleReclaimResult(outcome).isOk,
          outcome == RoleReclaimOutcome.ok,
        );
      }
    });

    test('her sonuç boş olmayan Türkçe mesaj üretir', () {
      for (final RoleReclaimOutcome outcome in RoleReclaimOutcome.values) {
        final String message = RoleReclaimResult(outcome).displayMessage;
        expect(message.trim(), isNotEmpty, reason: '$outcome için mesaj yok');
      }
      expect(
        RoleReclaimResult(RoleReclaimOutcome.locked).displayMessage,
        contains('15'),
        reason: 'kilit mesajı süreyi söylemeli',
      );
      expect(
        RoleReclaimResult(RoleReclaimOutcome.invalid).displayMessage,
        contains('hatalı'),
      );
      expect(
        RoleReclaimResult(RoleReclaimOutcome.notConfigured).displayMessage,
        contains('tanımlı değil'),
      );
      expect(
        RoleReclaimResult(RoleReclaimOutcome.invalidInput).displayMessage,
        contains('boş'),
      );
    });

    test('RPC’den gelen özel mesaj varsa o gösterilir', () {
      const RoleReclaimResult result = RoleReclaimResult(
        RoleReclaimOutcome.failed,
        message: 'Rol geri alınamadı · ağ yok',
      );
      expect(result.displayMessage, 'Rol geri alınamadı · ağ yok');
    });
  });

  group('RecoverySecretResult', () {
    test('yalnızca dolu kod başarı sayılır', () {
      expect(const RecoverySecretResult().isOk, isFalse);
      expect(const RecoverySecretResult(secret: '   ').isOk, isFalse);
      expect(
        const RecoverySecretResult(secret: 'a1b2c3', message: 'hazır').isOk,
        isTrue,
      );
    });
  });
}
