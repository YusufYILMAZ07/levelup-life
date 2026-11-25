import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../domain/entities/entities.dart';
import 'pin_security.dart';
import 'secure_secrets_store.dart';

/// Cihaz düzeyindeki tercihler — oyun durumundan ayrı tutulur.
///
/// * bildirim anahtarları + günlük check-in saati + sessiz saat (DND)
/// * özel alan PIN kilidi (**yalnızca tuzlanmış SHA-256 hash** saklanır)
/// * biyometrik kilit ve arka plan toleransı (grace period)
/// * Supabase canlı senkronizasyon yapılandırması
/// * gerçek profil fotoğrafları (`partnerId → dosya yolu / data URL`)
///
/// v6: OneSignal REST API anahtarı istemciden **tamamen kaldırıldı**; push
/// gönderimi Supabase Edge Function üzerinden yapılır (anahtar sunucuda).
final class AppSettings {
  const AppSettings({
    this.messageNotifications = true,
    this.planReminders = true,
    this.dailyCheckinReminder = true,
    this.dailyCheckinHour = 21,
    this.dailyCheckinMinute = 30,
    this.doNotDisturbEnabled = false,
    this.quietStartMinutes = 23 * 60,
    this.quietEndMinutes = 7 * 60,
    this.pinLockEnabled = false,
    this.pinHash = '',
    this.pinSalt = '',
    this.pinAlgorithm = 'pbkdf2-sha256',
    this.pinIterations = 0,
    this.pinFailedAttempts = 0,
    this.pinLockedUntilMs = 0,
    this.biometricEnabled = false,
    this.lockGraceSeconds = defaultLockGraceSeconds,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.roomCode = '',
    this.deviceRole = CouplePartner.yusufId,
    this.lockToDeviceOwner = false,
    this.deviceOwnerConfigured = false,
    this.oneSignalAppId = '',
    this.avatarSources = const <String, String>{},
  });

  /// Yıldönümümüz (31 Ocak) — ilk açılışta hatırlatılan varsayılan PIN.
  ///
  /// Yalnızca **hash'siz** ilk kurulumda doğrulama için kullanılır; hiçbir
  /// zaman düz metin olarak diske yazılmaz.
  static const String defaultPin = '3101';

  /// `couple_rooms.room_code` için önerilen varsayılan oda.
  static const String defaultRoomCode = 'YUSUF-CEYDA-2026';

  /// Kamera/galeri/izin pencereleri için varsayılan tolerans (saniye).
  static const int defaultLockGraceSeconds = 30;

  /// Ayarlanabilir aralık: 0 (hemen kilitle) … 300 (5 dk).
  static const int minLockGraceSeconds = 0;
  static const int maxLockGraceSeconds = 300;

  final bool messageNotifications;
  final bool planReminders;
  final bool dailyCheckinReminder;

  /// Akşam puanı hatırlatıcısının saati (0..23).
  final int dailyCheckinHour;

  /// Akşam puanı hatırlatıcısının dakikası (0..59).
  final int dailyCheckinMinute;

  /// Sessiz saatler (Do Not Disturb) açık mı?
  final bool doNotDisturbEnabled;

  /// Sessiz aralık başlangıcı — gece yarısından itibaren dakika.
  final int quietStartMinutes;

  /// Sessiz aralık bitişi — gece yarısından itibaren dakika.
  final int quietEndMinutes;

  final bool pinLockEnabled;

  /// Tuzlanmış PIN özeti (hex). Boşsa varsayılan 3101 geçerlidir.
  final String pinHash;

  /// PIN tuzu (hex).
  final String pinSalt;

  /// Özet algoritması: `pbkdf2-sha256` (v6.1) veya `sha256` (v6 kayıtları).
  ///
  /// Alan yoksa eski kayıt kabul edilir ve başarılı girişten sonra PBKDF2'ye
  /// yükseltilir ([needsPinMigration]).
  final String pinAlgorithm;

  /// PBKDF2 tur sayısı (0 → üretim varsayılanı).
  final int pinIterations;

  /// Kalıcı hatalı deneme sayacı — uygulama yeniden açılınca sıfırlanmaz.
  final int pinFailedAttempts;

  /// Brute-force beklemesinin bitiş zamanı (epoch ms, 0 → bekleme yok).
  final int pinLockedUntilMs;

  /// Face ID / Touch ID / parmak izi ile kilit açma.
  final bool biometricEnabled;

  /// Uygulama arka plana geçtikten sonra kilidin devreye girmesi için geçen
  /// süre (saniye). Kamera/galeri gibi sistem pencereleri kilit açmaz.
  final int lockGraceSeconds;

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String roomCode;

