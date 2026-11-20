import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/chat/chat_screen.dart';
import 'package:levelup_life/presentation/chat/widgets/photo_presets.dart';

/// v4 sohbet UX'i: yanıt, arama ve video filtresi.
void main() {
  GameState withMessages(List<ChatMessage> messages) {
    final GameState base = CoupleBootstrap.initialState();
    return base.withCouple(base.couple.copyWith(messages: messages));
  }

  Future<void> pump(WidgetTester tester, GameState state) async {
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
  }

  testWidgets('uzun basıp yanıtla alıntılı mesaj gönderir', (
    WidgetTester tester,
  ) async {
    final ChatMessage first = ChatMessage(
      id: 'm1',
      senderId: CouplePartner.ceydaId,
      createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
      text: 'Selam',
    );
    await pump(tester, withMessages(<ChatMessage>[first]));

    await tester.longPress(find.text('Selam'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-reply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reply-cancel')), findsOneWidget);
    expect(find.textContaining('mesajına yanıt'), findsWidgets);

    await tester.enterText(find.byKey(const Key('chat-input')), 'İyiyim sen?');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ChatScreen)),
    );
    final ChatMessage sent = container.read(gameProvider).couple.messages.last;
    expect(sent.senderId, CouplePartner.yusufId);
    expect(sent.replyToMessageId, 'm1');
    expect(sent.replyPreviewText, 'Selam');
    expect(find.byKey(const Key('reply-cancel')), findsNothing);
  });

  testWidgets('başlıktaki arama mesajları gerçek zamanlı filtreler', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    await pump(
      tester,
      withMessages(<ChatMessage>[
        ChatMessage(
          id: 'm1',
          senderId: CouplePartner.ceydaId,
          createdAt: now.subtract(const Duration(minutes: 3)),
          text: 'Selam canım',
        ),
        ChatMessage(
          id: 'm2',
          senderId: CouplePartner.ceydaId,
          createdAt: now.subtract(const Duration(minutes: 2)),
          text: 'Kahve içelim mi?',
        ),
      ]),
    );

    await tester.tap(find.byKey(const Key('chat-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-search-input')), 'kahve');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-m1')), findsNothing);
    expect(find.byKey(const Key('chat-m2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-search-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-m1')), findsOneWidget);
    expect(find.byKey(const Key('chat-m2')), findsOneWidget);
  });

  testWidgets('anı albümü video ve fotoğrafı ayrı filtreler', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    await pump(
      tester,
      withMessages(<ChatMessage>[
        ChatMessage(
          id: 'photo-1',
          senderId: CouplePartner.yusufId,
          createdAt: now.subtract(const Duration(minutes: 2)),
          photoDataOrUrl: PhotoPreset.all.first.source,
          mediaType: ChatMediaType.image,
          kind: ChatMessageKind.photo,
        ),
        ChatMessage(
          id: 'video-1',
          senderId: CouplePartner.ceydaId,
          createdAt: now.subtract(const Duration(minutes: 1)),
          photoDataOrUrl: 'https://example.com/clip.mp4',
          mediaType: ChatMediaType.video,
          kind: ChatMessageKind.photo,
          durationSeconds: 12,
        ),
      ]),
    );

    await tester.tap(find.byKey(const Key('open-album')));
    await tester.pumpAndSettle();
    expect(find.text('Anı Albümü'), findsOneWidget);
    expect(find.text('Ortak fotoğraf & video galerimiz'), findsOneWidget);
    expect(find.byKey(const Key('album-photo-1')), findsOneWidget);
    expect(find.byKey(const Key('album-video-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('album-filter-videos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-video-1')), findsOneWidget);
    expect(find.byKey(const Key('album-photo-1')), findsNothing);

    await tester.tap(find.byKey(const Key('album-filter-memories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-photo-1')), findsOneWidget);
    expect(find.byKey(const Key('album-video-1')), findsNothing);
  });

  testWidgets('linkten fotoğraf yükler ve sohbete ekler', (
    WidgetTester tester,
  ) async {
    await pump(tester, CoupleBootstrap.initialState());

    await tester.tap(find.byKey(const Key('chat-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Linkten Fotoğraf Yükle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-image-url')));
    await tester.pumpAndSettle();
    expect(find.text('🔗 Linkten Fotoğraf'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('image-url-input')),
      'gecersiz-link',
    );
    await tester.tap(find.byKey(const Key('image-url-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('image-url-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('image-url-input')),
      'https://example.com/couple.png',
    );
    await tester.tap(find.byKey(const Key('image-url-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-caption-input')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('photo-caption-input')),
      'Kampüs anısı',
    );
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ChatScreen)),
    );
    final ChatMessage sent = container.read(gameProvider).couple.messages.last;
    expect(sent.kind, ChatMessageKind.photo);
    expect(sent.photoDataOrUrl, 'https://example.com/couple.png');
    expect(sent.photoCaption, 'Kampüs anısı');
  });
}
