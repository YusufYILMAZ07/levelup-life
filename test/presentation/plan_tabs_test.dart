import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/development/development_screen.dart';
import 'package:levelup_life/presentation/development/widgets/reward_capsules_tab.dart';
import 'package:levelup_life/presentation/development/widgets/weekly_plan_tab.dart';

/// Haftalık plan testlerinde sabit "şimdi": 17 Kasım 2026, Salı 14:30.
final DateTime _tuesday = DateTime(2026, 11, 17, 14, 30);

GameState _state({CoupleState? couple}) {
  final GameState base = CoupleBootstrap.initialState(now: _tuesday);
  return couple == null ? base : base.withCouple(couple);
}

/// Demo seed'in puanlarını sıfırlar (kapsül eşikleri temiz ölçülsün).
CoupleState _zeroCouple() =>
    CoupleBootstrap.initialState(now: _tuesday).couple.copyWith(
      rubricScores: const <String, int>{},
      bonusActions: const <BonusActionLog>[],
    );

/// Sıfır puandan her iki partnerde tüm sütunlardan 3 puan → 450 birleşik puan.
CoupleState _richCouple() {
  final CoupleState couple = _zeroCouple();
  final Map<String, int> scores = <String, int>{
    for (final String id in CouplePartner.ids)
      for (final StatKey stat in StatKey.values)
        CoupleState.rubricKey(id, stat, _tuesday): 3,
  };
  return couple.copyWith(rubricScores: scores);
}

Future<MemoryGameStore> _pump(
  WidgetTester tester,
  Widget child, {
  GameState? initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 950));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final MemoryGameStore store = MemoryGameStore(initial ?? _state());
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
              children: <Widget>[child],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

CoupleState _couple(WidgetTester tester, Finder finder) {
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(finder),
  );
  return container.read(gameProvider).couple;
}