  /// Bu telefonun sahibi: `yusuf` veya `ceyda`.
  final String deviceRole;

  /// `true` → aktif profil cihaz sahibine kilitlenir; yanlış isimle mesaj
  /// gönderilmesi veya puan girilmesi engellenir.
  final bool lockToDeviceOwner;

  /// Kullanıcı "Bu telefon kimin?" seçimini en az bir kez yaptı mı?
  final bool deviceOwnerConfigured;

  /// OneSignal uygulama kimliği (istemcide güvenli; push Edge Function'dan).
  final String oneSignalAppId;

  final Map<String, String> avatarSources;

  bool get isCloudConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty &&
      roomCode.trim().isNotEmpty;

  /// İstemci yalnızca App ID bilir; REST anahtarı sunucudadır.
  bool get isPushConfigured => oneSignalAppId.trim().isNotEmpty;

  /// Çift modu: oda kodu + bulut yapılandırması tamam mı?
  ///
  /// OneSignal `external_id`'si yalnızca bu modda `couple:<oda>:<rol>`
  /// biçiminde açılır; oda yoksa eski kimlik temizlenir.
  bool get partnerModeEnabled => isCloudConfigured;

  /// En az bir bildirim türü açık mı?
  bool get wantsNotifications =>
      messageNotifications || planReminders || dailyCheckinReminder;

  /// Teşhis/log satırları için maskeli oda kodu (tam kod asla loglanmaz).
  String get maskedRoomCode {
    final String code = normalizedRoomCode;
    if (code.isEmpty) return '';
    if (code.length <= 5) return '••••';
    return '${code.substring(0, 3)}•••${code.substring(code.length - 2)}';
  }

  /// Anon key yalnızca son 4 karakterle gösterilir.
  String get maskedAnonKey {
    final String key = supabaseAnonKey.trim();
    if (key.isEmpty) return '';
    if (key.length <= 8) return '••••';
    return '••••${key.substring(key.length - 4)}';
  }

  /// OneSignal App ID maskesi.
  String get maskedOneSignalAppId {
    final String id = oneSignalAppId.trim();
    if (id.isEmpty) return '';
    if (id.length <= 8) return '••••';
    return '${id.substring(0, 4)}••••';
  }

  /// Log'a yazılabilecek (sır içermeyen) özet.
  String get redactedSummary =>
      'AppSettings(pin: ${pinLockEnabled ? 'açık' : 'kapalı'}, '
      'cloud: ${isCloudConfigured ? maskedRoomCode : 'kapalı'}, '
      'push: ${isPushConfigured ? maskedOneSignalAppId : 'kapalı'})';

  /// PIN hash'i tanımlı mı? (ilk kurulumda varsayılan PIN kullanılır)
  bool get hasPin => pinHash.trim().isNotEmpty && pinSalt.trim().isNotEmpty;

  /// Kayıtlı kimliğin algoritması.
  PinAlgorithm get pinCredentialAlgorithm => PinAlgorithm.fromId(pinAlgorithm);

  /// v6 SHA-256 kaydı mı? Başarılı girişte PBKDF2'ye yükseltilir.
  bool get needsPinMigration =>
      hasPin && pinCredentialAlgorithm == PinAlgorithm.sha256Legacy;

  /// Saklanan kimlik (doğrulama için).
  PinCredential get pinCredential => PinCredential(
    hash: pinHash,
    salt: pinSalt,
    algorithm: pinCredentialAlgorithm,
    iterations: pinIterations <= 0
        ? PinSecurity.defaultIterations
        : pinIterations,
  );

  /// Brute-force beklemesi sürüyor mu? (uygulama kapanıp açılsa da geçerli)
  bool get isPinLockedOut =>
      pinLockedUntilMs > DateTime.now().millisecondsSinceEpoch;

  /// Beklemenin bitiş anı (yoksa `null`).
  DateTime? get pinLockedUntil => pinLockedUntilMs <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(pinLockedUntilMs);

  /// Bekleme bitene kadar kalan süre.
  Duration get pinLockoutRemaining {
    final DateTime? until = pinLockedUntil;
    if (until == null) return Duration.zero;
    final Duration remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String avatarOf(String partnerId) => avatarSources[partnerId] ?? '';

  bool get hasAnyAvatar =>
      avatarSources.values.any((String value) => value.trim().isNotEmpty);

  String get normalizedRoomCode => normalizeRoomCode(roomCode);

  /// `YUSUF-CEYDA-2026` → `YUSUF-CEYDA-2026` (boşluklar kırpılır, büyük harf).
  static String normalizeRoomCode(String raw) {
    final String cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '-');
    return cleaned.isEmpty ? '' : cleaned.toUpperCase();
  }

