import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/development/widgets/mood_capsules_section.dart';

/// Salı 14:30 — haftalık seed'in aktif olduğu sabit an.
final DateTime _tuesday = DateTime(2026, 11, 17, 14, 30);

Future<MemoryGameStore> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 950));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GameState state = CoupleBootstrap.initialState(now: _tuesday);
  final MemoryGameStore store = MemoryGameStore(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gameStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.huge,
              ),
              children: const <Widget>[MoodCapsulesSection()],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('duygu kapsülleri', () {
    testWidgets('dört kapsül başlıklarıyla birlikte görünür', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.text('Anlık Duygu Kapsülleri'), findsOneWidget);
      expect(find.text('Moralin Bozuksa Aç'), findsOneWidget);
      expect(find.text('Beni Özlediysen Aç'), findsOneWidget);
      expect(find.text('Motivasyon Lazımsa Aç'), findsOneWidget);
      expect(find.text('Doğum Günü Mektubun'), findsOneWidget);
    });

    testWidgets('kapsül açılınca iki partnerin notunu gösterir', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('mood-capsule-morale')));
      await tester.pumpAndSettle();

      expect(find.text('Yusuf 💻'), findsOneWidget);
      expect(find.text('Ceyda 🌸'), findsOneWidget);
      expect(find.textContaining('Kötü bir gün'), findsOneWidget);
      expect(find.byKey(const Key('mood-custom-input')), findsOneWidget);
    });

    testWidgets('özel not yazıp sohbete gönderir', (WidgetTester tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('mood-capsule-morale')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('mood-custom-input')),
        'Bugün seninle gurur duyuyorum 💖',
      );
      await tester.tap(find.byKey(const Key('mood-send-morale')));
      await tester.pumpAndSettle();

      expect(find.textContaining('sohbete düştü'), findsOneWidget);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(MoodCapsulesSection)),
      );
      final ChatMessage sent = container
          .read(gameProvider)
          .couple
          .messages
          .last;
      expect(sent.kind, ChatMessageKind.loveNote);
      expect(sent.text, 'Bugün seninle gurur duyuyorum 💖');
      expect(sent.senderId, CouplePartner.yusufId);
    });

    testWidgets('özel not boşsa kapsülün ilk notunu gönderir', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('mood-capsule-birthday')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mood-send-birthday')));
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(MoodCapsulesSection)),
      );
      final ChatMessage sent = container
          .read(gameProvider)
          .couple
          .messages
          .last;
      expect(sent.kind, ChatMessageKind.loveNote);
      expect(sent.text, contains('İyi ki doğdun sevgilim'));
    });
  });
}
