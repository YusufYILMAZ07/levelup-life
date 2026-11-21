import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/theme/theme.dart';
import 'package:levelup_life/core/utils/date_x.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:levelup_life/domain/entities/entities.dart';
import 'package:levelup_life/presentation/dashboard/dashboard_screen.dart';
import 'package:levelup_life/presentation/progress/progress_screen.dart';
import 'package:levelup_life/presentation/progress/widgets/progress_range_toggle.dart';
import 'package:levelup_life/presentation/progress/widgets/streak_calendar.dart';
import 'package:levelup_life/presentation/progress/widgets/xp_trend_chart.dart';
import 'package:levelup_life/presentation/shell/app_shell.dart';

/// Testlerde "şimdi" sabittir: takvim ve grafik etiketleri deterministik olur.
final DateTime _now = DateTime(2026, 11, 15, 12);

const UserSetup _setup = UserSetup(
  displayName: 'Yusuf Kaya',
  role: LifeRole.student,
  studyField: 'Bilgisayar Mühendisliği',
  gradeYear: 2,
  goals: <GoalType>{GoalType.academic},
  tempo: DailyTempo.balanced,
);

/// Geçmişi bugüne göre kuran hazır durum: son 3 gün 20 + 30 + 40 XP.
GameState _buildState({bool withHistory = true}) {
  DailyXpLog log = DailyXpLog.empty;
  if (withHistory) {
    log = log
        .record(at: DateX.shiftDays(_now, -2), xp: 20)
        .record(at: DateX.shiftDays(_now, -1), xp: 30)
        .record(at: _now, xp: 40);
  }

  final UserProfile profile =
      UserProfile.starter(
        id: 'user-progress',
        displayName: 'Yusuf Kaya',
        role: LifeRole.student,
        focusStats: const <StatKey>{StatKey.intelligence},
        createdAt: DateTime(2026, 11, 1),
      ).copyWith(
        onboardingCompleted: true,
        totalXp: log.totalXp,
        xpLog: log,
        streak: Streak(
          currentDays: log.currentStreakOn(_now),
          longestDays: log.longestStreak,
          lastActiveDay: log.lastActiveDay,
          totalActiveDays: log.activeDays,
        ),
      );

  return GameState(setup: _setup, profile: profile);
}

Future<void> _pumpHost(
  WidgetTester tester,
  Widget home, {
  required GameState state,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 950));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gameStoreProvider.overrideWithValue(MemoryGameStore(state))],
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpProgress(WidgetTester tester, {bool withHistory = true}) =>
    _pumpHost(
      tester,
      ProgressScreen(now: _now),
      state: _buildState(withHistory: withHistory),
    );

void main() {
  testWidgets('özet kartları, XP grafiği ve takvim birlikte görünür', (
    WidgetTester tester,
  ) async {
    await _pumpProgress(tester);

    expect(find.text('İlerleme'), findsOneWidget);
    expect(find.textContaining('Toplam 90 XP'), findsOneWidget);
    expect(find.text('3 gün seri'), findsOneWidget);
    expect(find.byType(XpTrendChart), findsOneWidget);
    expect(find.text('7 gün'), findsOneWidget);
    expect(find.text('90 XP'), findsOneWidget);
    expect(find.text('3 / 7 gün aktif'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(StreakCalendar),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Seri Takvimi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('streak-cell-2026-11-15')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('streak-cell-2026-11-13')),
      findsOneWidget,
    );
  });

  testWidgets('7 gün varsayılan, 30 güne geçince seri uzar', (
    WidgetTester tester,
  ) async {
    await _pumpProgress(tester);

    expect(
      tester.widget<XpTrendChart>(find.byType(XpTrendChart)).series,
      hasLength(ProgressRange.week.days),
    );

    await tester.tap(find.byKey(const Key('progress-range-month')));
    await tester.pumpAndSettle();

    final XpTrendChart chart = tester.widget<XpTrendChart>(
      find.byType(XpTrendChart),
    );
    expect(chart.series, hasLength(ProgressRange.month.days));
    expect(chart.range, ProgressRange.month);
    expect(find.text('30 gün'), findsOneWidget);
    expect(find.text('3 / 30 gün aktif'), findsOneWidget);

    // Son nokta her zaman bugündür ve bugünün XP'sini taşır.
    expect(DateX.isSameDay(chart.series.last.day, _now), isTrue);
    expect(chart.series.last.xp, 40);
  });

  testWidgets('boş geçmişte grafik durur ama ipucu gösterilir', (
    WidgetTester tester,
  ) async {
    await _pumpProgress(tester, withHistory: false);

    expect(find.byType(XpTrendChart), findsOneWidget);
    expect(find.textContaining('Henüz XP kaydı yok'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('0 gün seri'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(StreakCalendar),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('streak-cell-2026-11-15')),
      findsOneWidget,
    );
  });

  testWidgets('alt sekme çubuğu Bugün ↔ Gelişim ↔ Sohbet ↔ İlerleme geçişi', (
    WidgetTester tester,
  ) async {
    await _pumpHost(tester, const AppShell(), state: _buildState());

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));

    expect(stack().index, 0);

    // Regresyon: alt çubuk tüm yüksekliği kaplamamalı, gövdeye yer kalmalı.
    final double bodyHeight = tester.getSize(find.byType(IndexedStack)).height;
    expect(bodyHeight, greaterThan(300));
    expect(
      tester.getSize(find.byType(DashboardScreen)).height,
      greaterThan(300),
    );
    expect(find.textContaining('Yusuf'), findsWidgets);

    // Çift sürümü sekmeleri: dört sekme de mevcut.
    expect(find.byKey(const Key('nav-development')), findsOneWidget);
    expect(find.byKey(const Key('nav-chat')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-development')));
    await tester.pumpAndSettle();
    expect(stack().index, 1);

    await tester.tap(find.byKey(const Key('nav-chat')));
    await tester.pumpAndSettle();
    expect(stack().index, 2);

    await tester.tap(find.byKey(const Key('nav-progress')));
    await tester.pumpAndSettle();
    expect(stack().index, 3);

    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(stack().index, 0);
  });
}