void main() {
  group('haftalık plan', () {
    testWidgets('seçili gün varsayılan olarak bugündür ve iki partnerin '
        'bloklarını gösterir', (WidgetTester tester) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));

      expect(find.text('Yan Yana Akış'), findsOneWidget);
      expect(find.text('Salı · blok → tamamla / kanıt'), findsOneWidget);
      expect(find.text('Okulda · Bilgisayar Müh. Dersi'), findsOneWidget);
      expect(find.text('Sporda · Antrenman & Mobilite'), findsOneWidget);
      expect(find.text('0/3'), findsNWidgets(2));
    });

    testWidgets('gün değiştirince akış o güne göre yenilenir', (
      WidgetTester tester,
    ) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));

      await tester.tap(find.byKey(const Key('schedule-day-3')));
      await tester.pumpAndSettle();

      expect(find.text('Çarşamba · blok → tamamla / kanıt'), findsOneWidget);
      expect(find.text('Okulda · Bilgisayar Müh. Dersi'), findsNothing);
      expect(find.text('Okulda · Olasılık & İstatistik'), findsOneWidget);

      await tester.tap(find.byKey(const Key('schedule-day-6')));
      await tester.pumpAndSettle();
      expect(find.text('Cumartesi · blok → tamamla / kanıt'), findsOneWidget);
      expect(find.textContaining('Birlikte'), findsWidgets);
    });

    testWidgets('yeni plan bloğu her iki partner için kaydedilir', (
      WidgetTester tester,
    ) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));

      await tester.tap(find.byKey(const Key('add-schedule-button')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Plan'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('schedule-title-field')),
        'Birlikte Koşu',
      );
      await tester.pump();
      final Finder target = find.byKey(const Key('schedule-target-both'));
      final Finder category = find.byKey(
        const Key('schedule-category-workout'),
      );
      final Finder save = find.byKey(const Key('schedule-save-button'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.textContaining('eklendi'), findsOneWidget);
      final List<ScheduleBlock> added =
          _couple(tester, find.byType(WeeklyPlanTab)).scheduleBlocks
              .where((ScheduleBlock block) => block.title == 'Birlikte Koşu')
              .toList();
      expect(added, hasLength(2));
      expect(
        added.map((ScheduleBlock block) => block.partnerId).toSet(),
        CouplePartner.ids.toSet(),
      );
      expect(added.first.category, ScheduleCategory.workout);
      expect(added.first.weekday, 2);
      expect(added.first.startMinutes, 540);
      expect(find.text('Birlikte Koşu'), findsNWidgets(2));
    });
  });

  group('blok aksiyonları', () {
    Future<void> openActions(WidgetTester tester) async {
      final Finder tile = find.byKey(
        const Key('schedule-block-plan-yusuf-2-840'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('tamamla aksiyonu +25 XP verir, sohbete rozet düşer', (
      WidgetTester tester,
    ) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));
      final CoupleState before = _couple(tester, find.byType(WeeklyPlanTab));

      await openActions(tester);
      expect(find.text('Tamamla (+25 XP)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('schedule-action-complete')));
      await tester.pumpAndSettle();

      expect(
        find.text('Okulda · Bilgisayar Müh. Dersi tamamlandı · +25 XP'),
        findsOneWidget,
      );
      final CoupleState after = _couple(tester, find.byType(WeeklyPlanTab));
      expect(
        after.blockById('plan-yusuf-2-840')!.isCompletedOn(_tuesday),
        isTrue,
      );
      expect(after.messages.length, before.messages.length + 1);
      expect(after.messages.last.kind, ChatMessageKind.questShare);
      expect(after.messages.last.earnedPoints, SchedulePlanner.completionXp);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('kanıt aksiyonu sohbete fotoğraflı kanıt bırakır', (
      WidgetTester tester,
    ) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));

      await openActions(tester);
      await tester.tap(find.byKey(const Key('schedule-action-proof')));
      await tester.pumpAndSettle();

      expect(find.text('Kanıt sohbete gönderildi 📸'), findsOneWidget);
      final ChatMessage proof = _couple(
        tester,
        find.byType(WeeklyPlanTab),
      ).messages.last;
      expect(proof.kind, ChatMessageKind.proof);
      expect(proof.senderId, CouplePartner.yusufId);
      expect(proof.questBadgeTitle, 'Okulda · Bilgisayar Müh. Dersi');
      expect(proof.hasPhoto, isTrue);
    });

    testWidgets('sil aksiyonu bloğu plandan kaldırır', (
      WidgetTester tester,
    ) async {
      await _pump(tester, WeeklyPlanTab(now: _tuesday));

      await openActions(tester);
      await tester.tap(find.byKey(const Key('schedule-action-delete')));
      await tester.pumpAndSettle();

      expect(find.textContaining('plandan kaldırıldı'), findsOneWidget);
      expect(
        _couple(
          tester,
          find.byType(WeeklyPlanTab),
        ).blockById('plan-yusuf-2-840'),
        isNull,
      );
      expect(find.text('Okulda · Bilgisayar Müh. Dersi'), findsNothing);
    });
  });

  group('ödül kapsülleri', () {
    testWidgets('puan yetmezken kapsüller kilitli görünür', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const RewardCapsulesTab(),
        initial: _state(couple: _zeroCouple()),
      );
      expect(find.text('Birleşik Gelişim Puanı'), findsOneWidget);
      expect(find.text('Kahve & Tatlı Molası Kapsülü'), findsOneWidget);
      expect(
        find.text('Ceyda\'nın Büyük Doğum Günü Sürpriz Kapsülü'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('open-capsule-capsule-coffee')),
        findsNothing,
      );
      expect(find.byKey(const Key('add-capsule-button')), findsOneWidget);
    });

    testWidgets('puan dolunca kapsül açılır ve kutlama modalı gösterilir', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const RewardCapsulesTab(),
        initial: _state(couple: _richCouple()),
      );

      expect(find.text('450'), findsOneWidget);
      final Finder open = find.byKey(const Key('open-capsule-capsule-coffee'));
      expect(open, findsOneWidget);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(find.text('Kapsül Açıldı! 🎉'), findsOneWidget);
      expect(find.textContaining('telefonlar çantada'), findsWidgets);
      await tester.tap(find.byKey(const Key('capsule-reveal-close')));
      await tester.pumpAndSettle();

      expect(find.text('Kapsül Açıldı! 🎉'), findsNothing);
      expect(
        find.byKey(const Key('open-capsule-capsule-coffee')),
        findsNothing,
      );
      expect(
        _couple(
          tester,
          find.byType(RewardCapsulesTab),
        ).capsuleById('capsule-coffee')!.isOpened,
        isTrue,
      );
      expect(find.textContaining('Kapsülü açtın!'), findsOneWidget);
    });
  });

  group('yeni kapsül ve gelişim ekranı', () {
    testWidgets('yeni kapsül alt sayfası kapsülü rafa ekler', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const RewardCapsulesTab());

      await tester.tap(find.byKey(const Key('add-capsule-button')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Ödül Kapsülü'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('capsule-title-field')),
        'Piknik Günü',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('capsule-emoji-🍿')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('capsule-points-750')));
      await tester.pump();
      final Finder save = find.byKey(const Key('capsule-save-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('🍿 Piknik Günü rafa eklendi'), findsOneWidget);
      final CoupleState couple = _couple(
        tester,
        find.byType(RewardCapsulesTab),
      );
      final RewardCapsule added = couple.rewardCapsules.firstWhere(
        (RewardCapsule capsule) => capsule.title == 'Piknik Günü',
      );
      expect(added.emoji, '🍿');
      expect(added.requiredPoints, 750);
      expect(added.isCustom, isTrue);
    });

    testWidgets('gelişim ekranı sekmeleri arasında geçiş yapar', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameStoreProvider.overrideWithValue(MemoryGameStore(_state())),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DevelopmentScreen(now: _tuesday),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yan Yana Akış'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dev-tab-rewards')));
      await tester.pumpAndSettle();
      expect(find.text('Birleşik Gelişim Puanı'), findsOneWidget);
      expect(find.text('Yan Yana Akış'), findsNothing);

      await tester.tap(find.byKey(const Key('dev-tab-daily')));
      await tester.pumpAndSettle();
      expect(find.text('Günlük Gelişim Rubriği'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dev-tab-week')));
      await tester.pumpAndSettle();
      expect(find.text('Yan Yana Akış'), findsOneWidget);
    });
  });
}
