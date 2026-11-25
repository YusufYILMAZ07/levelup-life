import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/app_services.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/application/shell_controller.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v6.2: yerel bildirim yönlendirmesi ve plan zamanlama imzası regresyonları.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationService.instance.onNotificationTap = null;
  });

  Future<ProviderContainer> pumpServices(WidgetTester tester) async {
    final GameState seed = CoupleBootstrap.initialState(
      now: DateTime(2026, 11, 23, 9),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameStoreProvider.overrideWithValue(MemoryGameStore(seed)),
          appSettingsStoreProvider.overrideWithValue(
            MemoryAppSettingsStore(
              const AppSettings(
                deviceOwnerConfigured: true,
                // Test cihazında tek seferlik karşılama diyaloğu açılmasın.
                lockToDeviceOwner: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: AppServices(child: Scaffold(body: Text('ana ekran'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // `_bootstrap` içindeki unawaited çağrılar (configure / syncSchedules)
    // tamamlanmadan bildirim dokunuşu test edilmesin.
    await tester.pump(const Duration(milliseconds: 50));
    return ProviderScope.containerOf(tester.element(find.byType(AppServices)));
  }

  testWidgets('tüm yerel bildirim payload’ları doğru sekmeye gider', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpServices(tester);
    final void Function(String?)? tap =
        NotificationService.instance.onNotificationTap;
    expect(tap, isNotNull);
    expect(container.read(shellTabProvider), ShellTabController.today);

    // 1) Rubrik güncellemesi → Gelişim sekmesi.
    tap!('sync-rubric');
    expect(container.read(shellTabProvider), ShellTabController.development);

    // 2) Sohbet bildirimi → Sohbet sekmesi + mesaj odağı.
    tap('chat:msg-42');
    expect(container.read(shellTabProvider), ShellTabController.chat);
    expect(container.read(chatFocusMessageProvider), 'msg-42');

    // 3) Plan senkronizasyonu → Bugün / Plan sekmesi.
    tap('sync-plan');
    expect(container.read(shellTabProvider), ShellTabController.today);

    // 4) Özel gün → İlerleme sekmesi.
    tap('special:ny-2027');
    expect(container.read(shellTabProvider), ShellTabController.progress);

    // 5) Plan hatırlatıcısı (`plan:<id>`) → Bugün / Plan sekmesi.
    tap('plan:block-1');
    expect(container.read(shellTabProvider), ShellTabController.today);

    // 6) Check-in → Bugün sekmesi (İlerleme'den geri döner).
    tap('special:ny-2027');
    expect(container.read(shellTabProvider), ShellTabController.progress);
    tap('checkin');
    expect(container.read(shellTabProvider), ShellTabController.today);
  });

  test('plan günü / sessiz saat değişince zamanlama imzası değişir', () {
    final GameState state = CoupleBootstrap.initialState(
      now: DateTime(2026, 11, 23, 9),
    );
    const AppSettings base = AppSettings();
    final String signature = AppServices.scheduleSignature(state, base);
    // Aynı durum + aynı ayar → aynı imza (gereksiz yeniden zamanlama yok).
    expect(AppServices.scheduleSignature(state, base), signature);

    expect(
      AppServices.scheduleSignature(
        state,
        base.copyWith(
          quietStartMinutes: base.quietStartMinutes == 23 * 60
              ? 22 * 60
              : 23 * 60,
        ),
      ),
      isNot(signature),
    );
    expect(
      AppServices.scheduleSignature(
        state,
        base.copyWith(
          quietEndMinutes: base.quietEndMinutes == 7 * 60 ? 6 * 60 : 7 * 60,
        ),
      ),
      isNot(signature),
    );
    expect(
      AppServices.scheduleSignature(
        state,
        base.copyWith(doNotDisturbEnabled: !base.doNotDisturbEnabled),
      ),
      isNot(signature),
    );

    final List<ScheduleBlock> blocks = state.couple.scheduleBlocks;
    expect(blocks, isNotEmpty);
    final ScheduleBlock first = blocks.first;
    final List<ScheduleBlock> moved = <ScheduleBlock>[
      first.copyWith(weekday: first.weekday == 1 ? 2 : 1),
      ...blocks.skip(1),
    ];
    final GameState movedState = state.withCouple(
      state.couple.copyWith(scheduleBlocks: moved),
    );
    expect(
      AppServices.scheduleSignature(movedState, base),
      isNot(signature),
      reason: 'plan günü değişince hatırlatıcı yeniden zamanlanmalı',
    );
  });
}
