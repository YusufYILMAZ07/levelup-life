import 'package:flutter/material.dart';

/// Tüm uygulamada iOS'un yumuşak lastik bant kaydırmasını kullanır.
///
/// Android'de de aynı hissi verir; 120 Hz ekranlarda `BouncingScrollPhysics`
/// kısa listelerde bile doğal bir ivme sağlar.
final class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
