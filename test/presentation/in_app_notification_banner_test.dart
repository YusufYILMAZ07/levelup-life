import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/shell_controller.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/presentation/widgets/in_app_notification_banner.dart';

void main() {
  setUp(InAppNotificationCenter.instance.reset);
  tearDown(InAppNotificationCenter.instance.reset);

  Future<ProviderContainer> pumpHost(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InAppNotificationHost(
            child: Scaffold(body: Center(child: Text('Ana ekran'))),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(InAppNotificationHost)),
    );
  }

  testWidgets('partner mesajı üstten banner olarak görünür', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    InAppNotificationCenter.instance.show(
      title: 'Ceyda 🌸',
      body: 'Sana bir fotoğraf gönderdi 📸',
      emoji: '📸',
      kind: InAppNotificationKind.photo,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('in-app-notification-banner')), findsOneWidget);
    expect(find.text('Ceyda 🌸'), findsOneWidget);
    expect(find.text('Sana bir fotoğraf gönderdi 📸'), findsOneWidget);

    // Otomatik kapanma zamanlayıcısını test sonunda boşalt.
    InAppNotificationCenter.instance.reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('banner’a dokunmak Sohbet sekmesini açar', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpHost(tester);
    expect(container.read(shellTabProvider), ShellTabController.today);

    InAppNotificationCenter.instance.show(
      title: 'Yusuf 💻',
      body: 'Sana bir dürtme gönderdi 💫',
      emoji: '💫',
      kind: InAppNotificationKind.nudge,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('in-app-notification-banner')));

    expect(container.read(shellTabProvider), ShellTabController.chat);
    expect(InAppNotificationCenter.instance.current, isNull);
  });

  testWidgets('kapat düğmesi banner’ı gizler', (WidgetTester tester) async {
    await pumpHost(tester);
    InAppNotificationCenter.instance.show(
      title: 'Ceyda 🌸',
      body: 'Kısa bir not bıraktı 💌',
      emoji: '💌',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byKey(const Key('in-app-notification-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('in-app-notification-banner')), findsNothing);
    expect(InAppNotificationCenter.instance.current, isNull);
  });
}
