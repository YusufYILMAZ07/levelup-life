import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/game_state.dart';
import '../domain/entities/entities.dart';
import 'app_settings.dart';

/// Bağlantı durumu — ayarlar ekranındaki durum satırını besler.
enum SyncStatus { disabled, connecting, connected, error }

/// Kurtarma kodu üretim sonucu (v6.3).
///
/// Düz metin kod yalnızca [secret] içinde bulunur ve **yalnızca bir kez**
/// döner; sunucuda bcrypt özeti kalır. [message] başarısızlık nedenini
/// kullanıcıya göstermek içindir.
final class RecoverySecretResult {
  const RecoverySecretResult({this.secret, this.message = ''});

  final String? secret;
  final String message;

  bool get isOk => (secret ?? '').trim().isNotEmpty;
}

/// `reclaim_couple_role` sonucu.
enum RoleReclaimOutcome {
  /// Rol devralındı; uygulama yeniden bağlanabilir.
  ok,

  /// Kod yanlış (sayaç arttı, 5'te kilit).
  invalid,

  /// 15 dakikalık kilit süresi dolmadı.
  locked,

  /// Odada kurtarma sırrı tanımlı değil (`LR002`).
  notConfigured,

  /// Boş kod / geçersiz oda kodu gibi istemci hatası.
  invalidInput,

  /// Ağ, oturum veya beklenmeyen hata.
  failed,
}

final class RoleReclaimResult {
  const RoleReclaimResult(this.outcome, {this.message = ''});

  final RoleReclaimOutcome outcome;
  final String message;

  bool get isOk => outcome == RoleReclaimOutcome.ok;

  /// Kullanıcıya gösterilecek hazır metin (RPC'den gelen mesaj varsa o).
  String get displayMessage {
    if (message.trim().isNotEmpty) return message;
    return switch (outcome) {
      RoleReclaimOutcome.ok => 'Rol geri alındı.',
      RoleReclaimOutcome.invalid => 'Kurtarma kodu hatalı.',
      RoleReclaimOutcome.locked =>
        'Çok fazla hatalı deneme · 15 dakika sonra tekrar dene.',
      RoleReclaimOutcome.notConfigured =>
        'Bu odada kurtarma kodu tanımlı değil.',
      RoleReclaimOutcome.invalidInput => 'Kurtarma kodu boş olamaz.',
      RoleReclaimOutcome.failed =>
        'Rol geri alınamadı · bağlantıyı kontrol et.',
    };
  }
}

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
    if (uri == null ||
        uri.host.isEmpty ||
        anonKey.isEmpty ||
        roomCode.isEmpty) {
      return false;
    }
    final bool isLocalHttp =
        uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '10.0.2.2');
    // Üretimde yalnızca https; http sadece debug localhost için kabul edilir.
    final bool schemeOk = uri.scheme == 'https' || (kDebugMode && isLocalHttp);
    return schemeOk;
  }

  bool sameAs(SyncConfig other) =>
      url == other.url &&
      anonKey == other.anonKey &&
      roomCode == other.roomCode &&
      deviceRole == other.deviceRole;
}

/// Supabase olaylarının koordinatöre taşındığı callback demeti.
final class SyncCallbacks {
  const SyncCallbacks({
    required this.onRemoteMessage,
    required this.onRemoteMessageUpdate,
    required this.onRemoteMessageDeleted,
    required this.onRemoteState,
    required this.onStatusChanged,
    this.onRemoteHistory,
    this.onPresenceChanged,
    this.onTypingChanged,
  });

  final void Function(ChatMessage message) onRemoteMessage;
  final void Function(ChatMessage message) onRemoteMessageUpdate;
  final void Function(String messageId) onRemoteMessageDeleted;
  final void Function(GameState state) onRemoteState;
  final void Function(SyncStatus status, String message) onStatusChanged;
  final void Function(List<ChatMessage> messages)? onRemoteHistory;
  final void Function(bool partnerOnline)? onPresenceChanged;
  final void Function(bool partnerTyping)? onTypingChanged;
}

/// Koordinatörün ihtiyaç duyduğu ağ sözleşmesi (testlerde fake ile değişir).
abstract interface class CloudSyncBackend {
  bool get isConnected;

