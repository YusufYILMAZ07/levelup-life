import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import 'app_colors.dart';

/// İki partnerin görsel kimliği (renk, emoji, gradient).
///
/// Domain katmanı renk bilmez; bu eşleme tek yerde tutulur ki üst bar,
/// sohbet balonları, radar ve düello kartları aynı dili konuşsun.
abstract final class CouplePalette {
  /// Yusuf — indigo (markanın ana rengi).
  static const Color yusuf = AppColors.primary;

  /// Ceyda — gül kırmızısı.
  static const Color ceyda = Color(0xFFE11D48);

  static Color colorOf(String partnerId) =>
      partnerId == CouplePartner.ceydaId ? ceyda : yusuf;

  static Color softOf(String partnerId, {double alpha = 0.12}) =>
      colorOf(partnerId).withValues(alpha: alpha);

  static LinearGradient gradientOf(String partnerId) {
    final Color base = colorOf(partnerId);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[base, Color.lerp(base, Colors.white, 0.32)!],
    );
  }

  static LinearGradient auraOf(String partnerId, {double peak = 0.14}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          colorOf(partnerId).withValues(alpha: peak),
          colorOf(partnerId).withValues(alpha: 0),
        ],
      );

  static String emojiOf(String partnerId) => CouplePartner.emoji(partnerId);

  static String nameOf(String partnerId) =>
      CouplePartner.displayName(partnerId);

  /// Canlı durum rengi — duruma göre küçük bir renk kodu.
  static Color liveStatusColor(LiveStatus status) => switch (status) {
    LiveStatus.coding => AppColors.primary,
    LiveStatus.academic => ceyda,
    LiveStatus.studying => AppColors.statIntelligence,
    LiveStatus.gym => AppColors.statStrength,
    LiveStatus.coffee => const Color(0xFFB45309),
    LiveStatus.deepFocus => AppColors.statProductivity,
    LiveStatus.resting => AppColors.textTertiary,
  };

  /// Düello skoruna göre renk (yüksek skor sıcak).
  static Color scoreColor(int percent) {
    if (percent >= 85) return AppColors.streak;
    if (percent >= 70) return AppColors.success;
    if (percent >= 50) return AppColors.primary;
    return AppColors.textTertiary;
  }
}
