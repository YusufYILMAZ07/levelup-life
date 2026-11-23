import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/presentation/dashboard/dashboard_screen.dart';
import 'package:levelup_life/services/app_settings.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GameState state = CoupleBootstrap.initialState();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameStoreProvider.overrideWithValue(MemoryGameStore(state)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('v4 ayar bölümleri (avatar, bildirim, PIN, bulut) görünür', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    expect(find.text('Profil fotoğrafları'), findsOneWidget);
    expect(find.text('📱 Bu Telefon Kimin?'), findsOneWidget);
    expect(find.byKey(const Key('device-owner-yusuf')), findsOneWidget);
    expect(find.byKey(const Key('device-owner-ceyda')), findsOneWidget);
    expect(find.byKey(const Key('device-test-mode')), findsOneWidget);
    expect(find.byKey(const Key('onesignal-app-id')), findsOneWidget);
    // v6: REST anahtarı istemciden kaldırıldı.
    expect(find.byKey(const Key('onesignal-rest-key')), findsNothing);
    expect(find.byKey(const Key('notif-dnd')), findsOneWidget);
    expect(find.byKey(const Key('pin-grace')), findsOneWidget);
    expect(find.byKey(const Key('biometric-toggle')), findsOneWidget);
    expect(find.byKey(const Key('avatar-yusuf')), findsOneWidget);
    expect(find.byKey(const Key('avatar-ceyda')), findsOneWidget);
    expect(find.byKey(const Key('notif-messages')), findsOneWidget);
    expect(find.byKey(const Key('notif-plan')), findsOneWidget);
    expect(find.byKey(const Key('notif-checkin')), findsOneWidget);
    expect(find.byKey(const Key('pin-toggle')), findsOneWidget);
    expect(find.byKey(const Key('pin-change')), findsOneWidget);
    expect(find.byKey(const Key('cloud-url')), findsOneWidget);
    expect(find.byKey(const Key('cloud-key')), findsOneWidget);
    expect(find.byKey(const Key('cloud-room')), findsOneWidget);
    expect(find.byKey(const Key('cloud-connect')), findsOneWidget);
    expect(
      find.textContaining('İki Telefon Canlı Senkronizasyon'),
      findsOneWidget,
    );
    expect(find.text('Bu Telefon: Yusuf 💻'), findsOneWidget);
  });

  testWidgets('mesaj bildirimi anahtarı ayarı kalıcı olarak değiştirir', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    expect(container.read(appSettingsProvider).messageNotifications, isTrue);

    final Finder notif = find.byKey(const Key('notif-messages'));
    await tester.ensureVisible(notif);
    await tester.pumpAndSettle();
    await tester.tap(notif);
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).messageNotifications, isFalse);
  });

  testWidgets('çift PIN kilidi açılıp kapatılabilir', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    expect(container.read(appSettingsProvider).pinLockEnabled, isFalse);

    final Finder pinToggle = find.byKey(const Key('pin-toggle'));
    await tester.ensureVisible(pinToggle);
    await tester.pumpAndSettle();
    await tester.tap(pinToggle);
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).pinLockEnabled, isTrue);

    await tester.tap(pinToggle);
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).pinLockEnabled, isFalse);
  });
}
