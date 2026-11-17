/// Sayı ve tarih biçimlendirme yardımcıları.
///
/// `intl` bağımlılığı eklemeden, Türkçe okunabilirlik için binlik ayıraç
/// kullanılır: `1000 → 1.000`, `2450 → 2.450`.
abstract final class FormatX {
  /// Binlik ayıraçlı tam sayı.
  static String number(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// "450 / 1.000 XP"
  static String xpPair(int current, int total) =>
      '${number(current)} / ${number(total)} XP';

  /// "İyi akşamlar", "Günaydın" — saate göre selamlama.
  static String greeting(DateTime now) {
    final int hour = now.hour;
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  /// "15 Kasım" gibi kısa Türkçe tarih.
  static String shortDate(DateTime date) {
    const List<String> months = <String>[
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// "45 dk" / "1 sa 30 dk".
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes dk';
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }
}
