import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/entities.dart';
import 'game_state.dart';

/// Bir durum değişikliğinin kaynağı.
///
/// v6'da senkron koordinatörü, uzak paketi uygularken "bu değişikliği buluta
/// geri gönderme" kararını zamanlayıcı (Timer) ile değil bu etiketle verir.
/// Böylece 700–900 ms'lik yarış pencereleri tamamen ortadan kalkar.
enum MutationOrigin { local, remote }

/// Controller modüllerinin oyun durumuna eriştiği dar sözleşme.
///
/// `GameController` bu arayüzü uygular; modüller (quest / development / chat /
/// goals / sync) birbirine değil yalnızca bu sözleşmeye bağlıdır.
abstract interface class GameStateAccess {
  GameState get state;

  Ref get ref;

  /// Yeni durumu yazar, kaynağını etiketler ve diske yazılmasını planlar.
  void commit(GameState next, {MutationOrigin origin = MutationOrigin.local});
}

/// Controller modüllerinin paylaştığı XP/partner yardımcıları.
extension GameStateAccessX on GameStateAccess {
  PartnerData partnerDataOr(String partnerId) =>
      state.partnerData(partnerId) ??
      (partnerId == state.activePartnerId
          ? state.activePartner
          : const PartnerData());

  /// Partnerin profilini XP ile ödüller ve isteğe bağlı ek mutasyon uygular.
  XpAward? awardPartner({
    required String partnerId,
    required StatKey stat,
    required int xp,
    required DateTime at,
    GameState Function(GameState current)? then,
  }) {
    final PartnerData data = partnerDataOr(partnerId);
    final UserProfile? profile = data.profile;
    if (profile == null || xp <= 0) return null;

    final XpAward award = profile.completeQuest(stat: stat, xp: xp, at: at);
    GameState next = state.withPartner(
      partnerId,
      data.copyWith(profile: award.profile),
    );
    if (then != null) next = then(next);
    commit(next);
    return award;
  }
}
