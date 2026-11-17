import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt sekme indeksi (Bugün / Gelişim / Sohbet / İlerleme).
///
/// Dashboard'daki "📅 Tüm Haftalık Planı Gör" gibi kısayollar bu provider
/// üzerinden sekmeler arası geçiş yapar; shell kendi state'ini tutmaz.
final class ShellTabController extends Notifier<int> {
  static const int today = 0;
  static const int development = 1;
  static const int chat = 2;
  static const int progress = 3;

  @override
  int build() => today;

  void goTo(int index) {
    if (index < today || index > progress || state == index) return;
    state = index;
  }

  void goToDevelopment() => goTo(development);

  void goToChat() => goTo(chat);
}

final NotifierProvider<ShellTabController, int> shellTabProvider =
    NotifierProvider<ShellTabController, int>(ShellTabController.new);
