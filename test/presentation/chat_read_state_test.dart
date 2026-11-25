import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/application/shell_controller.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/chat/chat_screen.dart';

/// v6.1 sohbet davranışı: okundu yalnızca sekme aktifken işaretlenir ve
/// liste sadece **yeni son mesaj** geldiğinde en alta kayar.
void main() {
  GameState seeded(int count) {
    final DateTime base = DateTime.now().subtract(Duration(minutes: count));
    final List<ChatMessage> messages = <ChatMessage>[
      for (int i = 0; i < count; i++)
        ChatMessage(
          id: 'm$i',
          senderId: CouplePartner.ceydaId,
          createdAt: base.add(Duration(minutes: i)),
          text: 'mesaj $i',
        ),
    ];
    final GameState state = CoupleBootstrap.initialState();
    return state.withCouple(state.couple.copyWith(messages: messages));
  }

  Future<ProviderContainer> pump(WidgetTester tester, GameState state) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameStoreProvider.overrideWithValue(MemoryGameStore(state)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ChatScreen)));
  }

  ScrollableState listScrollable(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );

  testWidgets('sohbet sekmesi görünür değilken mesajlar okundu sayılmaz', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(tester, seeded(2));
    // İlk açılışta varsayılan sekme "Bugün": gelen mesajlar okunmamış kalır.
    expect(
      container
          .read(gameProvider)
          .couple
          .messages
          .every((ChatMessage message) => !message.isRead),
      isTrue,
    );

    container.read(shellTabProvider.notifier).goToChat();
    await tester.pumpAndSettle();

    expect(
      container
          .read(gameProvider)
          .couple
          .messages
          .every((ChatMessage message) => message.isRead),
      isTrue,
    );
  });

  testWidgets('silinen son mesaj sohbeti aşağı sıçratmaz', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(tester, seeded(30));
    final ScrollableState scrollable = listScrollable(tester);
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    final double before = scrollable.position.pixels;
    expect(before, lessThan(scrollable.position.maxScrollExtent));

    final String lastId = container.read(gameProvider).couple.messages.last.id;
    container.read(gameProvider.notifier).deleteMessage(lastId);
    await tester.pumpAndSettle();

    final double after = listScrollable(tester).position.pixels;
    expect(after, before);
  });

  testWidgets('yeni son mesaj geldiğinde sohbet en alta kayar', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(tester, seeded(30));
    final ScrollableState scrollable = listScrollable(tester);
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();

    container
        .read(gameProvider.notifier)
        .receiveRemoteMessage(
          ChatMessage(
            id: 'fresh',
            senderId: CouplePartner.ceydaId,
            createdAt: DateTime.now(),
            text: 'yeni mesaj',
          ),
        );
    await tester.pumpAndSettle();

    final ScrollableState refreshed = listScrollable(tester);
    // ListView tembel kurulduğu için `maxScrollExtent` bir tahmindir; bu
    // yüzden "sona yakın + yeni balon görünür" doğrulanır.
    expect(
      refreshed.position.pixels,
      greaterThan(refreshed.position.maxScrollExtent * 0.85),
    );
    expect(find.text('yeni mesaj'), findsOneWidget);
  });
}
