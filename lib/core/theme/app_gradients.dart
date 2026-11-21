import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Uygulamanın imza gradient'leri (aydınlık tema).
///
/// Gradient'ler `const` tutulur (stat'a özel olanlar `stat_palette.dart`
/// içinde üretilir) böylece her frame'de yeniden tahsis edilmez.
abstract final class AppGradients {
  /// Tüm ekranların arkasındaki ferah zemin: beyaz → inci grisi.
  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFFFFFFF),
      AppColors.background,
      AppColors.backgroundAlt,
    ],
    stops: <double>[0, 0.55, 1],
  );

  /// Ana marka gradient'i: indigo → elektrik mavisi.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.primary, AppColors.accentBlue],
  );

  /// Aynı gradient'in daha açık tonu (ikincil yüzeyler, çipler).
  static const LinearGradient primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.primaryBright, Color(0xFF60A5FA)],
  );

  /// Genel seviye (Level) çubuğu — üç duraklı, canlı.
  static const LinearGradient levelBar = LinearGradient(
    colors: <Color>[
      AppColors.primaryDeep,
      AppColors.primary,
      AppColors.accentBlue,
    ],
  );

  /// XP kazanımı vurgusu (açık → koyu, "parlayan" his).
  static const LinearGradient xpBar = LinearGradient(
    colors: <Color>[AppColors.primaryBright, AppColors.accentBlue],
  );

  /// Streak / seri vurgusu: mercan → altın.
  static const LinearGradient streak = LinearGradient(
    colors: <Color>[AppColors.streak, Color(0xFFFBBF24)],
  );

  /// Level-up / ödül anları için kutlama gradient'i.
  static const LinearGradient legendary = LinearGradient(
    colors: <Color>[
      Color(0xFFF59E0B),
      Color(0xFFF472B6),
      AppColors.primaryBright,
    ],
  );

  /// Beyaz zemin üzerinde yumuşak renkli "aura" (kart arkaları).
  static LinearGradient aura(
    Color color, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    double peakOpacity = 0.16,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: <Color>[
        color.withValues(alpha: peakOpacity),
        color.withValues(alpha: 0),
      ],
    );
  }

  /// Dikey fade — ekran üstündeki atmosfer ışığı.
  static LinearGradient verticalFade(Color color, {double peakOpacity = 0.12}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        color.withValues(alpha: peakOpacity),
        color.withValues(alpha: 0),
      ],
    );
  }

  /// Kart üzerindeki cam parlaması (shimmer katmanı).
  static const LinearGradient sheen = LinearGradient(
    colors: <Color>[Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
    stops: <double>[0, 0.5, 1],
  );
}
