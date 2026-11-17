import 'package:flutter/material.dart';

/// Tipografi ölçeği.
///
/// Sayısal veriler (XP, Level, Streak) her zaman `numeric*` stillerini kullanır:
/// bu stiller `tabularFigures` içerir, böylece animasyon sırasında rakamlar
/// zıplamaz — Apple Fitness hissi buradan gelir.
abstract final class AppTypography {
  static const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Onboarding / level-up kahraman başlığı.
  static const TextStyle displayHero = TextStyle(
    fontSize: 52,
    height: 1.02,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.8,
    fontFeatures: _tabular,
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    height: 1.06,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    height: 1.16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    height: 1.32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  /// "CORE SYSTEMS" tarzı üst etiketler.
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle numericHero = TextStyle(
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    fontFeatures: _tabular,
  );

  static const TextStyle numericLarge = TextStyle(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );

  static const TextStyle numeric = TextStyle(
    fontSize: 18,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
  );

  static const TextStyle numericSmall = TextStyle(
    fontSize: 13,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// Renkleri uygulanmış Material [TextTheme].
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primary),
      displayMedium: displayHero.copyWith(color: primary),
      displaySmall: headline.copyWith(color: primary),
      headlineLarge: headline.copyWith(color: primary),
      headlineMedium: title.copyWith(color: primary),
      headlineSmall: subtitle.copyWith(color: primary),
      titleLarge: title.copyWith(color: primary),
      titleMedium: subtitle.copyWith(color: primary),
      titleSmall: body.copyWith(color: primary, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(color: secondary),
      bodyMedium: body.copyWith(color: secondary),
      bodySmall: bodySmall.copyWith(color: tertiary),
      labelLarge: subtitle.copyWith(color: primary),
      labelMedium: caption.copyWith(color: secondary),
      labelSmall: label.copyWith(color: tertiary),
    );
  }
}
