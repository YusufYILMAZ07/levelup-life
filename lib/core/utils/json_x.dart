/// Flutter'dan bağımsız, savunmacı JSON yardımcıları.
///
/// Backend (Supabase / Firebase) şemaları değişse bile eski cache dosyaları
/// uygulamayı çökertmesin diye tüm alanlar `fallback` ile okunur.
abstract final class JsonX {
  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic>? asMapOrNull(Object? value) =>
      value == null ? null : asMap(value);

  static String asString(Object? value, {String fallback = ''}) =>
      value is String ? value : (value?.toString() ?? fallback);

  static int asInt(Object? value, {int fallback = 0}) => switch (value) {
    int v => v,
    num v => v.round(),
    String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };

  static double asDouble(Object? value, {double fallback = 0}) =>
      switch (value) {
        num v => v.toDouble(),
        String v => double.tryParse(v) ?? fallback,
        _ => fallback,
      };

  static bool asBool(Object? value, {bool fallback = false}) => switch (value) {
    bool v => v,
    num v => v != 0,
    String v => v.toLowerCase() == 'true',
    _ => fallback,
  };

  static DateTime? asDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static List<String> asStringList(Object? value) {
    if (value is Iterable) {
      return <String>[for (final Object? item in value) item.toString()];
    }
    return const <String>[];
  }

  /// Enum'ı `name` üzerinden çözer; bilinmeyen değerde [fallback] döner.
  static T asEnum<T extends Enum>(
    List<T> values,
    Object? raw, {
    required T fallback,
  }) {
    if (raw is String) {
      for (final T candidate in values) {
        if (candidate.name == raw) return candidate;
      }
    }
    return fallback;
  }
}
