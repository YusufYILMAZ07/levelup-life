import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/game_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme.dart';
import 'data/game_store.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yerel store açılışta bir kez hazırlanır → GameController senkron kalır,
  // uygulama "loading" ekranı göstermeden doğru ekranla açılır.
  final GameStore store = await LocalGameStore.open();
  runApp(
    ProviderScope(
      overrides: [gameStoreProvider.overrideWithValue(store)],
      child: const LevelUpApp(),
    ),
  );
}

/// Uygulama kökü.
///
/// Router görevi `_RootGate` görür: onboarding tamamlanmadıysa sihirbaz,
/// tamamlandıysa alt sekmeli kabuk ([AppShell]). `GameState` değiştiğinde
/// geçiş animasyonlu olur.
class LevelUpApp extends StatelessWidget {
  const LevelUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool onboarded = ref.watch(isOnboardedProvider);
    return AnimatedSwitcher(
      duration: AppMotion.slow,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: onboarded
          ? const AppShell(key: ValueKey<String>('shell'))
          : const OnboardingScreen(key: ValueKey<String>('onboarding')),
    );
  }
}
