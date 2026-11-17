import 'package:flutter/widgets.dart';

/// 4pt tabanlı boşluk ölçeği.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Ekran yatay padding'i.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xxl);

  /// Standart kart iç boşluğu.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Büyük / kahraman kart iç boşluğu.
  static const EdgeInsets cardLarge = EdgeInsets.all(xxl);

  /// Liste elemanları arası dikey aralık.
  static const EdgeInsets listGap = EdgeInsets.only(bottom: md);

  /// Alt güvenli alan + buton payı.
  static const EdgeInsets bottomBar = EdgeInsets.fromLTRB(xxl, md, xxl, lg);
}

/// Köşe yarıçapları — brief'teki 16 / 24 kuralı burada token'laşır.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Modal / bottom sheet için sadece üst köşeler.
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
}
