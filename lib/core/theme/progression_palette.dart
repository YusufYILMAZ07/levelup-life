import 'package:flutter/material.dart';

import '../../domain/entities/energy_mode.dart';
import '../../domain/entities/rank_tier.dart';

/// Seviye unvanlarının (Çaylak → Efsane) görsel kimliği — aydınlık tema.
extension RankTierPalette on RankTier {
  Color get color => switch (this) {
    RankTier.rookie => const Color(0xFF64748B),
    RankTier.journeyman => const Color(0xFFB45309),
    RankTier.expert => const Color(0xFF4F46E5),
    RankTier.master => const Color(0xFF9333EA),
    RankTier.legend => const Color(0xFFDB2777),
  };

  IconData get icon => switch (this) {
    RankTier.rookie => Icons.egg_alt_rounded,
    RankTier.journeyman => Icons.handyman_rounded,
    RankTier.expert => Icons.workspace_premium_rounded,
    RankTier.master => Icons.military_tech_rounded,
    RankTier.legend => Icons.auto_awesome_rounded,
  };

  /// Profil çerçevesi gradient'i.
  LinearGradient get frameGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color.lerp(color, Colors.white, 0.35)!, color],
  );
}

/// Enerji modlarının görsel kimliği.
extension EnergyModePalette on EnergyMode {
  Color get color => switch (this) {
    EnergyMode.balanced => const Color(0xFF4F46E5),
    EnergyMode.lowEnergy => const Color(0xFFF59E0B),
    EnergyMode.examWeek => const Color(0xFF8B5CF6),
    EnergyMode.overloaded => const Color(0xFFEF4444),
  };

  IconData get icon => switch (this) {
    EnergyMode.balanced => Icons.bolt_rounded,
    EnergyMode.lowEnergy => Icons.battery_alert_rounded,
    EnergyMode.examWeek => Icons.menu_book_rounded,
    EnergyMode.overloaded => Icons.schedule_rounded,
  };
}
