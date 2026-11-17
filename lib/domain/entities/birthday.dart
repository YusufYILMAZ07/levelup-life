import 'partner_data.dart';

/// Doğum günü deneyiminin tarih yapılandırması.
///
/// Uygulama hediye olduğu için tarih kodda sabittir; başka bir güne almak
/// isterseniz yalnızca [BirthdayConfig.ceyda] satırını düzenleyin. Sürpriz
/// modalı Bugün sekmesindeki karttan **her zaman** açılabilir, otomatik
/// kutlama ise yalnızca tarih geldiğinde tetiklenir.
final class BirthdayConfig {
  const BirthdayConfig({
    required this.partnerId,
    required this.day,
    required this.month,
    this.year,
  });

  final String partnerId;
  final int day;
  final int month;

  /// Doğum yılı (bilinmiyorsa `null` → yaş hesaplanmaz).
  final int? year;

  /// Ceyda'nın doğum günü. (Değiştirmek için bu satırı düzenleyin.)
  static const BirthdayConfig ceyda = BirthdayConfig(
    partnerId: CouplePartner.ceydaId,
    day: 14,
    month: 2,
  );

  static const List<String> _months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  String get dateLabel => '$day ${_months[(month - 1).clamp(0, 11)]}';

  bool isToday(DateTime now) => now.day == day && now.month == month;

  /// Bir sonraki doğum gününe kalan gün (bugünse 0).
  int daysUntil(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    DateTime next = DateTime(now.year, month, day);
    if (next.isBefore(today)) next = DateTime(now.year + 1, month, day);
    return next.difference(today).inDays;
  }

  /// Bugün doğum günü ise kutlama metni üretir.
  String? greeting(DateTime now, String displayName) {
    if (!isToday(now)) return null;
    return 'İyi ki doğdun $displayName! 🎂';
  }
}