  static String normalizePin(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 4 ? digits.substring(0, 4) : digits;
  }

  /// Gece yarısını aşan aralıkları da doğru değerlendirir (23:00 → 07:00).
  bool isQuietAt(DateTime at) {
    if (!doNotDisturbEnabled) return false;
    final int minute = at.hour * 60 + at.minute;
    final int start = quietStartMinutes.clamp(0, 1439);
    final int end = quietEndMinutes.clamp(0, 1439);
    if (start == end) return false;
    if (start < end) return minute >= start && minute < end;
    return minute >= start || minute < end;
  }

  /// Sessiz aralık nedeniyle ertelenmesi gereken dakikayı aralık sonuna taşır.
  int shiftOutOfQuietHours(int minutes) {
    if (!doNotDisturbEnabled) return minutes;
    final int safe = minutes.clamp(0, 1439);
    final int start = quietStartMinutes.clamp(0, 1439);
    final int end = quietEndMinutes.clamp(0, 1439);
    if (start == end) return safe;
    final bool inside = start < end
        ? safe >= start && safe < end
        : safe >= start || safe < end;
    return inside ? end : safe;
  }

  /// "23:00 – 07:00" etiketi (ayarlar ekranı).
  String get quietHoursLabel =>
      '${timeLabelOfMinutes(quietStartMinutes)} – '
      '${timeLabelOfMinutes(quietEndMinutes)}';

  String get dailyCheckinLabel =>
      timeLabelOfMinutes(dailyCheckinHour * 60 + dailyCheckinMinute);

  static String timeLabelOfMinutes(int minutes) {
    final int safe = minutes.clamp(0, 1439);
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:'
        '${(safe % 60).toString().padLeft(2, '0')}';
  }

  AppSettings copyWith({
    bool? messageNotifications,
    bool? planReminders,
    bool? dailyCheckinReminder,
    int? dailyCheckinHour,
    int? dailyCheckinMinute,
    bool? doNotDisturbEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? pinLockEnabled,
    String? pinHash,
    String? pinSalt,
    String? pinAlgorithm,
    int? pinIterations,
    int? pinFailedAttempts,
    int? pinLockedUntilMs,
    bool? biometricEnabled,
    int? lockGraceSeconds,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? roomCode,
    String? deviceRole,
    bool? lockToDeviceOwner,
    bool? deviceOwnerConfigured,
    String? oneSignalAppId,
    Map<String, String>? avatarSources,
  }) => AppSettings(
    messageNotifications: messageNotifications ?? this.messageNotifications,
    planReminders: planReminders ?? this.planReminders,
    dailyCheckinReminder: dailyCheckinReminder ?? this.dailyCheckinReminder,
    dailyCheckinHour: dailyCheckinHour ?? this.dailyCheckinHour,
    dailyCheckinMinute: dailyCheckinMinute ?? this.dailyCheckinMinute,
    doNotDisturbEnabled: doNotDisturbEnabled ?? this.doNotDisturbEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
    pinAlgorithm: pinAlgorithm ?? this.pinAlgorithm,
    pinIterations: pinIterations ?? this.pinIterations,
    pinFailedAttempts: pinFailedAttempts ?? this.pinFailedAttempts,
    pinLockedUntilMs: pinLockedUntilMs ?? this.pinLockedUntilMs,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    lockGraceSeconds: lockGraceSeconds ?? this.lockGraceSeconds,
    supabaseUrl: supabaseUrl ?? this.supabaseUrl,
    supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    roomCode: roomCode ?? this.roomCode,
    deviceRole: deviceRole ?? this.deviceRole,
    lockToDeviceOwner: lockToDeviceOwner ?? this.lockToDeviceOwner,
    deviceOwnerConfigured: deviceOwnerConfigured ?? this.deviceOwnerConfigured,
    oneSignalAppId: oneSignalAppId ?? this.oneSignalAppId,
    avatarSources: avatarSources ?? this.avatarSources,
  );

  /// PIN'i tuzlayıp PBKDF2 ile türetir (düz metin hiçbir yerde kalmaz).
  ///
  /// Geçersiz PIN'de değişiklik yapılmaz (`this` döner).
  AppSettings withPin(
    String pin, {
    String? salt,
    PinAlgorithm algorithm = PinAlgorithm.pbkdf2Sha256,
    int? iterations,
  }) {
    if (!PinSecurity.isValidPin(pin)) return this;
    final PinCredential credential = PinCredential.create(
      pin,
      salt: salt,
      algorithm: algorithm,
      iterations: iterations,
    );
    return copyWith(
      pinHash: credential.hash,
      pinSalt: credential.salt,
      pinAlgorithm: credential.algorithm.id,
      pinIterations: credential.iterations,
      pinFailedAttempts: 0,
      pinLockedUntilMs: 0,
    );
  }