  Future<bool> connect(SyncConfig config);

  Future<void> disconnect();

  Future<bool> pushState(GameState state);

  Future<bool> insertMessage(ChatMessage message);

  Future<bool> deleteMessage(String messageId);

  Future<bool> setTyping(bool typing);

  Future<List<ChatMessage>> pullFullHistory({int limit = 200});

  Future<List<ChatMessage>> fetchMessages({int limit = 200, DateTime? before});

  Future<String?> uploadMediaBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// Alıcı partnerin okundu bilgisini RPC ile işaretler (o ana kadar).
  Future<int> markMessagesRead(DateTime upTo);

  /// Alıcı partnerin emoji tepkisini RPC ile değiştirir.
  Future<bool> toggleMessageReaction(String messageId, String emoji);

  /// Cihazın bildirim/senkron sağlığını `room_members` satırına yazar.
  Future<void> updateMemberHealth({
    required bool pushEnabled,
    required int? quietStartMinute,
    required int? quietEndMinute,
    required int utcOffsetMinutes,
  });

  /// 401/403 sonrası oturumu ve oda üyeliğini tazeler.
  Future<bool> refreshSessionAndMembership();
}

/// Yusuf & Ceyda'nın iki ayrı telefondan **canlı** senkronizasyonu (v6).
///
/// Güvenlik modeli:
/// * **Anonymous Auth:** her cihaz `auth.uid()` alır.
/// * **`room_members`:** RPC `join_couple_room` yalnızca oda kodunu bilen
///   cihazı (en fazla 2 kişi, rol başına 1) odaya yazar.
/// * **RLS:** `couple_rooms` / `chat_messages` yalnızca doğrulanmış üyeye
///   açıktır; `for all using (true)` politikası **yoktur**.
/// * **Özel kova:** `couple-media` public değildir; dosya yolu
///   `<room_code>/...` altındadır ve erişim **imzalı URL** ile yapılır.
/// * **REST anahtarı sunucuda:** push, `send-couple-push` Edge Function'ından
///   gönderilir (istemcide OneSignal REST anahtarı yok).
///
/// SQL şeması `supabase/migrations/20261123000000_v6_security.sql` içindedir.
final class SupabaseSyncService implements CloudSyncBackend {
  SupabaseSyncService({required this.callbacks});

  static const String mediaBucket = 'couple-media';
  static const String roomsTable = 'couple_rooms';
  static const String messagesTable = 'chat_messages';
  static const String membersTable = 'room_members';
  static const String joinRoomRpc = 'join_couple_room';
  static const String markReadRpc = 'mark_messages_read';
  static const String toggleReactionRpc = 'toggle_message_reaction';
  static const String touchMemberRpc = 'touch_room_member';
  static const String issueRecoverySecretRpc = 'issue_couple_recovery_secret';
  static const String reclaimRoleRpc = 'reclaim_couple_role';
  static const int signedUrlSeconds = 7 * 24 * 60 * 60;

  /// Kanal aboneliğinin kurulması için üst sınır.
  static const Duration subscribeTimeout = Duration(seconds: 10);

  /// Join `ok` döndükten sonra `postgres_changes` kurulumu sunucuda
  /// başarısız olabiliyor (`Unable to subscribe to changes with given
  /// parameters`); bu hata `subscribed` durumundan **sonra** `channelError`
  /// olarak gelir. Başarı ilan etmeden önce bu kısa pencere beklenir.
  static const Duration replicationGrace = Duration(milliseconds: 1200);

  /// Ayarlar → "SQL şemasını kopyala" düğmesinin içeriği.
  ///
  /// Tam şema depodaki migration dosyasındadır; buradaki metin yalnızca
  /// panelde hızlı kurulum için özet niteliğindedir.
  static const String schemaSql = r'''
-- v6 güvenli şema (tam sürüm: supabase/migrations/20261123000000_v6_security.sql)
-- v6.1 için ayrıca: supabase/migrations/20261125000000_v6_1_production_gold.sql
-- (rol kurtarma, okundu/tepki RPC'leri, push_deliveries idempotency, cihaz sağlığı)
create table if not exists public.couple_rooms (
  room_code text primary key,
  state_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.room_members (
  room_code text not null references public.couple_rooms(room_code) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('yusuf','ceyda')),
  joined_at timestamptz not null default now(),
  primary key (room_code, user_id),
  unique (room_code, role)
);
create table if not exists public.chat_messages (
  id text primary key,
  room_code text not null references public.couple_rooms(room_code) on delete cascade,
  sender_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.couple_rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.chat_messages enable row level security;
-- Üyelik kontrolü SECURITY DEFINER fonksiyonu ile yapılır:
--   using (public.is_room_member(room_code))
insert into storage.buckets (id, name, public)
values ('couple-media', 'couple-media', false)
on conflict (id) do update set public = false;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.couple_rooms;
''';

