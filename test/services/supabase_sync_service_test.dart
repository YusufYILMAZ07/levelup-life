import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/services/supabase_sync_service.dart';

void main() {
  group('SyncConfig', () {
    test('eksik bilgilerde geçersizdir', () {
      expect(
        const SyncConfig(
          url: '',
          anonKey: '',
          roomCode: '',
          deviceRole: 'yusuf',
        ).isValid,
        isFalse,
      );
      expect(
        const SyncConfig(
          url: 'demo.supabase.co',
          anonKey: 'key',
          roomCode: 'ODA',
          deviceRole: 'yusuf',
        ).isValid,
        isFalse,
      );
    });

    test('https URL + anahtar + oda kodu geçerlidir', () {
      const SyncConfig config = SyncConfig(
        url: 'https://demo.supabase.co',
        anonKey: 'anon',
        roomCode: 'YUSUF-CEYDA-2026',
        deviceRole: 'ceyda',
      );
      expect(config.isValid, isTrue);
      expect(config.sameAs(config), isTrue);
      expect(
        config.sameAs(
          const SyncConfig(
            url: 'https://demo.supabase.co',
            anonKey: 'anon',
            roomCode: 'YUSUF-CEYDA-2026',
            deviceRole: 'yusuf',
          ),
        ),
        isFalse,
      );
    });

    test('SQL şeması iki tabloyu ve medya kovasını içerir', () {
      const String sql = SupabaseSyncService.schemaSql;
      expect(sql, contains('create table if not exists public.couple_rooms'));
      expect(sql, contains('create table if not exists public.chat_messages'));
      expect(sql, contains("'couple-media'"));
      expect(sql, contains('supabase_realtime'));
    });
  });
}
