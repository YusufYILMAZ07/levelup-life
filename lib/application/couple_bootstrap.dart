import '../domain/entities/entities.dart';
import '../domain/services/couple_seed.dart';
import 'game_state.dart';

/// Uygulamanın "hediye modu" başlangıç durumu.
///
/// `main.dart` store boşsa bunu diske yazar; böylece uygulama ilk açılışta
/// Yusuf & Ceyda'nın hazır profilleriyle, sohbet geçmişiyle ve bucket list'iyle
/// açılır. Testler store'u boş bıraktığı için onboarding akışı korunur.
abstract final class CoupleBootstrap {
  static GameState initialState({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return GameState.dual(
      partners: CoupleSeeder.partners(now: at),
      activePartnerId: CouplePartner.yusufId,
      couple: CoupleSeeder.couple(now: at),
    );
  }
}