  final SyncCallbacks callbacks;

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  SyncConfig? _config;

  /// En son denenen yapılandırma; kurtarma RPC'leri bağlantı başarısız olsa da
  /// (`role taken`) aynı istemci/oturum üzerinden çalışabilsin diye tutulur.
  SyncConfig? _lastConfig;
  bool _connecting = false;
  DateTime? _lastRemoteStateAt;

  @override
  bool get isConnected => _client != null && _channel != null;

  SyncConfig? get config => _config;

  static String? _bootstrappedUrl;
  static String? _bootstrappedKey;
  static bool _bootstrapped = false;

  /// Supabase istemcisini yapılandırır.
  ///
  /// v5'teki statik `_bootstrapped` bayrağı, URL değişince uygulamanın
  /// yeniden başlatılmasını zorunlu kılıyordu. v6'da eski istemci
  /// `dispose()` edilir ve yeni URL/anahtar ile temiz kurulum yapılır.
  Future<SupabaseClient> _ensureClient(SyncConfig config) async {
    if (_bootstrapped &&
        _bootstrappedUrl == config.url &&
        _bootstrappedKey == config.anonKey) {
      return Supabase.instance.client;
    }
    if (_bootstrapped) {
      try {
        await Supabase.instance.dispose();
      } catch (_) {
        // Daha önce kurulmamış / zaten kapanmış olabilir.
      }
      _bootstrapped = false;
    }
    await Supabase.initialize(url: config.url, publishableKey: config.anonKey);
    _bootstrapped = true;
    _bootstrappedUrl = config.url;
    _bootstrappedKey = config.anonKey;
    return Supabase.instance.client;
  }

