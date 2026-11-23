import 'dart:async';
import 'dart:convert';

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

  /// En az bir bildirim türü açık mı?
  bool get wantsNotifications =>
      messageNotifications || planReminders || dailyCheckinReminder;

  /// PIN hash'i tanımlı mı? (ilk kurulumda varsayılan PIN kullanılır)
  bool get hasPin => pinHash.trim().isNotEmpty && pinSalt.trim().isNotEmpty;

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
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    lockGraceSeconds: lockGraceSeconds ?? this.lockGraceSeconds,
    supabaseUrl: supabaseUrl ?? this.supabaseUrl,
    supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    roomCode: roomCode ?? this.roomCode,
    deviceRole: deviceRole ?? this.deviceRole,
    lockToDeviceOwner: lockToDeviceOwner ?? this.lockToDeviceOwner,
    deviceOwnerConfigured:
        deviceOwnerConfigured ?? this.deviceOwnerConfigured,
    oneSignalAppId: oneSignalAppId ?? this.oneSignalAppId,
    avatarSources: avatarSources ?? this.avatarSources,
  );

  /// PIN'i tuzlayıp hash'ler (düz metin hiçbir yerde kalmaz).
  AppSettings withPin(String pin, {String? salt}) {
    final PinCredential credential = PinCredential.create(pin, salt: salt);
    return copyWith(pinHash: credential.hash, pinSalt: credential.salt);
  }

  /// Girilen PIN doğru mu? Hash tanımlı değilse varsayılan PIN kabul edilir.
  bool verifyPin(String entered) {
    if (!hasPin) {
      return normalizePin(entered).length == 4 &&
          normalizePin(entered) == defaultPin;
    }
    return PinCredential(hash: pinHash, salt: pinSalt).matches(entered);
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
  Map<String, dynamic> toJson({bool includeSecrets = true}) => <String, dynamic>{
    'message_notifications': messageNotifications,
    'plan_reminders': planReminders,
    'daily_checkin_reminder': dailyCheckinReminder,
    'daily_checkin_hour': dailyCheckinHour,
    'daily_checkin_minute': dailyCheckinMinute,
    'do_not_disturb_enabled': doNotDisturbEnabled,
    'quiet_start_minutes': quietStartMinutes,
    'quiet_end_minutes': quietEndMinutes,
    'pin_lock_enabled': pinLockEnabled,
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
    final String legacyPin = AppSettings.normalizePin(
      json['pin_code']?.toString() ?? '',
    );
    if ((hash.isEmpty || salt.isEmpty) && legacyPin.length == 4) {
      // v5 düz metin PIN'i ilk açılışta hash'e taşınır; düz metin atılır.
      final PinCredential migrated = PinCredential.create(legacyPin);
      hash = migrated.hash;
      salt = migrated.salt;
    }

    final int grace = _asInt(
      json['lock_grace_seconds'],
      defaultLockGraceSeconds,
    ).clamp(minLockGraceSeconds, maxLockGraceSeconds);
    final String role =
        json['device_role']?.toString() == CouplePartner.ceydaId
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
      biometricEnabled: _asBool(json['biometric_enabled'], false),
      lockGraceSeconds: grace,
      supabaseUrl: json['supabase_url']?.toString() ?? '',
      supabaseAnonKey: json['supabase_anon_key']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      deviceRole: role,
      lockToDeviceOwner: _asBool(json['lock_to_device_owner'], false),
      deviceOwnerConfigured: _asBool(
        json['device_owner_configured'],
        false,
      ),
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

  Future<void> save(AppSettings settings);
}

final class MemoryAppSettingsStore implements AppSettingsStore {
  MemoryAppSettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

/// `shared_preferences` + `flutter_secure_storage` birleşimi.
///
/// PIN hash/tuz **asla** SharedPreferences'a yazılmaz; `.toJson()` çağrısı
/// güvenli alanları dışarıda bırakır ve [SecureSecretsStore]'a ayrıca yazar.
final class LocalAppSettingsStore implements AppSettingsStore {
  LocalAppSettingsStore._(this._preferences, this._secrets);

  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';

  final SharedPreferences _preferences;
  final SecureSecretsStore _secrets;

  static Future<LocalAppSettingsStore> open({SecureSecretsStore? secrets}) async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
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
      json = <String, dynamic>{...json, 'pin_hash': hash, 'pin_salt': salt};
    }
    return json.isEmpty ? const AppSettings() : AppSettings.fromJson(json);
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(
      AppConstants.cacheAppSettings,
      jsonEncode(settings.toJson(includeSecrets: false)),
    );
    await _secrets.write(_pinHashKey, settings.pinHash);
    await _secrets.write(_pinSaltKey, settings.pinSalt);
  }
}

/// Ayar mutasyonları — her değişiklik anında diske yazılır.
final class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(appSettingsStoreProvider).load();

  void _update(AppSettings next) {
    state = next;
    unawaited(_saveQuietly(next));
  }

  Future<void> _saveQuietly(AppSettings next) async {
    try {
      await ref.read(appSettingsStoreProvider).save(next);
    } catch (_) {
      // Ayar yazımı başarısız olsa da oturum devam eder.
    }
  }

  void setMessageNotifications(bool enabled) =>
      _update(state.copyWith(messageNotifications: enabled));

  void setPlanReminders(bool enabled) =>
      _update(state.copyWith(planReminders: enabled));

  void setDailyCheckinReminder(bool enabled) =>
      _update(state.copyWith(dailyCheckinReminder: enabled));

  /// Akşam check-in saatini ayarlar (0..23 / 0..59).
  bool setDailyCheckinTime({required int hour, required int minute}) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
    _update(
      state.copyWith(dailyCheckinHour: hour, dailyCheckinMinute: minute),
    );
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

  void setPinLockEnabled(bool enabled) =>
      _update(state.copyWith(pinLockEnabled: enabled));

  /// 4 haneli PIN; geçersiz giriş yoksayılır. Yalnızca hash saklanır.
  bool setPinCode(String raw) {
    final String pin = AppSettings.normalizePin(raw);
    if (pin.length != 4) return false;
    _update(state.withPin(pin));
    return true;
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
