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

  /// v5 tek oyunculu kaydı **silmeden** çift sürümüne taşır.
  ///
  /// v5'te `main.dart` çift sürümü olmayan her kaydı tohumla eziyordu; bu,
  /// kullanıcının onboarding cevaplarını, XP'sini ve sohbetini siliyordu.
  /// v6'da eski profil/ görevler cihaz sahibinin koltuğuna taşınır, mesajlar ve
  /// rubrik geçmişi korunur, yalnızca eksik tohum içerikleri eklenir.
  static GameState migrateFromLegacy(
    GameState legacy, {
    String deviceRole = CouplePartner.yusufId,
  }) {
    final GameState seeded = initialState();
    final String role = CouplePartner.isValid(deviceRole)
        ? deviceRole
        : CouplePartner.yusufId;
    final Map<String, PartnerData> partners = <String, PartnerData>{
      ...seeded.partners,
      role: PartnerData(
        setup: legacy.setup,
        profile: legacy.profile,
        quests: legacy.quests,
      ),
    };
    final Map<String, ChatMessage> messages = <String, ChatMessage>{
      for (final ChatMessage message in seeded.couple.messages)
        message.id: message,
      for (final ChatMessage message in legacy.couple.messages)
        message.id: message,
    };
    final List<ChatMessage> mergedMessages = messages.values.toList()
      ..sort((ChatMessage a, ChatMessage b) {
        final int byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final CoupleState couple = legacy.couple.copyWith(
      messages: mergedMessages,
      scheduleBlocks: legacy.couple.scheduleBlocks.isEmpty
          ? seeded.couple.scheduleBlocks
          : legacy.couple.scheduleBlocks,
      rewardCapsules: legacy.couple.rewardCapsules.isEmpty
          ? seeded.couple.rewardCapsules
          : legacy.couple.rewardCapsules,
      bucketGoals: legacy.couple.bucketGoals.isEmpty
          ? seeded.couple.bucketGoals
          : legacy.couple.bucketGoals,
      deletedMessageTombstones: <String, DateTime>{
        ...seeded.couple.deletedMessageTombstones,
        ...legacy.couple.deletedMessageTombstones,
      },
    );
    return GameState.dual(
      partners: partners,
      activePartnerId: role,
      couple: couple,
    );
  }
}
