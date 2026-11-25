import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/app_services.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/services/app_settings.dart';
import 'package:levelup_life/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v6.3: Android 14+ tam alarm izni değişimi → plan hatırlatıcılarının
/// `exact` / `inexact` moduyla yeniden zamanlanması.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationService.instance.onNotificationTap = null;
    AppServices.debugExactAlarmRefresher = null;
    AppServices.debugScheduleSyncCount = 0;
  });

  tearDown(() {
    AppServices.debugExactAlarmRefresher = null;
  });

  test('exactAlarmPermissionChanged yalnızca gerçek değişimi bildirir', () {
    // Önceki değer bilinmiyorsa (uygulama yeni açıldı) "değişti" denmez.
    expect(
      NotificationService.exactAlarmPermissionChanged(before: null, now: true),
      isFalse,
    );
    expect(
      NotificationService.exactAlarmPermissionChanged(before: true, now: true),
      isFalse,
    );
    expect(
      NotificationService.exactAlarmPermissionChanged(
        before: false,
        now: false,
      ),
      isFalse,
    );
    // İzin verildi / kaldırıldı.
    expect(
      NotificationService.exactAlarmPermissionChanged(before: false, now: true),
      isTrue,
    );
    expect(
      NotificationService.exactAlarmPermissionChanged(before: true, now: false),
      isTrue,
    );
  });

  Future<void> pumpServices(WidgetTester tester) async {
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
                // Tek seferlik "Bu telefon kimin?" diyaloğu açılmasın.
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
    // `_bootstrap` gerçek platform kanallarını bekler (plugin yok → hızlı
    // döner). Sahte saatte bu future'lar çözülmediği için kısa bir `runAsync`
    // penceresi açıp açılışın `_booted = true` noktasına gelmesini sağla.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('tam alarm izni değişince planlar yeniden zamanlanır', (
    WidgetTester tester,
  ) async {
    await pumpServices(tester);
    final int afterBootstrap = AppServices.debugScheduleSyncCount;
    expect(
      afterBootstrap,
      greaterThanOrEqualTo(1),
      reason: 'açılışta plan hatırlatıcıları bir kez zamanlanır',
    );

    // Kullanıcı sistem ayarlarından izni verdi → `changed == true`.
    AppServices.debugExactAlarmRefresher = () async => true;
    await resume(tester);
    expect(
      AppServices.debugScheduleSyncCount,
      greaterThan(afterBootstrap),
      reason: 'izin değişince imza sıfırlanıp planlar yeniden zamanlanmalı',
    );

    // İzin değişmedi → gereksiz yeniden zamanlama yok.
    final int afterChange = AppServices.debugScheduleSyncCount;
    AppServices.debugExactAlarmRefresher = () async => false;
    await resume(tester);
    expect(AppServices.debugScheduleSyncCount, afterChange);
  });

  testWidgets('izin sorgusu hata fırlatsa bile resume akışı kilitlenmez', (
    WidgetTester tester,
  ) async {
    await pumpServices(tester);
    final int afterBootstrap = AppServices.debugScheduleSyncCount;
    AppServices.debugExactAlarmRefresher = () async =>
        throw StateError('platform kanalı yok');
    await resume(tester);
    expect(AppServices.debugScheduleSyncCount, afterBootstrap);
    // Ekran hâlâ ayakta (istisna yukarı taşınmadı).
    expect(find.text('ana ekran'), findsOneWidget);
  });
}