  /// [withPin]'in ana isolate'i bloklamayan sürümü (üretim UI'ı bunu kullanır).
  Future<AppSettings> withPinAsync(
    String pin, {
    String? salt,
    PinAlgorithm algorithm = PinAlgorithm.pbkdf2Sha256,
    int? iterations,
  }) async {
    if (!PinSecurity.isValidPin(pin)) return this;
    final PinCredential credential = await PinCredential.createAsync(
      pin,
      salt: salt,
      algorithm: algorithm,
      iterations: iterations,
    );
    return copyWith(
      pinHash: credential.hash,
      pinSalt: credential.salt,
      pinAlgorithm: credential.algorithm.id,
      pinIterations: credential.iterations,
      pinFailedAttempts: 0,
      pinLockedUntilMs: 0,
    );
  }

  /// Girilen PIN doğru mu? Hash tanımlı değilse varsayılan PIN kabul edilir.
  ///
  /// Giriş **katı** doğrulanır: `310199` gibi fazla haneli giriş artık kabul
  /// edilmez (eski sürüm ilk 4 haneyi alıyordu).
  bool verifyPin(String entered) {
    if (!hasPin) {
      return PinSecurity.normalize(entered) == defaultPin;
    }
    return pinCredential.matches(entered);
  }

  /// [verifyPin]'in ana isolate'i bloklamayan sürümü.
  Future<bool> verifyPinAsync(String entered) async {
    if (!hasPin) {
      return PinSecurity.normalize(entered) == defaultPin;
    }
    return pinCredential.matchesAsync(entered);
  }

  AppSettings withAvatar(String partnerId, String source) => copyWith(
    avatarSources: <String, String>{...avatarSources, partnerId: source.trim()},
  );

  AppSettings withoutAvatar(String partnerId) => copyWith(
    avatarSources: <String, String>{
      for (final MapEntry<String, String> entry in avatarSources.entries)
        if (entry.key != partnerId) entry.key: entry.value,
    },
  );

  /// JSON'a yazar.
  ///
  /// [includeSecrets] `false` iken PIN hash/tuz **dahil edilmez**; bunlar
  /// `flutter_secure_storage` içinde ayrıca saklanır.
  Map<String, dynamic> toJson({bool includeSecrets = true}) =>
      <String, dynamic>{
        'message_notifications': messageNotifications,
        'plan_reminders': planReminders,
        'daily_checkin_reminder': dailyCheckinReminder,
        'daily_checkin_hour': dailyCheckinHour,
        'daily_checkin_minute': dailyCheckinMinute,
        'do_not_disturb_enabled': doNotDisturbEnabled,
        'quiet_start_minutes': quietStartMinutes,
        'quiet_end_minutes': quietEndMinutes,
        'pin_lock_enabled': pinLockEnabled,
        'pin_failed_attempts': pinFailedAttempts,
        'pin_locked_until_ms': pinLockedUntilMs,
        // Algoritma/tur sayısı **sır değildir**; güvenli depo okunamazsa
        // kullanıcının kilitli kalmaması için prefs'te de tutulur.
        'pin_algorithm': pinAlgorithm,
        'pin_iterations': pinIterations,
        if (includeSecrets) ...<String, dynamic>{
          'pin_hash': pinHash,
          'pin_salt': pinSalt,
        },
        'biometric_enabled': biometricEnabled,
        'lock_grace_seconds': lockGraceSeconds,
        'supabase_url': supabaseUrl,
        'supabase_anon_key': supabaseAnonKey,
        'room_code': roomCode,
        'device_role': deviceRole,
        'lock_to_device_owner': lockToDeviceOwner,
        'device_owner_configured': deviceOwnerConfigured,
        'onesignal_app_id': oneSignalAppId,
        'avatar_sources': avatarSources,
      };

  /// Yalnızca güvenli depoya yazılacak alanlar.
  Map<String, String> sensitiveValues() => <String, String>{
    if (pinHash.trim().isNotEmpty) 'pin_hash': pinHash,
    if (pinSalt.trim().isNotEmpty) 'pin_salt': pinSalt,
    if (pinHash.trim().isNotEmpty) 'pin_algorithm': pinAlgorithm,
    if (pinHash.trim().isNotEmpty) 'pin_iterations': '$pinIterations',
  };