  /// Odaya bağlanır. Hata durumunda `false` döner, exception fırlatmaz.
  @override
  Future<bool> connect(SyncConfig config) async {
    if (!config.isValid) {
      callbacks.onStatusChanged(
        SyncStatus.disabled,
        'Supabase bilgileri eksik.',
      );
      return false;
    }
    if (_connecting) return false;
    if (_config?.sameAs(config) == true && isConnected) return true;

    // Kilidi `disconnect()` ÖNCESİNDE al: iki eşzamanlı configure birbirinin
    // kanalını yarı yolda kapatmasın.
    _connecting = true;
    // Kurtarma RPC'leri (`issue…` / `reclaim…`) bağlantı kurulamasa bile aynı
    // URL/anahtar + anonim oturum üzerinden çalışsın.
    _lastConfig = config;
    callbacks.onStatusChanged(SyncStatus.connecting, 'Bağlanıyor…');
    try {
      await disconnect();

      final SupabaseClient client = await _ensureClient(config);

      // 1) Anonymous auth — RLS'in dayandığı kimlik. Süresi dolmuş oturum
      //    yenilenir; yoksa yeni anonim oturum açılır.
      final Session? session = client.auth.currentSession;
      if (session == null || session.isExpired) {
        if (session != null) {
          try {
            await client.auth.refreshSession();
          } catch (_) {
            // Refresh başarısızsa yeni anonim oturum.
          }
        }
        if (client.auth.currentSession == null ||
            client.auth.currentSession!.isExpired) {
          await client.auth.signInAnonymously();
        }
      }

      // 2) Odaya katıl (oda yoksa ilk üye oluşturur).
      await client.rpc(
        joinRoomRpc,
        params: <String, dynamic>{
          'p_room_code': config.roomCode,
          'p_role': config.deviceRole,
        },
      );

      // 3) Realtime: mesajlarda insert + update + delete, oda durumu,
      //    presence ve "yazıyor…" yayını.
      //
      // Önce `room_code` filtreli abonelik denenir. Supabase Realtime bazı
      // filtreleri reddediyorsa (`Unable to subscribe to changes with given
      // parameters`) kanal filtresiz kurulur: RLS zaten yalnızca üye olunan
      // odanın olaylarını iletir, `room_code` eşleşmesi istemcide ikinci kez
      // doğrulanır. Böylece canlı bağlantı hiç kopmaz.
      RealtimeChannel? channel = await _openChannel(
        client,
        config,
        useRoomFilter: true,
      );
      if (channel == null) {
        callbacks.onStatusChanged(
          SyncStatus.connecting,
          'Filtre uygulanamadı · filtresiz bağlanıyor…',
        );
        channel = await _openChannel(
          client,
          config,
          useRoomFilter: false,
        );
      }
      if (channel == null) {
        callbacks.onStatusChanged(SyncStatus.error, 'Kanal açılamadı.');
        return false;
      }

      callbacks.onStatusChanged(
        SyncStatus.connected,
        'Canlı · ${config.roomCode}',
      );
      await channel.track(<String, dynamic>{
        'role': config.deviceRole,
        'online_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _initialSync(client, config);

      _client = client;
      _channel = channel;
      _config = config;
      return true;
    } catch (error) {
      callbacks.onStatusChanged(SyncStatus.error, _friendly(error));
      _channel = null;
      _client = null;
      _config = null;
      return false;
    } finally {
      _connecting = false;
    }
  }

  /// Realtime kanalını kurar, aboneliği bekler ve kanalı döndürür.
  ///
  /// [useRoomFilter] `true` iken `INSERT`/`UPDATE` abonelikleri
  /// `room_code = <oda>` filtresiyle kurulur. `DELETE` olayında Supabase
  /// Realtime kolon filtresini **desteklemez**; bu dinleyici her zaman
  /// filtresiz kurulur (RLS zaten yalnızca üye olunan odanın olaylarını
  /// iletir, callback `room_code` alanını ikinci kez doğrular).
  ///
  /// Sunucu join'i `ok` döndürdükten sonra `postgres_changes` kurulumu
  /// başarısız olursa hata gecikmeli bir `system` iletisiyle gelir ve
  /// realtime istemcisi bunu `channelError` olarak iletir. Bu yüzden
  /// `subscribed` görüldükten hemen sonra başarı ilan edilmez; kısa bir
  /// [replicationGrace] penceresi beklenir. Başarısızlıkta kanal kaldırılır
  /// ve `null` döner; bağlantı durumu çağırana bırakılır.
  Future<RealtimeChannel?> _openChannel(
    SupabaseClient client,
    SyncConfig config, {
    required bool useRoomFilter,
  }) async {
    final String roomCode = config.roomCode.toUpperCase();
    final RealtimeChannel channel = client.channel(
      'couple-room-$roomCode',
      opts: const RealtimeChannelConfig(self: true),
    );
    final List<PostgresChangeFilter> roomFilter = <PostgresChangeFilter>[
      PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_code',
        value: roomCode,
      ),
    ];

    void bindMessageEvent(PostgresChangeEvent event) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: messagesTable,
        filters: useRoomFilter ? roomFilter : null,
        callback: (PostgresChangePayload payload) =>
            _handleMessageChange(event, payload),
      );
    }

