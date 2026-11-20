import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/game_controller.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/main.dart';
import 'package:levelup_life/presentation/dashboard/dashboard_screen.dart';
import 'package:levelup_life/presentation/onboarding/onboarding_screen.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 950));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gameStoreProvider.overrideWithValue(MemoryGameStore())],
      child: const LevelUpApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 4 adımı gerçek kullanıcı akışıyla tamamlar.
Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('onboarding-name-field')),
    'Yusuf',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('role-student')));
  await tester.pump();
  await tester.tap(find.text('Devam Et'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Bilgisayar Mühendisliği'));
  await tester.pump();
  await tester.tap(find.text('Devam Et'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('goal-fitness')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('goal-career')));
  await tester.pump();
  await tester.tap(find.text('Devam Et'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Maceraya Başla!'));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester, Type screenType) =>
    ProviderScope.containerOf(tester.element(find.byType(screenType)));

/// Lazy listelerde hedef widget'ı görünür olana kadar aşağı kaydırır.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final Finder scrollable = find.byType(Scrollable).first;
  for (int attempt = 0; attempt < 12 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('uygulama onboarding ile açılır ve isim olmadan ilerlemez',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Sen kimsin?'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('Sen kimsin?'), findsOneWidget);
    expect(find.text('Devam etmek için adını yaz.'), findsOneWidget);
  });

  testWidgets('onboarding cevapları dashboard ve kişisel görevleri üretir',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await _completeOnboarding(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.textContaining('Yusuf'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Bugünün Görevleri'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bugünün Görevleri'), findsOneWidget);

    final ProviderContainer container =
        _container(tester, DashboardScreen);
    final gameState = container.read(gameProvider);
    expect(gameState.setup?.studyField, 'Bilgisayar Mühendisliği');
    expect(gameState.profile?.onboardingCompleted, isTrue);
    expect(gameState.quests, isNotEmpty);
    expect(
      gameState.quests.every(
        (quest) => <String>{'fitness', 'career', 'core'}
            .contains(quest.tags.first),
      ),
      isTrue,
    );
  });

  testWidgets('görev tamamlamak XP kazandırır ve görevi işaretler',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await _completeOnboarding(tester);

    final ProviderContainer container =
        _container(tester, DashboardScreen);
    expect(container.read(gameProvider).profile!.totalXp, 0);

    final Finder completeButton = find.text('Tamamla');
    await _scrollTo(tester, completeButton);
    await tester.tap(completeButton.first);
    await tester.pumpAndSettle();

    // Görev doğrulama modalı: sayaç varsa demoyla hızlı geç, sonra onayla.
    final Finder timerDemo = find.byKey(const Key('verification-timer-demo'));
    if (timerDemo.evaluate().isNotEmpty) {
      await tester.tap(timerDemo);
      await tester.pump(const Duration(seconds: 6));
    }
    final Finder confirm = find.byKey(const Key('verification-confirm'));
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final gameState = container.read(gameProvider);
    expect(gameState.profile!.totalXp, greaterThan(0));
    expect(
      gameState.quests.where((quest) => quest.isCompleted),
      hasLength(1),
    );
    expect(find.textContaining('XP ·'), findsWidgets);
  });

  testWidgets('ayarlardan hedefler sıfırlanınca onboarding geri gelir',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enerji modu'), findsOneWidget);

    await tester.tap(find.text('Hedeflerimi sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('Yeniden başlamak istiyor musun?'), findsOneWidget);

    await tester.tap(find.text('Evet, sıfırla'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    final ProviderContainer container =
        _container(tester, OnboardingScreen);
    expect(container.read(gameProvider).profile, isNull);
    expect(container.read(gameProvider).quests, isEmpty);
  });

  testWidgets('modalden özel görev eklenince listeye girer',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await _completeOnboarding(tester);

    final Finder addButton = find.byKey(const Key('add-quest-button'));
    await _scrollTo(tester, addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Yeni Görev / Hedef Ekle'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('add-quest-title')),
      'Akşam yürüyüşü',
    );
    await tester.pump();

    final Finder submit = find.text('Görevi Ekle');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final ProviderContainer container =
        _container(tester, DashboardScreen);
    final Quest added = container
        .read(gameProvider)
        .quests
        .firstWhere((Quest quest) => quest.title == 'Akşam yürüyüşü');
    expect(added.cadence, QuestCadence.oneOff);
    expect(added.baseXp, greaterThan(0));
  });
}