  /// Bulut/push kimliği — SharedPreferences'a ek olarak güvenli depoya da
  /// yazılır (write-through). Cihaz kaybolursa oda kodu okunamaz.
  Map<String, String> cloudSecrets() => <String, String>{
    if (supabaseAnonKey.trim().isNotEmpty) 'supabase_anon_key': supabaseAnonKey,
    if (roomCode.trim().isNotEmpty) 'room_code': roomCode,
    if (oneSignalAppId.trim().isNotEmpty) 'oneSignal_app_id': oneSignalAppId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final Map<String, String> avatars = <String, String>{};
    final Object? rawAvatars = json['avatar_sources'];
    if (rawAvatars is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawAvatars.entries) {
        final String key = entry.key.toString();
        final String value = entry.value == null ? '' : entry.value.toString();
        if (key.isNotEmpty && value.isNotEmpty) avatars[key] = value;
      }
    }

    String hash = json['pin_hash']?.toString().trim() ?? '';
    String salt = json['pin_salt']?.toString().trim() ?? '';
    String algorithm = json['pin_algorithm']?.toString().trim() ?? '';
    int iterations = _asInt(json['pin_iterations'], 0);
    final String legacyPin = AppSettings.normalizePin(
      json['pin_code']?.toString() ?? '',
    );
    if ((hash.isEmpty || salt.isEmpty) && legacyPin.length == 4) {
      // v5 düz metin PIN'i ilk açılışta hash'e taşınır; düz metin atılır.
      // Yükleme yolunu yavaşlatmamak için SHA-256 kullanılır; doğru girişten
      // sonra PBKDF2'ye yükseltilir (needsPinMigration).
      final PinCredential migrated = PinCredential.create(
        legacyPin,
        algorithm: PinAlgorithm.sha256Legacy,
      );
      hash = migrated.hash;
      salt = migrated.salt;
      algorithm = migrated.algorithm.id;
      iterations = 0;
    } else if (hash.isNotEmpty && salt.isNotEmpty && algorithm.isEmpty) {
      // Alan yok → v6 SHA-256 kaydı.
      algorithm = PinAlgorithm.sha256Legacy.id;
    }
    final int failedAttempts = _asInt(
      json['pin_failed_attempts'],
      0,
    ).clamp(0, 1000);
    final int lockedUntilMs = _asInt(json['pin_locked_until_ms'], 0);

    final int grace = _asInt(
      json['lock_grace_seconds'],
      defaultLockGraceSeconds,
    ).clamp(minLockGraceSeconds, maxLockGraceSeconds);
    final String role = json['device_role']?.toString() == CouplePartner.ceydaId
        ? CouplePartner.ceydaId
        : CouplePartner.yusufId;

    return AppSettings(
      messageNotifications: _asBool(json['message_notifications'], true),
      planReminders: _asBool(json['plan_reminders'], true),
      dailyCheckinReminder: _asBool(json['daily_checkin_reminder'], true),
      dailyCheckinHour: _asInt(json['daily_checkin_hour'], 21).clamp(0, 23),
      dailyCheckinMinute: _asInt(json['daily_checkin_minute'], 30).clamp(0, 59),
      doNotDisturbEnabled: _asBool(json['do_not_disturb_enabled'], false),
      quietStartMinutes: _asInt(
        json['quiet_start_minutes'],
        23 * 60,
      ).clamp(0, 1439),
      quietEndMinutes: _asInt(json['quiet_end_minutes'], 7 * 60).clamp(0, 1439),
      pinLockEnabled: _asBool(json['pin_lock_enabled'], false),
      pinHash: hash,
      pinSalt: salt,
      pinAlgorithm: algorithm.isEmpty
          ? PinAlgorithm.pbkdf2Sha256.id
          : algorithm,
      pinIterations: iterations <= 0 ? 0 : iterations,
      pinFailedAttempts: failedAttempts,
      pinLockedUntilMs: lockedUntilMs <= 0 ? 0 : lockedUntilMs,
      biometricEnabled: _asBool(json['biometric_enabled'], false),
      lockGraceSeconds: grace,
      supabaseUrl: json['supabase_url']?.toString() ?? '',
      supabaseAnonKey: json['supabase_anon_key']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      deviceRole: role,
      lockToDeviceOwner: _asBool(json['lock_to_device_owner'], false),
      deviceOwnerConfigured: _asBool(json['device_owner_configured'], false),
      oneSignalAppId: json['onesignal_app_id']?.toString() ?? '',
      avatarSources: avatars,
    );
  }

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Ayarların kalıcılık sözleşmesi (testlerde [MemoryAppSettingsStore]).
abstract interface class AppSettingsStore {
  AppSettings load();

