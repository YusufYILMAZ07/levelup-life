import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/game_state.dart';
import '../domain/entities/entities.dart';
import 'app_settings.dart';

/// Bağlantı durumu — ayarlar ekranındaki durum satırını besler.
enum SyncStatus { disabled, connecting, connected, error }

/// Supabase bağlantı yapılandırması (oda kodu + cihaz rolü).
final class SyncConfig {
  const SyncConfig({
    required this.url,
    required this.anonKey,
    required this.roomCode,
    required this.deviceRole,
  });

  factory SyncConfig.fromSettings(AppSettings settings) => SyncConfig(
    url: settings.supabaseUrl.trim(),
    anonKey: settings.supabaseAnonKey.trim(),
    roomCode: settings.normalizedRoomCode,
    deviceRole: settings.deviceRole,
  );

  final String url;
  final String anonKey;
  final String roomCode;
  final String deviceRole;

  bool get isValid {
    final Uri? uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        anonKey.isNotEmpty &&
        roomCode.isNotEmpty;
  }

  bool sameAs(SyncConfig other) =>
      url == other.url &&
      anonKey == other.anonKey &&
      roomCode == other.roomCode &&
      deviceRole == other.deviceRole;
}

/// Yusuf & Ceyda'nın iki ayrı telefondan **canlı** senkronizasyonu.
///
/// Tasarım ilkesi: **bulut tamamen opsiyonel**. Yapılandırma yoksa hiçbir
/// ağ çağrısı yapılmaz; uygulama %100 yerel (`LocalGameStore`) çalışır.
/// Bağlantı kurulamazsa da hiçbir ekran çökmez — yalnızca durum "hata"
/// olur ve tekrar denenebilir.
///
/// ## Supabase kurulumu (30 saniye)
/// Supabase Dashboard → **SQL Editor** → aşağıdaki bloğu yapıştırıp çalıştır:
///
/// ```sql
/// -- 1) Çift odası: tek satırda tüm oyun durumu (JSONB)
/// create table if not exists public.couple_rooms (
///   room_code  text primary key,
///   state_json jsonb not null default '{}'::jsonb,
///   updated_at timestamptz not null default now()
/// );
///
/// -- 2) Sohbet mesajları: delta senkronu (tek tek satırlar)
/// create table if not exists public.chat_messages (
///   id         text primary key,
///   room_code  text not null references public.couple_rooms(room_code) on delete cascade,
///   sender_id  text not null,
///   payload    jsonb not null,
///   created_at timestamptz not null default now()
/// );
///
/// -- 3) RLS: sadece bu iki kişilik özel oda (anon anahtar + oda kodu)
/// alter table public.couple_rooms enable row level security;
/// alter table public.chat_messages enable row level security;
/// drop policy if exists "couple_rooms_all" on public.couple_rooms;
/// create policy "couple_rooms_all" on public.couple_rooms
///   for all using (true) with check (true);
/// drop policy if exists "chat_messages_all" on public.chat_messages;
/// create policy "chat_messages_all" on public.chat_messages
///   for all using (true) with check (true);
///
/// -- 4) Medya kovası (fotoğraf + video)
/// insert into storage.buckets (id, name, public)
/// values ('couple-media', 'couple-media', true)
/// on conflict (id) do nothing;
/// drop policy if exists "couple_media_all" on storage.objects;
/// create policy "couple_media_all" on storage.objects
///   for all using (bucket_id = 'couple-media')
///   with check (bucket_id = 'couple-media');
///
/// -- 5) Realtime yayını
/// alter publication supabase_realtime add table public.chat_messages;
/// alter publication supabase_realtime add table public.couple_rooms;
/// ```
///
/// Not: 5. adım tablo zaten yayındaysa hata verebilir; mesajı yok say.
final class SupabaseSyncService {
  SupabaseSyncService({
    required this.onRemoteMessage,
    required this.onRemoteState,
    required this.onStatusChanged,
    this.onRemoteHistory,
  });

