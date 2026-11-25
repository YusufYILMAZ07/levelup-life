import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/core/constants/app_constants.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/presentation/shell/app_shell.dart';

/// Gerçek küçük Android telefonu + büyük sistem yazı boyutu senaryosu:
/// 360×640 dp ekran, 1.3× metin ölçeği. Dört ana sekme ve alt sayfalar
/// kaydırılarak RenderFlex taşması olmadığı doğrulanır.
const Size _smallScreen = Size(360, 640);
const TextScaler _largeText = TextScaler.linear(1.3);

final DateTime _now = DateTime(2026, 11, 23, 12);

Future<void> _pumpShell(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_smallScreen);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameStoreProvider.overrideWithValue(
          MemoryGameStore(CoupleBootstrap.initialState(now: _now)),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: _largeText),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _scrollableOf(String screenKey) => find
    .descendant(
      of: find.byKey(ValueKey<String>(screenKey)),
      matching: find.byType(Scrollable),
    )
    .first;

/// Sekmeyi baştan sona kaydırır; her adımda taşma hatası olmadığını doğrular.
Future<void> _sweep(
  WidgetTester tester, {
  required String tab,
  required String screenKey,
}) async {
  final Finder scrollable = _scrollableOf(screenKey);
  expect(scrollable, findsOneWidget, reason: '$tab: kaydırılabilir gövde yok');

  for (int step = 0; step < 16; step++) {
    await tester.drag(scrollable, const Offset(0, -340));
    await tester.pump(const Duration(milliseconds: 140));
    final Object? error = tester.takeException();
    expect(error, isNull, reason: '$tab · aşağı adım $step taştı: $error');
  }
  for (int step = 0; step < 16; step++) {
    await tester.drag(scrollable, const Offset(0, 340));
    await tester.pump(const Duration(milliseconds: 140));
    final Object? error = tester.takeException();
    expect(error, isNull, reason: '$tab · yukarı adım $step taştı: $error');
  }
  // Testin devamı üstteki kontrollere dokunabilsin: listenin başına dön.
  await tester.drag(scrollable, const Offset(0, 4000), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  test('görünen marka adı ve sürüm CEYYUS / 6.4.0', () {
    expect(AppConstants.appName, 'CEYYUS');
    expect(AppConstants.appVersion, '6.4.0');
    // Veri güvenliği: yedek kimliği değişmedi (mevcut yedekler okunur).
    expect(AppConstants.cacheGameState, 'cache.game_state');
  });

  testWidgets('360×640 + 1.3× yazı: Bugün sekmesi taşmadan çizilir', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.byKey(const Key('nav-today')), findsOneWidget);
    expect(find.byKey(const Key('nav-development')), findsOneWidget);
    expect(find.byKey(const Key('nav-chat')), findsOneWidget);
    expect(find.byKey(const Key('nav-progress')), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Gelişim'), findsOneWidget);
    expect(find.text('Sohbet'), findsOneWidget);
    expect(find.text('İlerleme'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _sweep(tester, tab: 'Bugün', screenKey: 'dashboard');
  });

  testWidgets('Gelişim sekmesinin üç alt sekmesi taşmadan çizilir', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const Key('nav-development')));
    await tester.pumpAndSettle();

    await _sweep(
      tester,
      tab: 'Gelişim · Haftalık Plan',
      screenKey: 'development',
    );

    await tester.tap(find.byKey(const Key('dev-tab-daily')));
    await tester.pumpAndSettle();
    await _sweep(
      tester,
      tab: 'Gelişim · Günlük Puan',
      screenKey: 'development',
    );

    await tester.tap(find.byKey(const Key('dev-tab-rewards')));
    await tester.pumpAndSettle();
    await _sweep(tester, tab: 'Gelişim · Kapsüller', screenKey: 'development');
  });

  testWidgets('Sohbet sekmesi taşmadan çizilir', (WidgetTester tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const Key('nav-chat')));
    await tester.pumpAndSettle();

    await _sweep(tester, tab: 'Sohbet', screenKey: 'chat');
  });

  testWidgets('İlerleme sekmesi 7 ve 30 gün görünümünde taşmadan çizilir', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const Key('nav-progress')));
    await tester.pumpAndSettle();

    await _sweep(tester, tab: 'İlerleme · 7 gün', screenKey: 'progress');

    await tester.scrollUntilVisible(
      find.byKey(const Key('progress-range-month')),
      240,
      scrollable: _scrollableOf('progress'),
    );
    await tester.tap(find.byKey(const Key('progress-range-month')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _sweep(tester, tab: 'İlerleme · 30 gün', screenKey: 'progress');
  });
}