  /// Yazım hataları **yutulmaz**; çağıran kullanıcıya bildirir.
  Future<void> save(AppSettings settings);

  /// Son güvenli depo / yazım sorunu (yoksa `null`).
  String? get lastError;
}

final class MemoryAppSettingsStore implements AppSettingsStore {
  MemoryAppSettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  String? lastError;

  @override
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

/// `shared_preferences` + `flutter_secure_storage` birleşimi.
///
/// PIN hash/tuz/algorithm/iterations **asla** SharedPreferences'a yazılmaz;
/// `.toJson()` çağrısı güvenli alanları dışarıda bırakır ve
/// [SecureSecretsStore]'a ayrıca yazar.
final class LocalAppSettingsStore implements AppSettingsStore {
  LocalAppSettingsStore._(this._preferences, this._secrets);

  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';
  static const String _pinAlgorithmKey = 'pin_algorithm';
  static const String _pinIterationsKey = 'pin_iterations';
  static const String _anonKeyKey = 'supabase_anon_key';
  static const String _roomKey = 'room_code';
  static const String _appIdKey = 'oneSignal_app_id';

  final SharedPreferences _preferences;
  final SecureSecretsStore _secrets;

  String? _lastError;

  @override
  String? get lastError => _lastError;

  static Future<LocalAppSettingsStore> open({
    SecureSecretsStore? secrets,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SecureSecretsStore secure =
        secrets ?? await LocalSecureSecretsStore.open();
    return LocalAppSettingsStore._(preferences, secure);
  }

  @override
  AppSettings load() {
    final String? raw = _preferences.getString(AppConstants.cacheAppSettings);
    Map<String, dynamic> json = const <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          json = <String, dynamic>{
            for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
              entry.key.toString(): entry.value,
          };
        }
      } catch (_) {
        // Bozuk ayar kaydı uygulamayı çökertmez; güvenli varsayılanlar döner.
        json = const <String, dynamic>{};
      }
    }
    final String? hash = _secrets.read(_pinHashKey);
    final String? salt = _secrets.read(_pinSaltKey);
    if (hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty) {
      final String? secureAlgorithm = _secrets.read(_pinAlgorithmKey);
      final String? secureIterations = _secrets.read(_pinIterationsKey);
      json = <String, dynamic>{
        ...json,
        'pin_hash': hash,
        'pin_salt': salt,
        // Güvenli depo değeri varsa o kazanır; yoksa prefs'teki metadata
        // (algoritma/tur) kullanılır — aksi hâlde PBKDF2 kaydı yanlışlıkla
        // SHA-256 sayılıp kullanıcı kilitli kalabilirdi.
        if (secureAlgorithm != null && secureAlgorithm.isNotEmpty)
          'pin_algorithm': secureAlgorithm,
        if (secureIterations != null && secureIterations.isNotEmpty)
          'pin_iterations': secureIterations,
      };
    } else if (!_secrets.isOperational &&
        AppSettings._asBool(json['pin_lock_enabled'], false)) {
      // v6.1: Keystore/Keychain açılamadığında **varsayılan 3101'e düşmüyoruz**
      // (bu, kilidi sessizce etkisiz kılardı). Kilit bu oturum için kapanır ve
      // kullanıcı uyarılır; hash kaybolmuş gibi davranıp yanlış PIN kabul
      // edilmez.
      _lastError =
          'Güvenli depo (Keychain/Keystore) açılamadı · PIN kilidi bu '
          'oturumda devre dışı. Ayarlar → Gizlilik’ten yeniden aç.';
      json = <String, dynamic>{
        ...json,
        'pin_lock_enabled': false,
        'pin_failed_attempts': 0,
        'pin_locked_until_ms': 0,
      };
    }
    final String? secureAnonKey = _secrets.read(_anonKeyKey);
    if (secureAnonKey != null &&
        secureAnonKey.isNotEmpty &&
        (json['supabase_anon_key']?.toString().trim().isEmpty ?? true)) {
      json = <String, dynamic>{...json, 'supabase_anon_key': secureAnonKey};
    }
    final String? secureRoom = _secrets.read(_roomKey);
    if (secureRoom != null &&
        secureRoom.isNotEmpty &&
        (json['room_code']?.toString().trim().isEmpty ?? true)) {
      json = <String, dynamic>{...json, 'room_code': secureRoom};
    }
    final String? secureAppId = _secrets.read(_appIdKey);
    if (secureAppId != null &&
        secureAppId.isNotEmpty &&
        (json['onesignal_app_id']?.toString().trim().isEmpty ?? true)) {
      json = <String, dynamic>{...json, 'onesignal_app_id': secureAppId};
    }
    return json.isEmpty ? const AppSettings() : AppSettings.fromJson(json);
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(
      AppConstants.cacheAppSettings,
      jsonEncode(settings.toJson(includeSecrets: false)),
    );
    // Güvenli depo yazımı seri kuyrukta; hata yutulmaz.
    await _secrets.write(_pinHashKey, settings.pinHash);
    await _secrets.write(_pinSaltKey, settings.pinSalt);
    if (settings.hasPin) {
      await _secrets.write(_pinAlgorithmKey, settings.pinAlgorithm);
      await _secrets.write(_pinIterationsKey, '${settings.pinIterations}');
    } else {
      await _secrets.delete(_pinAlgorithmKey);
      await _secrets.delete(_pinIterationsKey);
    }
    // Bulut/push kimliği de güvenli depoya yazılır (write-through). Bu üç alan
    // zaten SharedPreferences'ta olduğu için yazma hatası ayar kaydını bozmaz.
    try {
      await _secrets.write(_anonKeyKey, settings.supabaseAnonKey);
      await _secrets.write(_roomKey, settings.roomCode);
      await _secrets.write(_appIdKey, settings.oneSignalAppId);
    } on SecureSecretsException {
      // Güvenli depo yoksa prefs kaydı yeterlidir.
    }
  }
}

