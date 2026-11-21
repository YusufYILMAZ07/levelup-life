import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/pin_lock_controller.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/presentation/widgets/pin_lock_screen.dart';
import 'package:levelup_life/services/app_settings.dart';

void main() {
  Future<ProviderContainer> pumpLock(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final MemoryAppSettingsStore store = MemoryAppSettingsStore(
      const AppSettings(pinLockEnabled: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PinLockScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PinLockScreen)),
    );
  }

  Future<void> tapPin(WidgetTester tester, String pin) async {
    for (final String digit in pin.split('')) {
      await tester.tap(find.byKey(Key('pin-key-$digit')));
      await tester.pump();
    }
  }

  testWidgets('varsayılan 3101 PIN kilidi açar', (WidgetTester tester) async {
    final ProviderContainer container = await pumpLock(tester);

    expect(find.text('Yusuf & Ceyda'), findsOneWidget);
    expect(container.read(pinLockProvider), isTrue);

    await tapPin(tester, '3101');
    await tester.pumpAndSettle();

    expect(container.read(pinLockProvider), isFalse);
  });

  testWidgets('hatalı PIN uyarı gösterir ve kilit açılmaz', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpLock(tester);

    await tapPin(tester, '0000');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-error')), findsOneWidget);
    expect(container.read(pinLockProvider), isTrue);
  });

  testWidgets('silme tuşu son haneyi kaldırır', (WidgetTester tester) async {
    await pumpLock(tester);

    await tapPin(tester, '14');
    await tester.tap(find.byKey(const Key('pin-delete')));
    await tester.pump();
    await tapPin(tester, '02');

    expect(find.byKey(const Key('pin-error')), findsNothing);
  });
}
