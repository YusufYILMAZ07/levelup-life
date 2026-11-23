import '../domain/entities/entities.dart';

/// Gelişim rubriğinde bir puanlamanın sonucu (kutlama/özet için).
final class RubricOutcome {
  const RubricOutcome({
    required this.partnerId,
    required this.pillar,
    required this.score,
    required this.xpGained,
    required this.leveledUp,
    required this.synergyXp,
    required this.totalToday,
  });

  final String partnerId;
  final StatKey pillar;
  final int score;

  /// Bu dokunuşla kazanılan XP (aynı gün tekrar puanlamada 0).
  final int xpGained;

  final bool leveledUp;

  /// Sinerji tetiklendiyse her iki partnerin kazandığı XP.
  final int synergyXp;

  /// Partnerin bugünkü toplam rubrik puanı (0..15).
  final int totalToday;

  bool get hasSynergy => synergyXp > 0;

  @override
  String toString() =>
      'RubricOutcome($partnerId · ${pillar.code} = $score · +$xpGained XP · '
      'sinerji: $synergyXp)';
}

/// Plan bloğu tamamlamanın sonucu (kutlama/snackbar için).
final class ScheduleOutcome {
  const ScheduleOutcome({
    required this.partnerId,
    required this.block,
    required this.xpGained,
    required this.leveledUp,
    required this.alreadyCompleted,
  });

  final String partnerId;
  final ScheduleBlock block;

  /// Bu dokunuşla kazanılan XP (gün içinde tekrar tamamlamada 0).
  final int xpGained;

  final bool leveledUp;

  /// Blok bugün daha önce tamamlanmış mıydı?
  final bool alreadyCompleted;

  @override
  String toString() =>
      'ScheduleOutcome($partnerId · ${block.title} · +$xpGained XP)';
}