    bindMessageEvent(PostgresChangeEvent.insert);
    bindMessageEvent(PostgresChangeEvent.update);
    // DELETE: kolon filtresi desteklenmiyor → filtresiz dinlenir.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: messagesTable,
      callback: (PostgresChangePayload payload) =>
          _handleMessageChange(PostgresChangeEvent.delete, payload),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: roomsTable,
      filters: useRoomFilter ? roomFilter : null,
      callback: _handleRoomPayload,
    );
    channel
      ..onPresenceSync((_) => _emitPresence(channel, config))
      ..onPresenceJoin((_) => _emitPresence(channel, config))
      ..onPresenceLeave((_) => _emitPresence(channel, config))
      ..onBroadcast(
        event: 'typing',
        callback: (Map<String, dynamic> payload) {
          final Object? sender = payload['sender_id'];
          if (sender?.toString() == config.deviceRole) return;
          callbacks.onTypingChanged?.call(payload['typing'] == true);
        },
      );

    final Completer<bool> ready = Completer<bool>();
    Timer? graceTimer;
    void settle(bool ok) {
      graceTimer?.cancel();
      if (!ready.isCompleted) ready.complete(ok);
    }

    channel.subscribe((RealtimeSubscribeStatus status, Object? error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Join `ok` gelse bile replication kurulumu sonradan düşebilir.
        graceTimer ??= Timer(replicationGrace, () => settle(true));
        return;
      }
      if (status == RealtimeSubscribeStatus.channelError &&
          identical(_channel, channel)) {
        // Bağlantı sonradan koptu; ayarlar ekranı bunu görsün.
        callbacks.onStatusChanged(
          SyncStatus.error,
          'Bağlantı koptu · ${error ?? 'tekrar denenecek'}',
        );
      }
      settle(false);
    });

    bool readyOk;
    try {
      readyOk = await ready.future.timeout(subscribeTimeout);
    } on TimeoutException {
      readyOk = false;
    }
    graceTimer?.cancel();
    if (!readyOk) {
      try {
        await client.removeChannel(channel);
      } catch (_) {
        // Kanal zaten kapanmış olabilir.
      }
      return null;
    }
    return channel;
  }

  /// Bağlantı sonrası oda durumu + son 200 mesaj.
  Future<void> _initialSync(SupabaseClient client, SyncConfig config) async {
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
        callbacks.onRemoteState(
          GameState.fromJson(Map<String, dynamic>.from(rawState)),
        );
      }
    } catch (_) {
      // Tablo henüz kurulmamış olabilir; bağlantı yine de çalışır.
    }
    try {
      final List<ChatMessage> history = await pullFullHistory(limit: 200);
      callbacks.onRemoteHistory?.call(history);
    } catch (_) {
      // Geçmiş çekilemezse canlı akış yine çalışır.
    }
  }

  /// Presence listesinden partnerin çevrimiçi olup olmadığını çıkarır.
  void _emitPresence(RealtimeChannel channel, SyncConfig config) {
    try {
      bool partnerOnline = false;
      for (final SinglePresenceState state in channel.presenceState()) {
        for (final Presence presence in state.presences) {
          final String role = presence.payload['role']?.toString() ?? '';
          if (role.isNotEmpty && role != config.deviceRole) {
            partnerOnline = true;
          }
        }
      }
      callbacks.onPresenceChanged?.call(partnerOnline);
    } catch (_) {
      // Presence desteklenmiyorsa sessizce atlanır.
    }
  }

  @override
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
      callbacks.onStatusChanged(
        SyncStatus.disabled,
        'Bulut kapalı · yerel mod',
      );
    }
    _client = null;
    callbacks.onPresenceChanged?.call(false);
  }

  /// Tüm oyun durumunu odaya yazar (rubrik, plan, kapsül, bucket list…).
  @override
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
  @override
  Future<bool> insertMessage(ChatMessage message) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    try {
      // v6.1 öncesi şemada `read_at` / `reactions` kolonları yoktur. Yeni
      // kolonlar RPC'ler tarafından yazılır; INSERT yalnızca v6 sözleşmesini
      // kullanır, böylece migration gecikse bile mesaj akışı bozulmaz.
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

  /// Mesajı buluttan siler (RLS yalnızca kendi gönderdiğini silmeye izin verir).
  @override
  Future<bool> deleteMessage(String messageId) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    try {
      await client
          .from(messagesTable)
          .delete()
          .eq('id', messageId)
          .eq('room_code', config.roomCode);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// "yazıyor…" bilgisini broadcast ile karşı tarafa yollar.
  @override
  Future<bool> setTyping(bool typing) async {
    final RealtimeChannel? channel = _channel;
    final SyncConfig? config = _config;
    if (channel == null || config == null) return false;
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: <String, dynamic>{
          'sender_id': config.deviceRole,
          'typing': typing,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bağlantı kurulduğunda son [limit] mesajı çeker (eskiden yeniye).
  @override
  Future<List<ChatMessage>> pullFullHistory({int limit = 200}) =>
      fetchMessages(limit: limit);

  /// Eski mesaj sayfalama: [before] anından daha eski kayıtları getirir.
  @override
  Future<List<ChatMessage>> fetchMessages({
    int limit = 200,
    DateTime? before,
  }) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return const <ChatMessage>[];
    try {
      final int safeLimit = limit.clamp(1, 500);
      // `*` eski şemada da çalışır; yeni `read_at` / `reactions` kolonları
      // varsa aşağıda payload ile birleştirilir.
      final List<dynamic> rows = before == null
          ? await client
                .from(messagesTable)
                .select('*')
                .eq('room_code', config.roomCode)
                .order('created_at', ascending: false)
                .limit(safeLimit)
          : await client
                .from(messagesTable)
                .select('*')
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
        if (row['read_at'] != null) json['is_read'] = true;
        final Object? reactions = row['reactions'];
        if (reactions is Map && reactions.isNotEmpty) {
          json['reactions'] = reactions;
        }
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

  /// Fotoğraf / videoyu **özel** `couple-media` kovasına yükler ve imzalı URL
  /// döner. Kova public değildir; RLS yolun ilk klasörünü oda kodu olarak
  /// doğrular.
  @override
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
      return await client.storage
          .from(mediaBucket)
          .createSignedUrl(path, signedUrlSeconds);
    } catch (_) {
      return null;
    }
  }

  /// Alıcı partnerin okundu bilgisini yalnızca güvenli RPC üzerinden yazar.
  @override
  Future<int> markMessagesRead(DateTime upTo) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return 0;
    try {
      final Object? count = await client.rpc(
        markReadRpc,
        params: <String, dynamic>{
          'p_room_code': config.roomCode,
          'p_up_to': upTo.toUtc().toIso8601String(),
        },
      );
      return count is num ? count.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Emoji tepkisini RPC ile değiştirir; doğrudan satır güncellemesi yapmaz.
  @override
  Future<bool> toggleMessageReaction(String messageId, String emoji) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    if (messageId.trim().isEmpty || emoji.trim().isEmpty) return false;
    try {
      await client.rpc(
        toggleReactionRpc,
        params: <String, dynamic>{
          'p_room_code': config.roomCode,
          'p_message_id': messageId.trim(),
          'p_emoji': emoji.trim(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cihazın `push_enabled`, sessiz saat ve UTC offset bilgisini üye satırına
  /// yazar. Sunucu tarafı sessiz saat kontrolü bu alanları kullanır.
  @override
  Future<void> updateMemberHealth({
    required bool pushEnabled,
    required int? quietStartMinute,
    required int? quietEndMinute,
    required int utcOffsetMinutes,
  }) async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return;
    try {
      await client.rpc(
        touchMemberRpc,
        params: <String, dynamic>{
          'p_room_code': config.roomCode,
          'p_push_enabled': pushEnabled,
          'p_quiet_start_minute': quietStartMinute?.clamp(0, 1439),
          'p_quiet_end_minute': quietEndMinute?.clamp(0, 1439),
          'p_utc_offset_minutes': utcOffsetMinutes.clamp(-840, 840),
        },
      );
    } catch (_) {
      // Eski migration çalıştırılmamış olabilir; push akışı devam eder.
    }
  }

  /// 401/403 sonrası token'ı yeniler ve oda üyeliğini yeniden doğrular.
  @override
  Future<bool> refreshSessionAndMembership() async {
    final SupabaseClient? client = _client;
    final SyncConfig? config = _config;
    if (client == null || config == null) return false;
    try {
      await client.auth.refreshSession();
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      await client.rpc(
        joinRoomRpc,
        params: <String, dynamic>{
          'p_room_code': config.roomCode,
          'p_role': config.deviceRole,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kurtarma RPC'leri için istemci.
  Future<SupabaseClient?> _recoveryClient() async {
    final SupabaseClient? connected = _client;
    if (connected != null) return connected;
    final SyncConfig? config = _lastConfig;
    if (config == null) return null;
    try {
      final SupabaseClient client = await _ensureClient(config);
      final Session? session = client.auth.currentSession;
      if (session == null || session.isExpired) {
        await client.auth.signInAnonymously();
      }
      return client;
    } catch (_) {
      return null;
    }
  }

  /// Oda üyesi cihaz için yeni kurtarma kodu üretir.
  ///
  /// Düz metin kod yalnızca dönen sonuçta bulunur ve başka hiçbir yerde
  /// saklanmaz; sunucuda bcrypt özeti kalır.
  Future<RecoverySecretResult> issueRecoverySecret(String roomCode) async {
    final String code = roomCode.trim();
    if (code.isEmpty) {
      return const RecoverySecretResult(message: 'Oda kodu boş olamaz.');
    }
    final SupabaseClient? client = await _recoveryClient();
    if (client == null) {
      return const RecoverySecretResult(
        message: 'Önce Supabase bağlantısını kur ☁️',
      );
    }
    try {
      final Object? value = await client.rpc(
        issueRecoverySecretRpc,
        params: <String, dynamic>{'p_room_code': code},
      );
      final String secret = value?.toString().trim() ?? '';
      if (secret.isEmpty) {
        return const RecoverySecretResult(message: 'Kod üretilemedi.');
      }
      return RecoverySecretResult(
        secret: secret,
        message: 'Kurtarma kodu hazır.',
      );
    } on PostgrestException catch (error) {
      return RecoverySecretResult(
        message: _recoveryError(error, fallback: 'Kod üretilemedi.'),
      );
    } catch (_) {
      return const RecoverySecretResult(
        message: 'Kod üretilemedi · bağlantıyı kontrol et.',
      );
    }
  }

  /// Kurtarma koduyla rolü bu cihaza devreder.
  ///
  /// Sunucu `ok | invalid | locked` döner; `LR001` / `LR002` / `22023` hata
  /// kodları da anlamlı sonuca eşlenir (dialog kullanıcıya doğru mesajı
  /// gösterebilsin diye).
  Future<RoleReclaimResult> reclaimRole({
    required String roomCode,
    required String role,
    required String recoverySecret,
  }) async {
    final String code = roomCode.trim();
    final String cleanRole = role.trim().toLowerCase();
    final String secret = recoverySecret.trim();
    if (code.isEmpty || cleanRole.isEmpty) {
      return const RoleReclaimResult(
        RoleReclaimOutcome.invalidInput,
        message: 'Oda kodu ve rol gerekli.',
      );
    }
    if (secret.isEmpty) {
      return const RoleReclaimResult(RoleReclaimOutcome.invalidInput);
    }
    final SupabaseClient? client = await _recoveryClient();
    if (client == null) {
      return const RoleReclaimResult(
        RoleReclaimOutcome.failed,
        message: 'Önce Supabase bağlantısını kur ☁️',
      );
    }
    try {
      final Object? value = await client.rpc(
        reclaimRoleRpc,
        params: <String, dynamic>{
          'p_room_code': code,
          'p_role': cleanRole,
          'p_recovery_secret': secret,
        },
      );
      final String status = value?.toString().trim().toLowerCase() ?? '';
      final RoleReclaimOutcome outcome = switch (status) {
        'ok' => RoleReclaimOutcome.ok,
        'invalid' => RoleReclaimOutcome.invalid,
        'locked' => RoleReclaimOutcome.locked,
        _ => RoleReclaimOutcome.failed,
      };
      return RoleReclaimResult(outcome);
    } on PostgrestException catch (error) {
      final RoleReclaimOutcome outcome = switch (_errorCode(error)) {
        'LR001' => RoleReclaimOutcome.locked,
        'LR002' => RoleReclaimOutcome.notConfigured,
        '22023' => RoleReclaimOutcome.invalidInput,
        _ => RoleReclaimOutcome.failed,
      };
      return RoleReclaimResult(
        outcome,
        message: outcome == RoleReclaimOutcome.failed
            ? _recoveryError(error, fallback: 'Rol geri alınamadı.')
            : '',
      );
    } catch (_) {
      return const RoleReclaimResult(
        RoleReclaimOutcome.failed,
        message: 'Rol geri alınamadı · bağlantıyı kontrol et.',
      );
    }
  }

  static String _errorCode(PostgrestException error) =>
      error.code?.trim().toUpperCase() ?? '';

  static String _recoveryError(
    PostgrestException error, {
    required String fallback,
  }) {
    final String errCode = _errorCode(error);
    final String text = error.message.toLowerCase();
    if (errCode == '42501' || text.contains('not a room member')) {
      return 'Bu cihaz oda üyesi değil · önce bağlan.';
    }
    if (errCode == 'P0002' || text.contains('room not found')) {
      return 'Oda bulunamadı.';
    }
    if (errCode == 'LR001') {
      return 'Çok fazla hatalı deneme · 15 dakika sonra tekrar dene.';
    }
    if (errCode == 'LR002') {
      return 'Bu odada kurtarma kodu tanımlı değil.';
    }
    if (errCode == '22023') {
      return 'Kurtarma kodu boş olamaz.';
    }
    return fallback;
  }

  /// `room_code` değeri [expected] ile aynı mı? (büyük/küçük harf duyarsız)
  static bool _sameRoom(Object? raw, String expected) {
    final String room = raw?.toString().trim() ?? '';
    if (room.isEmpty) return false;
    return room.toUpperCase() == expected.trim().toUpperCase();
  }

  void _handleMessageChange(
    PostgresChangeEvent event,
    PostgresChangePayload payload,
  ) {
    final SyncConfig? config = _config;
    if (config == null) return;

    if (event == PostgresChangeEvent.delete) {
      final String id = payload.oldRecord['id']?.toString() ?? '';
      final String room = payload.oldRecord['room_code']?.toString() ?? '';
      // DELETE aboneliği filtresiz kuruldu: `room_code` döndüyse eşleşmeyen
      // olayı istemcide ele (RLS zaten yalnızca üye olunan odayı iletir).
      if (room.isNotEmpty && !_sameRoom(room, config.roomCode)) return;
      if (id.isEmpty) return;
      callbacks.onRemoteMessageDeleted(id);
      return;
    }

    final Map<String, dynamic> record = payload.newRecord;
    // Filtresiz fallback aboneliğinde de oda eşleşmesi doğrulanır.
    if (!_sameRoom(record['room_code'], config.roomCode)) return;
    // Kendi yazdığımız satır echo'su (self: true) yoksayılır.
    if (record['sender_id']?.toString() == config.deviceRole) return;
    final Object? raw = record['payload'];
    if (raw is! Map) return;
    try {
      final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
      if (record['read_at'] != null) json['is_read'] = true;
      final Object? reactions = record['reactions'];
      if (reactions is Map && reactions.isNotEmpty) {
        json['reactions'] = reactions;
      }
      final ChatMessage message = ChatMessage.fromJson(json);
      if (message.id.trim().isEmpty) return;
      if (event == PostgresChangeEvent.update) {
        callbacks.onRemoteMessageUpdate(message);
      } else {
        callbacks.onRemoteMessage(message);
      }
    } catch (_) {
      // Bozuk satır diğer mesajların akışını bozmaz.
    }
  }

  void _handleRoomPayload(PostgresChangePayload payload) {
    final SyncConfig? config = _config;
    if (config == null) return;
    final Map<String, dynamic> record = payload.newRecord;
    if (!_sameRoom(record['room_code'], config.roomCode)) return;
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
      callbacks.onRemoteState(
        GameState.fromJson(Map<String, dynamic>.from(raw)),
      );
    } catch (_) {
      // Şema sürümü uyuşmazsa yerel durum korunur.
    }
  }

  static String _friendly(Object error) {
    final String text = error.toString().toLowerCase();
    if (text.contains('invalid api key') ||
        text.contains('jwt') ||
        text.contains('unauthorized')) {
      return 'Anahtar geçersiz görünüyor.';
    }
    if (text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('network')) {
      return 'İnternet bağlantısı yok · yerel mod sürüyor.';
    }
    if (text.contains('relation') &&
        (text.contains('does not exist') || text.contains('bulunamadı'))) {
      return 'SQL şeması henüz kurulmamış. README’deki migration’ı çalıştır.';
    }
    if (text.contains('anonymous') || text.contains('anonymous_provider')) {
      return 'Supabase panelinde Anonymous sign-in kapalı görünüyor.';
    }
    if (text.contains('role') && text.contains('taken')) {
      return 'Bu rol başka bir cihazda zaten kullanılıyor.';
    }
    return 'Bağlantı kurulamadı · yerel mod sürüyor.';
  }
}
