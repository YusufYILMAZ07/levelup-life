import 'package:flutter/animation.dart';

/// Mikro-animasyon süreleri ve eğrileri.
///
/// Tüm ekranlar bu sabitleri kullanır; böylece uygulama tek bir "ritim" ile
/// hareket eder (Apple Fitness'ın imza hissi).
abstract final class AppMotion {
  // ── Süreler ──────────────────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration cinematic = Duration(milliseconds: 720);

  /// XP çubuğunun dolma süresi.
  static const Duration xpFill = Duration(milliseconds: 950);

  /// Level-up sekansının toplam süresi.
  static const Duration levelUp = Duration(milliseconds: 1200);

  // ── Eğriler ──────────────────────────────────────────────────────────────
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasize = Curves.easeOutBack;
  static const Curve overshoot = Curves.elasticOut;

  /// Liste elemanlarının kademeli girişi için hazır interval.
  static const Interval staggered = Interval(0.15, 1, curve: Curves.easeOutCubic);

  /// Kartların kademeli girişi: index * [staggerStep] ms gecikme.
  static const int staggerStep = 70;
}
