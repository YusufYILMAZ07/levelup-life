import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../domain/entities/entities.dart';

/// Cihaz düzeyindeki tercihler — oyun durumundan ayrı tutulur.
///
/// * bildirim anahtarları (mesaj / plan / akşam puanı)
/// * özel alan PIN kilidi
/// * Supabase canlı senkronizasyon yapılandırması
/// * gerçek profil fotoğrafları (`partnerId → dosya yolu / data URL`)
final class AppSettings {
  const AppSettings({
    this.messageNotifications = true,
    this.planReminders = true,
    this.dailyCheckinReminder = true,
    this.pinLockEnabled = false,
    this.pinCode = defaultPin,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.roomCode = '',
    this.deviceRole = CouplePartner.yusufId,
    this.avatarSources = const <String, String>{},
  });

  /// Ceyda'nın doğum günü — ilk açılışta hatırlatılan varsayılan PIN.
  static const String defaultPin = '1402';

  /// `couple_rooms.room_code` için önerilen varsayılan oda.
  static const String defaultRoomCode = 'YUSUF-CEYDA-2026';

  final bool messageNotifications;
  final bool planReminders;
  final bool dailyCheckinReminder;
  final bool pinLockEnabled;
  final String pinCode;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String roomCode;

  /// Bu telefonun sahibi: `yusuf` veya `ceyda`.
  final String deviceRole;

  final Map<String, String> avatarSources;

  bool get isCloudConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty &&
      roomCode.trim().isNotEmpty;

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

  AppSettings copyWith({
    bool? messageNotifications,
    bool? planReminders,
    bool? dailyCheckinReminder,
    bool? pinLockEnabled,
    String? pinCode,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? roomCode,
    String? deviceRole,
    Map<String, String>? avatarSources,
  }) => AppSettings(
    messageNotifications: messageNotifications ?? this.messageNotifications,
    planReminders: planReminders ?? this.planReminders,
    dailyCheckinReminder: dailyCheckinReminder ?? this.dailyCheckinReminder,
    pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
    pinCode: pinCode ?? this.pinCode,
    supabaseUrl: supabaseUrl ?? this.supabaseUrl,
    supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    roomCode: roomCode ?? this.roomCode,
    deviceRole: deviceRole ?? this.deviceRole,
    avatarSources: avatarSources ?? this.avatarSources,
  );

  AppSettings withAvatar(String partnerId, String source) => copyWith(
    avatarSources: <String, String>{...avatarSources, partnerId: source.trim()},
  );

  AppSettings withoutAvatar(String partnerId) => copyWith(
    avatarSources: <String, String>{
      for (final MapEntry<String, String> entry in avatarSources.entries)
        if (entry.key != partnerId) entry.key: entry.value,
    },
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message_notifications': messageNotifications,
    'plan_reminders': planReminders,
    'daily_checkin_reminder': dailyCheckinReminder,
    'pin_lock_enabled': pinLockEnabled,
    'pin_code': pinCode,
    'supabase_url': supabaseUrl,
    'supabase_anon_key': supabaseAnonKey,
    'room_code': roomCode,
    'device_role': deviceRole,
    'avatar_sources': avatarSources,
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
    final String rawPin = json['pin_code'] == null
        ? defaultPin
        : json['pin_code'].toString();
    final String pin = normalizePin(rawPin);
    return AppSettings(
      messageNotifications: _asBool(json['message_notifications'], true),
      planReminders: _asBool(json['plan_reminders'], true),
      dailyCheckinReminder: _asBool(json['daily_checkin_reminder'], true),
      pinLockEnabled: _asBool(json['pin_lock_enabled'], false),
      pinCode: pin.length == 4 ? pin : defaultPin,
      supabaseUrl: json['supabase_url']?.toString() ?? '',
      supabaseAnonKey: json['supabase_anon_key']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      deviceRole: json['device_role']?.toString() == CouplePartner.ceydaId
          ? CouplePartner.ceydaId
          : CouplePartner.yusufId,
      avatarSources: avatars,
    );
  }

  /// PIN doğrulaması — kilit ekranı ve ayarlar aynı kuralı kullanır.
  static bool matchesPin(String entered, String expected) =>
      normalizePin(entered).length == 4 &&
      normalizePin(entered) == normalizePin(expected);

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
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

final class LocalAppSettingsStore implements AppSettingsStore {
  LocalAppSettingsStore._(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalAppSettingsStore> open() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return LocalAppSettingsStore._(preferences);
  }

  @override
  AppSettings load() {
    final String? raw = _preferences.getString(AppConstants.cacheAppSettings);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppSettings.fromJson(<String, dynamic>{
          for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
            entry.key.toString(): entry.value,
        });
      }
    } catch (_) {
      // Bozuk ayar kaydı uygulamayı çökertmez.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(
      AppConstants.cacheAppSettings,
      jsonEncode(settings.toJson()),
    );
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

  void setPinLockEnabled(bool enabled) =>
      _update(state.copyWith(pinLockEnabled: enabled));

  /// 4 haneli PIN; geçersiz giriş yoksayılır.
  bool setPinCode(String raw) {
    final String pin = AppSettings.normalizePin(raw);
    if (pin.length != 4) return false;
    _update(state.copyWith(pinCode: pin));
    return true;
  }

  void setAvatar(String partnerId, String source) =>
      _update(state.withAvatar(partnerId, source));

  void clearAvatar(String partnerId) => _update(state.withoutAvatar(partnerId));

  void setDeviceRole(String partnerId) {
    if (!CouplePartner.isValid(partnerId)) return;
    _update(state.copyWith(deviceRole: partnerId));
  }

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
