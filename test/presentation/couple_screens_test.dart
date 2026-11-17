import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/birthday/birthday_modal.dart';
import 'package:levelup_life/presentation/chat/chat_screen.dart';
import 'package:levelup_life/presentation/dashboard/dashboard_screen.dart';
import 'package:levelup_life/presentation/development/development_screen.dart';

/// Çift sürümü ekranlarının temel akışları: partner segmenti, rubrik puanlama,
/// hızlı eylem, sohbet gönderimi ve doğum günü kutlaması.
void main() {
  late GameState initialState;

  setUp(() {
    initialState = CoupleBootstrap.initialState();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameStoreProvider.overrideWithValue(MemoryGameStore(initialState)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard üst barında iki partner ve canlı durum görünür', (
    WidgetTester tester,
  ) async {
    await pump(tester, const DashboardScreen());

    expect(find.byKey(const Key('partner-yusuf')), findsOneWidget);
    expect(find.byKey(const Key('partner-ceyda')), findsOneWidget);
    expect(find.byKey(const Key('live-status-yusuf')), findsOneWidget);
    expect(find.byKey(const Key('live-status-ceyda')), findsOneWidget);
    expect(find.textContaining('doğum günü'), findsWidgets);
  });

  testWidgets('gelişim sekmesinde rubrik puanı XP kazandırır', (
    WidgetTester tester,
  ) async {
    await pump(tester, const DevelopmentScreen());

    expect(find.text('Günlük Gelişim Rubriği'), findsOneWidget);

    final Finder scoreButton = find.byKey(const Key('rubric-WIL-3'));
    await tester.scrollUntilVisible(
      scoreButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(scoreButton);
    await tester.pump();

    expect(find.textContaining('Disiplin güçlendi'), findsOneWidget);
  });

  testWidgets('gelişim sekmesinde hızlı eylem bonus XP verir', (
    WidgetTester tester,
  ) async {
    await pump(tester, const DevelopmentScreen());

    final Finder quick = find.byKey(const Key('quick-pomodoro'));
    await tester.scrollUntilVisible(
      quick,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(quick);
    await tester.pump();

    expect(find.textContaining('+20 XP'), findsWidgets);
  });

  testWidgets('sohbet mesajı gönderilir ve listede görünür', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ChatScreen());

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Bugün seninle gurur duyuyorum',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(find.text('Bugün seninle gurur duyuyorum'), findsOneWidget);
  });

  testWidgets('doğum günü modalı özet ve kapatma butonu içerir', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Scaffold(body: Center(child: BirthdayModal())));

    expect(find.text('Sevgili Ceyda,'), findsOneWidget);
    expect(find.byKey(const Key('birthday-close')), findsOneWidget);
    expect(find.byKey(const Key('birthday-note-next')), findsOneWidget);
    expect(
      find.textContaining(
        BirthdayConfig.ceyda.isToday(DateTime.now())
            ? 'İyi ki doğdun'
            : 'Ceyda için sürpriz',
      ),
      findsOneWidget,
    );
  });
}
