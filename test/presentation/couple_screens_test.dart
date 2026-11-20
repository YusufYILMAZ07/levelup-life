import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/birthday/birthday_modal.dart';
import 'package:levelup_life/presentation/chat/chat_screen.dart';
import 'package:levelup_life/presentation/chat/widgets/photo_presets.dart';
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
    await tester.tap(find.byKey(const Key('dev-tab-daily')));
    await tester.pumpAndSettle();

    expect(find.text('Günlük Gelişim Rubriği'), findsOneWidget);

    final Finder scoreButton = find.byKey(const Key('rubric-WIL-3'));
    await tester.scrollUntilVisible(
      scoreButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(scoreButton);
    await tester.pumpAndSettle();
    await tester.tap(scoreButton);
    await tester.pump();

    expect(find.textContaining('Disiplin güçlendi'), findsOneWidget);
  });

  testWidgets('gelişim sekmesinde hızlı eylem bonus XP verir', (
    WidgetTester tester,
  ) async {
    await pump(tester, const DevelopmentScreen());
    await tester.tap(find.byKey(const Key('dev-tab-daily')));
    await tester.pumpAndSettle();

    final Finder quick = find.byKey(const Key('quick-pomodoro'));
    await tester.scrollUntilVisible(
      quick,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(quick);
    await tester.pumpAndSettle();
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

  testWidgets('sohbetten haftalık plan kanıtı gönderilir', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    initialState = initialState.withCouple(
      initialState.couple.copyWith(
        scheduleBlocks: <ScheduleBlock>[
          ScheduleBlock(
            id: 'proof-now',
            partnerId: CouplePartner.yusufId,
            weekday: now.weekday,
            startMinutes: 0,
            endMinutes: 23 * 60 + 59,
            title: 'Kütüphane Sprinti',
            category: ScheduleCategory.study,
          ),
        ],
      ),
    );
    await pump(tester, const ChatScreen());

    await tester.tap(find.byKey(const Key('chat-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Hazır anı kartları'), findsOneWidget);

    await tester.tap(find.byKey(const Key('send-schedule-proof')));
    await tester.pumpAndSettle();

    final CoupleState couple = ProviderScope.containerOf(
      tester.element(find.byType(ChatScreen)),
    ).read(gameProvider).couple;
    final ChatMessage proof = couple.messages.last;
    expect(proof.kind, ChatMessageKind.proof);
    expect(proof.questBadgeTitle, 'Kütüphane Sprinti');
    expect(proof.hasPhoto, isTrue);
    expect(find.textContaining('Kanıtı'), findsWidgets);
  });

  testWidgets('anı albümü filtreleri kanıt ve anıları ayırır', (
    WidgetTester tester,
  ) async {
    final DateTime today = DateTime.now();
    initialState = initialState.withCouple(
      initialState.couple.copyWith(
        messages: <ChatMessage>[
          ChatMessage(
            id: 'album-proof',
            senderId: CouplePartner.yusufId,
            createdAt: today,
            photoDataOrUrl: PhotoPreset.all[0].source,
            photoCaption: 'Ders kanıtı',
            questBadgeTitle: 'Kütüphane',
            kind: ChatMessageKind.proof,
          ),
          ChatMessage(
            id: 'album-memory',
            senderId: CouplePartner.ceydaId,
            createdAt: today,
            photoDataOrUrl: PhotoPreset.all[1].source,
            photoCaption: 'İlk kahve',
            kind: ChatMessageKind.photo,
          ),
        ],
      ),
    );
    await pump(tester, const ChatScreen());

    await tester.tap(find.byKey(const Key('open-album')));
    await tester.pumpAndSettle();
    expect(find.text('Anı Albümü'), findsOneWidget);
    expect(find.text('Çift Anılarımız'), findsOneWidget);
    expect(find.text('Plan & Görev Kanıtları'), findsOneWidget);
    expect(find.text('2/2 kare · 0 favori'), findsOneWidget);
    expect(find.byKey(const Key('album-album-proof')), findsOneWidget);
    expect(find.byKey(const Key('album-album-memory')), findsOneWidget);

    await tester.tap(find.byKey(const Key('album-filter-proofs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-album-proof')), findsOneWidget);
    expect(find.byKey(const Key('album-album-memory')), findsNothing);

    await tester.tap(find.byKey(const Key('album-filter-memories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-album-proof')), findsNothing);
    expect(find.byKey(const Key('album-album-memory')), findsOneWidget);

    await tester.tap(find.byKey(const Key('album-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('2/2 kare · 0 favori'), findsOneWidget);
  });
}
