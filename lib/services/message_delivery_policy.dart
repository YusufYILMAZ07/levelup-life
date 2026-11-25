import 'app_settings.dart';

/// Mesaj / dürtme bildirimlerinin **saf** karar katmanı.
///
/// Bu sınıf platform, ağ veya Riverpod'a dokunmaz. Böylece "gönderenin
/// sessiz saati partnerin push'unu engellememeli" ve "sohbet açıkken gelen
/// mesaj için ikinci sistem bildirimi gösterilmemeli" kuralları birim testiyle
/// doğrulanabilir.
abstract final class MessageDeliveryPolicy {
  /// Karşı taraftan gelen mesaj için yerel OS bildirimi / üst banner
  /// gösterilmeli mi?
  ///
  /// * Alıcının kendi bildirim ayarı kapalıysa gösterilmez.
  /// * Alıcı sessiz saatteyse gösterilmez.
  /// * Sohbet sekmesi ön planda açıksa kullanıcı mesajı zaten görüyor;
  ///   gereksiz sistem bildirimi ve banner gösterilmez.
  static bool shouldShowIncomingLocal({
    required AppSettings settings,
    required DateTime now,
    required bool chatVisible,
    required bool appResumed,
  }) {
    if (!settings.messageNotifications) return false;
    if (settings.isQuietAt(now)) return false;
    if (chatVisible && appResumed) return false;
    return true;
  }

  /// Kullanıcının kendi gönderdiği mesaj/dürtme partnerin cihazına push
  /// edilmeli mi?
  ///
  /// **Gönderenin** bildirim tercihi veya sessiz saati bu kararı **etkilemez**.
  /// Push yalnızca yapılandırma ve alıcı tarafındaki kurallarla sınırlanır.
  static bool shouldPushOutgoing({required AppSettings settings}) =>
      settings.isPushConfigured && settings.isCloudConfigured;

  /// OneSignal `external_id` değerini odaya izole eder.
  ///
  /// Tek ortak format (istemci + Edge Function aynı biçimi kullanır):
  /// `${oda.trim().toLowerCase()}__${rol.trim().toLowerCase()}`.
  /// Örnek: `YUSUF-CEYDA-2026` + `ceyda` → `yusuf-ceyda-2026__ceyda`.
  ///
  /// Aynı OneSignal App ID'sini kullanan farklı çiftlerin cihazları artık
  /// birbirine push alamaz; alias her zaman oda + rol çiftidir.
  static String? scopedExternalId({
    required String roomCode,
    required String role,
  }) {
    final String room = roomCode.trim().toLowerCase();
    final String cleanRole = role.trim().toLowerCase();
    if (room.isEmpty || cleanRole.isEmpty) return null;
    return '${room}__$cleanRole';
  }

  /// Oda kodunu `external_id` için güvenli küçük harf biçimine çevirir.
  /// (`YUSUF-CEYDA-2026` → `yusuf-ceyda-2026`)
  static String normalizeRoomForExternalId(String raw) {
    final String normalized = AppSettings.normalizeRoomCode(raw);
    if (normalized.isEmpty) return '';
    return normalized.toLowerCase();
  }

  /// Ön plandayken OneSignal ikinci bildirimi bastırılmalı mı?
  ///
  /// Supabase Realtime bağlıysa mesaj yerel olarak zaten işlenir; OS bildirimi
  /// ikinci kez gösterilmez. Realtime yoksa OneSignal'ın bildirimi gösterilir.
  static bool shouldSuppressForegroundPush({
    required bool appResumed,
    required bool realtimeConnected,
  }) => appResumed && realtimeConnected;
}
