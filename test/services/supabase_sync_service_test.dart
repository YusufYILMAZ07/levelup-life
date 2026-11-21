import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';
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

  group('pullFullHistory birleştirmesi', () {
    ChatMessage message(String id, DateTime at, {String text = ''}) =>
        ChatMessage(
          id: id,
          senderId: CouplePartner.yusufId,
          createdAt: at,
          text: text,
        );

    test('id ile tekilleştirir, yerel kopyayı korur ve kronolojik sıralar', () {
      final ChatMessage localOld = message(
        'm1',
        DateTime(2026, 11, 20, 10),
        text: 'yerel',
      );
      final ChatMessage remoteEarlier = message(
        'm2',
        DateTime(2026, 11, 20, 9),
        text: 'uzak',
      );
      final ChatMessage remoteDuplicate = message(
        'm1',
        DateTime(2026, 11, 20, 10),
        text: 'eski kopya',
      );

      final List<ChatMessage> merged = SupabaseSyncService.mergeHistory(
        <ChatMessage>[localOld],
        <ChatMessage>[remoteEarlier, remoteDuplicate],
      );

      expect(merged, hasLength(2));
      expect(merged.first.id, 'm2');
      expect(merged.last.id, 'm1');
      expect(merged.last.text, 'yerel');
    });

    test('boş yerelde tüm geçmişi kronolojik döndürür', () {
      final List<ChatMessage> merged = SupabaseSyncService.mergeHistory(
        const <ChatMessage>[],
        <ChatMessage>[
          message('b', DateTime(2026, 11, 20, 11)),
          message('a', DateTime(2026, 11, 20, 8)),
        ],
      );
      expect(merged.map((ChatMessage item) => item.id), <String>['a', 'b']);
    });
  });
}