/// Ayar mutasyonları — her değişiklik anında diske yazılır.
///
/// v6.1: yazımlar **seri kuyrukta** çalışır (hızlı art arda dokunuşlarda
/// dosya/Keychain yarışmaz) ve son hata [lastSaveError] ile raporlanır.
final class AppSettingsController extends Notifier<AppSettings> {
  Future<void> _saveChain = Future<void>.value();

  /// Son kalıcılık hatası (ayarlar ekranı gösterebilir).
  String? lastSaveError;

  @override
  AppSettings build() => ref.watch(appSettingsStoreProvider).load();

  void _update(AppSettings next) {
    if (identical(next, state)) return;
    state = next;
    _enqueueSave(next);
  }

  void _enqueueSave(AppSettings next) {
    _saveChain = _saveChain.then((_) async {
      try {
        await ref.read(appSettingsStoreProvider).save(next);
        lastSaveError = null;
      } catch (error) {
        // Ayar yazımı başarısız olsa da oturum devam eder; kullanıcı bilir.
        lastSaveError = 'Ayarlar kaydedilemedi: $error';
        debugPrint('[AppSettings] $lastSaveError');
      }
    });
  }

  /// Bekleyen yazımı bekler (test / uygulama kapanışı).
  Future<void> flush() => _saveChain;

  void setMessageNotifications(bool enabled) =>
      _update(state.copyWith(messageNotifications: enabled));

  void setPlanReminders(bool enabled) =>
      _update(state.copyWith(planReminders: enabled));

  void setDailyCheckinReminder(bool enabled) =>
      _update(state.copyWith(dailyCheckinReminder: enabled));

