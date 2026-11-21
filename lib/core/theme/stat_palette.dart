import 'package:flutter/material.dart';

import '../../domain/entities/stat_key.dart';
import 'app_colors.dart';

/// Her statın görsel kimliği (renk, ikon, gradient, parıltı).
///
/// Domain katmanı renk bilmez; UI tarafı bu extension üzerinden stat -> renk
/// eşlemesini alır. Böylece yeni bir stat eklendiğinde derleyici bizi uyarır.
extension StatPalette on StatKey {
  Color get color => switch (this) {
    StatKey.intelligence => AppColors.statIntelligence,
    StatKey.strength => AppColors.statStrength,
    StatKey.vitality => AppColors.statVitality,
    StatKey.productivity => AppColors.statProductivity,
    StatKey.willpower => AppColors.statWillpower,
  };

  IconData get icon => switch (this) {
    StatKey.intelligence => Icons.psychology_rounded,
    StatKey.strength => Icons.fitness_center_rounded,
    StatKey.vitality => Icons.eco_rounded,
    StatKey.productivity => Icons.rocket_launch_rounded,
    StatKey.willpower => Icons.shield_rounded,
  };

  /// Stat kartı zemini için %8 opaklıkta renk tonu.
  Color get surfaceTint => color.withValues(alpha: 0.08);

  /// Kart kenarı için %18 opaklıkta renk.
  Color get borderColor => color.withValues(alpha: 0.20);

  /// Işık lekesi / parıltı rengi.
  Color get glowColor => color.withValues(alpha: 0.40);

  /// İkon madalyonu için canlı gradient (açık → koyu, "cam" his).
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color.lerp(color, Colors.white, 0.22)!, color],
  );

  /// Progress bar dolgusu: solda parlak, sağda doygun.
  LinearGradient get barGradient => LinearGradient(
    colors: <Color>[Color.lerp(color, Colors.white, 0.34)!, color],
  );
}
