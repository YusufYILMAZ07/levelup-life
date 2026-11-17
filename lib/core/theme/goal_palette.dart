import 'package:flutter/material.dart';

import '../../domain/entities/goal_type.dart';
import '../../domain/entities/user_profile.dart';
import 'app_colors.dart';
import 'stat_palette.dart';

/// Gelişim hedeflerinin görsel kimliği (Adım 3 kartları, görev etiketleri).
extension GoalPalette on GoalType {
  Color get color => primaryStat.color;

  LinearGradient get gradient => primaryStat.gradient;

  IconData get icon => switch (this) {
        GoalType.fitness => Icons.fitness_center_rounded,
        GoalType.academic => Icons.school_rounded,
        GoalType.career => Icons.code_rounded,
        GoalType.nutrition => Icons.local_drink_rounded,
        GoalType.reading => Icons.auto_stories_rounded,
        GoalType.discipline => Icons.wb_twilight_rounded,
      };
}

/// Onboarding rol kartlarının ikon ve renk kimliği.
extension LifeRolePalette on LifeRole {
  Color get color => switch (this) {
        LifeRole.student => AppColors.primary,
        LifeRole.highSchool => AppColors.statIntelligence,
        LifeRole.examPrep => AppColors.statWillpower,
        LifeRole.employee => AppColors.statProductivity,
        LifeRole.freelancer => AppColors.statVitality,
        LifeRole.explorer => AppColors.statStrength,
      };

  IconData get icon => switch (this) {
        LifeRole.student => Icons.school_rounded,
        LifeRole.highSchool => Icons.backpack_rounded,
        LifeRole.examPrep => Icons.timer_rounded,
        LifeRole.employee => Icons.work_rounded,
        LifeRole.freelancer => Icons.laptop_mac_rounded,
        LifeRole.explorer => Icons.explore_rounded,
      };

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color.lerp(color, Colors.white, 0.20)!, color],
      );
}