  /// Akşam check-in saatini ayarlar (0..23 / 0..59).
  bool setDailyCheckinTime({required int hour, required int minute}) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
    _update(state.copyWith(dailyCheckinHour: hour, dailyCheckinMinute: minute));
    return true;
  }

  /// Sessiz saatleri (DND) açar/kapatır ve aralığı günceller.
  void setDoNotDisturb({
    required bool enabled,
    int? startMinutes,
    int? endMinutes,
  }) {
    _update(
      state.copyWith(
        doNotDisturbEnabled: enabled,
        quietStartMinutes: startMinutes?.clamp(0, 1439),
        quietEndMinutes: endMinutes?.clamp(0, 1439),
      ),
    );
  }

  /// Kilidi açarken hash yoksa **varsayılan 3101** hemen hash'lenir.
  ///
  /// Böylece ekranda "PIN yok ama kilit açık" gibi tutarsız bir durum kalmaz ve
  /// varsayılan PIN yalnızca kullanıcı bilerek etkinleştirdiğinde geçerli olur.
  void setPinLockEnabled(bool enabled) {
    AppSettings next = state.copyWith(pinLockEnabled: enabled);
    if (enabled && !next.hasPin && next.pinHash.trim().isEmpty) {
      next = next.withPin(AppSettings.defaultPin);
    }
    if (!enabled) {
      next = next.copyWith(pinFailedAttempts: 0, pinLockedUntilMs: 0);
    }
    _update(next);
  }

  /// 4 haneli PIN; geçersiz giriş yoksayılır. Yalnızca PBKDF2 özeti saklanır.
  bool setPinCode(String raw) {
    final String pin = PinSecurity.normalize(raw);
    if (pin.isEmpty) return false;
    _update(state.withPin(pin));
    return true;
  }

  /// [setPinCode]'un ana isolate'i bloklamayan sürümü (üretim UI'ı).
  Future<bool> setPinCodeAsync(String raw) async {
    final String pin = PinSecurity.normalize(raw);
    if (pin.isEmpty) return false;
    final AppSettings next = await state.withPinAsync(pin);
    _update(next);
    return true;
  }

  /// v6 SHA-256 kaydını başarılı girişten sonra PBKDF2'ye yükseltir.
  Future<void> migratePinAsync(String raw) async {
    if (!state.needsPinMigration) return;
    final String pin = PinSecurity.normalize(raw);
    if (pin.isEmpty) return;
    final AppSettings next = await state.withPinAsync(pin, salt: state.pinSalt);
    _update(next);
  }

  /// Hatalı deneme sayacını kalıcı hale getirir (brute-force koruması).
  void recordPinFailure({
    required int attempts,
    required DateTime? lockedUntil,
  }) => _update(
    state.copyWith(
      pinFailedAttempts: attempts.clamp(0, 1000),
      pinLockedUntilMs: lockedUntil?.millisecondsSinceEpoch ?? 0,
    ),
  );

  /// Başarılı giriş / kilit kapatma sonrası sayaç sıfırlanır.
  void clearPinFailures() {
    if (state.pinFailedAttempts == 0 && state.pinLockedUntilMs == 0) return;
    _update(state.copyWith(pinFailedAttempts: 0, pinLockedUntilMs: 0));
  }

  void setBiometricEnabled(bool enabled) =>
      _update(state.copyWith(biometricEnabled: enabled));

  /// 0..300 saniye arası tolerans.
  bool setLockGraceSeconds(int seconds) {
    if (seconds < AppSettings.minLockGraceSeconds ||
        seconds > AppSettings.maxLockGraceSeconds) {
      return false;
    }
    _update(state.copyWith(lockGraceSeconds: seconds));
    return true;
  }

  void setAvatar(String partnerId, String source) =>
      _update(state.withAvatar(partnerId, source));

  void clearAvatar(String partnerId) => _update(state.withoutAvatar(partnerId));

  void setDeviceRole(String partnerId) {
    if (!CouplePartner.isValid(partnerId)) return;
    _update(state.copyWith(deviceRole: partnerId));
  }

  /// "📱 Bu Telefon Kimin?" seçimi: sahibi belirler, kimliği kilitler ve
  /// ilk kurulum isteminin bir daha gösterilmemesini işaretler.
  void configureDeviceOwner(String partnerId) {
    if (!CouplePartner.isValid(partnerId)) return;
    _update(
      state.copyWith(
        deviceRole: partnerId,
        lockToDeviceOwner: true,
        deviceOwnerConfigured: true,
      ),
    );
  }

  void setLockToDeviceOwner(bool enabled) => _update(
    state.copyWith(lockToDeviceOwner: enabled, deviceOwnerConfigured: true),
  );

  void markDeviceOwnerConfigured() =>
      _update(state.copyWith(deviceOwnerConfigured: true));

  /// Push için istemci yalnızca App ID kaydeder; REST anahtarı sunucudadır.
  void savePushConfig({required String appId}) =>
      _update(state.copyWith(oneSignalAppId: appId.trim()));

  void clearPushConfig() => _update(state.copyWith(oneSignalAppId: ''));

  void saveCloudConfig({
    required String url,
    required String anonKey,
    required String roomCode,
    required String deviceRole,
  }) {
    _update(
      state.copyWith(
        supabaseUrl: url.trim(),
        supabaseAnonKey: anonKey.trim(),
        roomCode: AppSettings.normalizeRoomCode(roomCode),
        deviceRole: CouplePartner.isValid(deviceRole)
            ? deviceRole
            : state.deviceRole,
      ),
    );
  }

  void clearCloudConfig() => _update(
    state.copyWith(supabaseUrl: '', supabaseAnonKey: '', roomCode: ''),
  );
}

final Provider<AppSettingsStore> appSettingsStoreProvider =
    Provider<AppSettingsStore>((Ref ref) => MemoryAppSettingsStore());

final NotifierProvider<AppSettingsController, AppSettings> appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Belirli partnerin gerçek fotoğrafı (yoksa boş metin).
final partnerAvatarProvider = Provider.family<String, String>(
  (Ref ref, String partnerId) =>
      ref.watch(appSettingsProvider).avatarOf(partnerId),
);
