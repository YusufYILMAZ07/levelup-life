import 'partner_data.dart';

/// Yusuf & Ceyda'nın özel günlerinden biri.
///
/// Tarihler her yıl tekrar eder; [daysUntil] her zaman **bir sonraki** oluşu
/// hesaplar ve gün farkı cihazın yerel takvimine göre 0..366 aralığındadır.
/// Sınıf bilinçli olarak yalnızca tarih/sunum taşır; bildirim planlama
/// `NotificationService`, UI ise `BirthdayBanner` / `BirthdayModal` içindedir.
final class SpecialDate {
  const SpecialDate({
    required this.id,
    required this.title,
    required this.countdownPhrase,
    required this.emoji,
    required this.month,
    required this.day,
    required this.description,
    this.partnerId,
  });

  final String id;

  /// "Ceyda'nın Doğum Günü" gibi tam başlık.
  final String title;

  /// "Ceyda'nın Doğum Gününe" gibi yönelme hâli (banner için).
  final String countdownPhrase;

  final String emoji;
  final int month;
  final int day;
  final String description;

  /// Doğum günlerinde ilgili partner; ortak tarihlerde `null`.
  final String? partnerId;

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

  bool get isBirthday => partnerId != null;

  String get dateLabel => '$day ${_months[(month - 1).clamp(0, 11)]}';

  bool isToday(DateTime now) => now.day == day && now.month == month;

  /// Bugünden itibaren bir sonraki tekrar (bugünse bugün 00:00).
  DateTime nextOccurrence(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thisYear = DateTime(now.year, month, day);
    return thisYear.isBefore(today)
        ? DateTime(now.year + 1, month, day)
        : thisYear;
  }

  /// Bir sonraki özel güne kalan gün (bugünse 0).
  int daysUntil(DateTime now) => nextOccurrence(
    now,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  String bannerText(DateTime now) {
    if (isToday(now)) return '🎉 Bugün $title!';
    return '$emoji $countdownPhrase ${daysUntil(now)} gün kaldı!';
  }

  String countdownLabel(DateTime now) {
    final int left = daysUntil(now);
    return left == 0 ? 'Bugün 🎉' : '$left gün kaldı';
  }

  String? greeting(DateTime now, String displayName) {
    if (!isToday(now) || !isBirthday) return null;
    return 'İyi ki doğdun $displayName! 🎂';
  }
}

/// Çiftin dört gerçek özel günü — tek doğruluk kaynağı.
abstract final class CoupleSpecialDates {
  static const SpecialDate ceydaBirthday = SpecialDate(
    id: 'ceyda-birthday',
    title: "Ceyda'nın Doğum Günü",
    countdownPhrase: "Ceyda'nın Doğum Gününe",
    emoji: '🎂',
    month: 11,
    day: 27,
    partnerId: CouplePartner.ceydaId,
    description: 'Ceyda için hazırlanan mektup, yılın özeti ve aşk notu.',
  );

  static const SpecialDate yusufBirthday = SpecialDate(
    id: 'yusuf-birthday',
    title: "Yusuf'un Doğum Günü",
    countdownPhrase: "Yusuf'un Doğum Gününe",
    emoji: '🎂',
    month: 12,
    day: 20,
    partnerId: CouplePartner.yusufId,
    description: 'Birlikte geçen bir yılın kutlaması ve Yusuf’a sürpriz.',
  );

  static const SpecialDate anniversary = SpecialDate(
    id: 'anniversary',
    title: 'Yıldönümümüz',
    countdownPhrase: 'Yıldönümümüze',
    emoji: '💍',
    month: 1,
    day: 31,
    description: 'Birlikte attığımız ilk adımın ve her yeni yılın kutlaması.',
  );

  static const SpecialDate valentinesDay = SpecialDate(
    id: 'valentines-day',
    title: 'Sevgililer Günü',
    countdownPhrase: 'Sevgililer Gününe',
    emoji: '💘',
    month: 2,
    day: 14,
    description:
        'Aşkımızı bir notla, bir anıyla ve küçük bir sürprizle kutlayın.',
  );

  static const List<SpecialDate> all = <SpecialDate>[
    ceydaBirthday,
    yusufBirthday,
    anniversary,
    valentinesDay,
  ];

  /// En yakın özel gün — eşitlikte [all] sırası korunur.
  static SpecialDate next(DateTime now) {
    SpecialDate best = all.first;
    for (final SpecialDate date in all.skip(1)) {
      if (date.daysUntil(now) < best.daysUntil(now)) best = date;
    }
    return best;
  }

  /// Geri sayıma göre sıralı liste (en yakın önce).
  static List<SpecialDate> sorted(DateTime now) {
    final List<SpecialDate> dates = <SpecialDate>[...all];
    dates.sort(
      (SpecialDate a, SpecialDate b) =>
          a.daysUntil(now).compareTo(b.daysUntil(now)),
    );
    return List<SpecialDate>.unmodifiable(dates);
  }

  static SpecialDate? byId(String id) {
    for (final SpecialDate date in all) {
      if (date.id == id) return date;
    }
    return null;
  }
}

/// Geriye dönük uyumluluk: eski ekranlar `BirthdayConfig.ceyda` kullanır.
abstract final class BirthdayConfig {
  static const SpecialDate ceyda = CoupleSpecialDates.ceydaBirthday;
  static const SpecialDate yusuf = CoupleSpecialDates.yusufBirthday;
  static const SpecialDate anniversary = CoupleSpecialDates.anniversary;
  static const SpecialDate valentinesDay = CoupleSpecialDates.valentinesDay;
  static const List<SpecialDate> all = CoupleSpecialDates.all;
}