  static const String mediaBucket = 'couple-media';
  static const String roomsTable = 'couple_rooms';
  static const String messagesTable = 'chat_messages';

  /// Ayarlar → "SQL şemasını kopyala" düğmesinin içeriği.
  static const String schemaSql = r'''
-- Yusuf & Ceyda · Supabase kurulumu (tek seferlik)
create table if not exists public.couple_rooms (
  room_code  text primary key,
  state_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id         text primary key,
  room_code  text not null references public.couple_rooms(room_code) on delete cascade,
  sender_id  text not null,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.couple_rooms enable row level security;
alter table public.chat_messages enable row level security;
drop policy if exists "couple_rooms_all" on public.couple_rooms;
create policy "couple_rooms_all" on public.couple_rooms
  for all using (true) with check (true);
drop policy if exists "chat_messages_all" on public.chat_messages;
create policy "chat_messages_all" on public.chat_messages
  for all using (true) with check (true);

insert into storage.buckets (id, name, public)
values ('couple-media', 'couple-media', true)
on conflict (id) do nothing;
drop policy if exists "couple_media_all" on storage.objects;
create policy "couple_media_all" on storage.objects
  for all using (bucket_id = 'couple-media')
  with check (bucket_id = 'couple-media');

alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.couple_rooms;
''';

  final void Function(ChatMessage message) onRemoteMessage;
  final void Function(GameState state) onRemoteState;
  final void Function(SyncStatus status, String message) onStatusChanged;

  /// Bağlantı sonrası son 200 mesaj (eskiden yeniye) buradan iletilir.
  final void Function(List<ChatMessage> messages)? onRemoteHistory;

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  SyncConfig? _config;
  bool _connecting = false;
  DateTime? _lastRemoteStateAt;

  static bool _bootstrapped = false;
  static String? _bootstrappedUrl;

  bool get isConnected => _client != null && _channel != null;

  SyncConfig? get config => _config;

