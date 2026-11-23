import 'dart:convert';

import '../application/game_state.dart';

/// Yedek dosyası geçersizse fırlatılan, kullanıcıya gösterilebilir hata.
final class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Doğrulanmış içe aktarma sonucu.
final class BackupRestore {
  const BackupRestore({
    required this.state,
    required this.schemaVersion,
    required this.exportedAt,
  });

  final GameState state;
  final int schemaVersion;
  final DateTime exportedAt;
}

/// Tüm yerel veriyi JSON olarak dışa/içe aktarır.
///
/// Format:
/// ```json
/// { "app": "levelup-life", "schema_version": 6,
///   "exported_at": "2026-11-23T…", "state": { …GameState… } }
/// ```
/// İçe aktarmada alan alan doğrulama yapılır; bozuk/eksik dosya uygulama
/// durumunu asla yarım bırakmaz (önce parse, sonra tek commit).
abstract final class BackupService {
  static const String appId = 'levelup-life';
  static const int backupVersion = 1;
  static const int supportedSchema = 6;
  static const int maxBytes = 8 * 1024 * 1024;

  static String export(GameState state, {DateTime? at}) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'app': appId,
      'backup_version': backupVersion,
      'schema_version': supportedSchema,
      'exported_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'state': state.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// JSON metnini doğrular ve [GameState] üretir.
  static BackupRestore parse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) {
      throw const BackupException('Yedek metni boş görünüyor.');
    }
    if (text.length > maxBytes) {
      throw const BackupException('Yedek çok büyük (en fazla 8 MB).');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const BackupException('Geçerli bir JSON değil · yedek okunamadı.');
    }
    if (decoded is! Map) {
      throw const BackupException('Yedek kökü bir JSON nesnesi olmalı.');
    }
    final Map<String, dynamic> map = <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
        entry.key.toString(): entry.value,
    };
    if (map['app']?.toString() != appId) {
      throw const BackupException('Bu dosya LevelUp Life yedeği değil.');
    }
    final Object? rawState = map['state'];
    if (rawState is! Map || rawState.isEmpty) {
      throw const BackupException('Yedekte oyun durumu bulunamadı.');
    }
    final Map<String, dynamic> stateJson = <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in rawState.entries)
        entry.key.toString(): entry.value,
    };
    if (stateJson['couple'] is! Map) {
      throw const BackupException('Yedekte çift verisi eksik.');
    }
    final Object? rawPartners = stateJson['partners'];
    if (rawPartners == null || rawPartners is! Map) {
      throw const BackupException('Yedekte partner verisi eksik.');
    }
    final int schema = _asInt(map['schema_version'], supportedSchema);
    if (schema > supportedSchema) {
      throw BackupException(
        'Bu yedek daha yeni bir sürümden (v$schema). Uygulamayı güncelle.',
      );
    }
    final GameState state;
    try {
      state = GameState.fromJson(stateJson);
    } catch (_) {
      throw const BackupException('Yedek içeriği bozuk · geri yüklenemedi.');
    }
    if (!state.isOnboarded && state.partners.isEmpty) {
      throw const BackupException('Yedekte kullanılabilir profil yok.');
    }
    return BackupRestore(
      state: state,
      schemaVersion: schema,
      exportedAt:
          DateTime.tryParse(map['exported_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
