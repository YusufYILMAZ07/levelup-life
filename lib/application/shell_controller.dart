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

/// Push / yerel bildirim dokunuşunda açılacak mesajın kimliği.
///
/// Sohbet ekranı bu değeri bir kez tüketip temizler. Böylece soğuk başlatmada
/// (`terminated → app launch`) gelen `message_id` kaybolmaz.
final class ChatFocusController extends Notifier<String?> {
  @override
  String? build() => null;

  void focus(String? messageId) {
    final String clean = messageId?.trim() ?? '';
    state = clean.isEmpty ? null : clean;
  }

  void clear() => state = null;
}

final NotifierProvider<ChatFocusController, String?> chatFocusMessageProvider =
    NotifierProvider<ChatFocusController, String?>(ChatFocusController.new);