  /// Odaya bağlanır. Hata durumunda `false` döner, exception fırlatmaz.
  Future<bool> connect(SyncConfig config) async {
    if (!config.isValid) {
      onStatusChanged(SyncStatus.disabled, 'Supabase bilgileri eksik.');
      return false;
    }
    if (_connecting) return false;
    if (_config?.sameAs(config) == true && isConnected) return true;

    await disconnect();
    _connecting = true;
    onStatusChanged(SyncStatus.connecting, 'Bağlanıyor…');
    try {
      if (!_bootstrapped) {
        await Supabase.initialize(
          url: config.url,
          // supabase_flutter 2.8.x uyumlu: Dashboard'daki "anon public".
          // ignore: deprecated_member_use
          anonKey: config.anonKey,
        );
        _bootstrapped = true;
        _bootstrappedUrl = config.url;
      } else if (_bootstrappedUrl != config.url) {
        onStatusChanged(
          SyncStatus.error,
          'Başka bir Supabase projesi için uygulamayı yeniden başlat.',
        );
        return false;
      }

      final SupabaseClient client = Supabase.instance.client;
      await client.from(roomsTable).upsert(<String, dynamic>{
        'room_code': config.roomCode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, ignoreDuplicates: true);

      final RealtimeChannel channel = client.channel(
        'couple-room-${config.roomCode}',
      );
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: messagesTable,
        filters: <PostgresChangeFilter>[
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_code',
            value: config.roomCode,
          ),
        ],
        callback: _handleMessagePayload,
      );
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: roomsTable,
        filters: <PostgresChangeFilter>[
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_code',
            value: config.roomCode,
          ),
        ],
        callback: _handleRoomPayload,
      );
      channel.subscribe((RealtimeSubscribeStatus status, Object? error) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            onStatusChanged(SyncStatus.connected, 'Canlı · ${config.roomCode}');
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            if (identical(_channel, channel)) {
              onStatusChanged(
                SyncStatus.error,
                'Bağlantı koptu · ${error ?? 'tekrar denenecek'}',
              );
            }
        }
      });

      _client = client;
      _channel = channel;
      _config = config;

      // İlk bağlantıda odadaki mevcut durumu çek (geçmiş sohbet + ilerleme).
      try {
        final Map<String, dynamic>? room = await client
            .from(roomsTable)
            .select('state_json, updated_at')
            .eq('room_code', config.roomCode)
            .maybeSingle();
        final Object? rawState = room?['state_json'];
        if (rawState is Map && rawState.isNotEmpty) {
          final Object? rawUpdated = room?['updated_at'];
          final DateTime? updatedAt = rawUpdated is String
              ? DateTime.tryParse(rawUpdated)
              : null;
          if (updatedAt != null) _lastRemoteStateAt = updatedAt;
          onRemoteState(
            GameState.fromJson(Map<String, dynamic>.from(rawState)),
          );
        }
      } catch (_) {
        // Tablo henüz kurulmamış olabilir; bağlantı yine de çalışır.
      }

      // Son 200 mesajı çek. Boş gelse bile callback çağrılır; koordinatör
      // yereldeki mesajları buluta geri doldurur → sıfır veri kaybı.
      try {
        final List<ChatMessage> history = await pullFullHistory(limit: 200);
        onRemoteHistory?.call(history);
      } catch (_) {
        // Geçmiş çekilemezse canlı akış yine çalışır.
      }

      onStatusChanged(SyncStatus.connected, 'Canlı · ${config.roomCode}');
      return true;
    } catch (error) {
      onStatusChanged(SyncStatus.error, _friendly(error));
      _channel = null;
      _client = null;
      _config = null;
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    final RealtimeChannel? channel = _channel;
    final SupabaseClient? client = _client;
    _channel = null;
    _config = null;
    if (channel != null && client != null) {
      try {
        await client.removeChannel(channel);
      } catch (_) {
        // Kanal zaten kapanmış olabilir.
      }
    }
    if (client != null) {
      onStatusChanged(SyncStatus.disabled, 'Bulut kapalı · yerel mod');
    }
  }

  /// Tüm oyun durumunu odaya yazar (rubrik, plan, kapsül, bucket list…).
  Future<bool> pushState(GameState state) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    try {
      await client.from(roomsTable).upsert(<String, dynamic>{
        'room_code': config.roomCode,
        'state_json': state.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Yeni sohbet mesajını Realtime abonelerine yayınlar.
  Future<bool> insertMessage(ChatMessage message) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    try {
      await client.from(messagesTable).upsert(<String, dynamic>{
        'id': message.id,
        'room_code': config.roomCode,
        'sender_id': message.senderId,
        'payload': message.toJson(),
        'created_at': message.createdAt.toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bağlantı kurulduğunda son [limit] mesajı çeker (eskiden yeniye).
  Future<List<ChatMessage>> pullFullHistory({int limit = 200}) =>
      fetchMessages(limit: limit);

  /// Eski mesaj sayfalama: [before] anından daha eski kayıtları getirir.
  Future<List<ChatMessage>> fetchMessages({
    int limit = 200,
    DateTime? before,
  }) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return const <ChatMessage>[];
    try {
      final int safeLimit = limit.clamp(1, 500);
      final List<dynamic> rows = before == null
          ? await client
                .from(messagesTable)
                .select('payload, created_at')
                .eq('room_code', config.roomCode)
                .order('created_at', ascending: false)
                .limit(safeLimit)
          : await client
                .from(messagesTable)
                .select('payload, created_at')
                .eq('room_code', config.roomCode)
                .lt('created_at', before.toUtc().toIso8601String())
                .order('created_at', ascending: false)
                .limit(safeLimit);
      final List<ChatMessage> messages = <ChatMessage>[];
      for (final dynamic row in rows) {
        if (row is! Map) continue;
        final Object? raw = row['payload'];
        if (raw is! Map) continue;
        final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
        json['created_at'] ??= row['created_at'];
        try {
          final ChatMessage message = ChatMessage.fromJson(json);
          if (message.id.trim().isNotEmpty) messages.add(message);
        } catch (_) {
          // Tek bozuk satır geçmişin tamamını düşürmez.
        }
      }
      return mergeHistory(const <ChatMessage>[], messages);
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  /// id ile tekilleştirir ve kronolojik sıraya koyar.
  ///
  /// Yerelde aynı id varsa yerel kopya korunur (okundu/beğeni gibi cihaz
  /// üstündeki güncel durumu ezmemek için).
  static List<ChatMessage> mergeHistory(
    List<ChatMessage> local,
    List<ChatMessage> remote,
  ) {
    final Map<String, ChatMessage> byId = <String, ChatMessage>{
      for (final ChatMessage message in local) message.id: message,
    };
    for (final ChatMessage message in remote) {
      byId.putIfAbsent(message.id, () => message);
    }
    final List<ChatMessage> merged = byId.values.toList(growable: false);
    merged.sort((ChatMessage a, ChatMessage b) {
      final int byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return merged;
  }

  /// Fotoğraf / videoyu `couple-media` kovasına yükler, public URL döner.
  Future<String?> uploadMediaBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null || bytes.isEmpty) return null;
    try {
      final String safeName = fileName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final String path =
          '${config.roomCode}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await client.storage
          .from(mediaBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return client.storage.from(mediaBucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  void _handleMessagePayload(PostgresChangePayload payload) {
    final SyncConfig? config = _config;
    if (config == null) return;
    final Map<String, dynamic> record = payload.newRecord;
    if (record['room_code']?.toString() != config.roomCode) return;
    if (record['sender_id']?.toString() == config.deviceRole) return;
    final Object? raw = record['payload'];
    if (raw is! Map) return;
    try {
      final ChatMessage message = ChatMessage.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (message.id.trim().isEmpty) return;
      onRemoteMessage(message);
    } catch (_) {
      // Bozuk satır diğer mesajların akışını bozmaz.
    }
  }

  void _handleRoomPayload(PostgresChangePayload payload) {
    final SyncConfig? config = _config;
    if (config == null) return;
    final Map<String, dynamic> record = payload.newRecord;
    if (record['room_code']?.toString() != config.roomCode) return;
    final Object? rawUpdated = record['updated_at'];
    final DateTime? updatedAt = rawUpdated is String
        ? DateTime.tryParse(rawUpdated)
        : null;
    if (updatedAt != null &&
        _lastRemoteStateAt != null &&
        !updatedAt.isAfter(_lastRemoteStateAt!)) {
      // Gecikmiş / eski paket yeni durumu ezmesin.
      return;
    }
    if (updatedAt != null) _lastRemoteStateAt = updatedAt;
    final Object? raw = record['state_json'];
    if (raw is! Map) return;
    try {
      onRemoteState(GameState.fromJson(Map<String, dynamic>.from(raw)));
    } catch (_) {
      // Şema sürümü uyuşmazsa yerel durum korunur.
    }
  }

  static String _friendly(Object error) {
    final String text = error.toString().toLowerCase();
    if (text.contains('invalid api key') ||
        text.contains('jwt') ||
        text.contains('unauthorized')) {
      return 'Anon anahtar geçersiz görünüyor.';
    }
    if (text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('network')) {
      return 'İnternet bağlantısı yok · yerel mod sürüyor.';
    }
    if (text.contains('relation') &&
        (text.contains('does not exist') || text.contains('bulunamadı'))) {
      return 'SQL şeması henüz kurulmamış. README’deki SQL’i çalıştır.';
    }
    return 'Bağlantı kurulamadı · yerel mod sürüyor.';
  }
}
