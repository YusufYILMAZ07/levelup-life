import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_services.dart';
import 'application/couple_bootstrap.dart';
import 'application/game_controller.dart';
import 'application/pin_lock_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme.dart';
import 'data/game_store.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/widgets/in_app_notification_banner.dart';
import 'presentation/widgets/pin_lock_screen.dart';
import 'services/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yerel store açılışta bir kez hazırlanır → GameController senkron kalır,
  // uygulama "loading" ekranı göstermeden doğru ekranla açılır.
  final GameStore store = await LocalGameStore.open();
  // Cihaz tercihleri (bildirim / PIN / Supabase / avatarlar) ayrı saklanır;
  // bulut yapılandırılmamışsa uygulama %100 yerel çalışır.
  final AppSettingsStore settingsStore = await LocalAppSettingsStore.open();
  // Hediye modu: depo boşsa (veya eski tek oyunculu kayıt varsa) çift sürümü
  // tohumu yazılır → uygulama Yusuf & Ceyda profilleriyle açılır.
  if (store.load()?.isCoupleEdition != true) {
    await store.save(CoupleBootstrap.initialState());
  }
  runApp(
    ProviderScope(
      overrides: [
        gameStoreProvider.overrideWithValue(store),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
      ],
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
      scrollBehavior: const AppScrollBehavior(),
      builder: (BuildContext context, Widget? child) =>
          InAppNotificationHost(child: child ?? const SizedBox.shrink()),
      home: const AppServices(child: _RootGate()),
    );
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool pinEnabled = ref.watch(
      appSettingsProvider.select(
        (AppSettings settings) => settings.pinLockEnabled,
      ),
    );
    final bool locked = ref.watch(pinLockProvider);
    if (pinEnabled && locked) {
      return const PinLockScreen(key: ValueKey<String>('pin-lock'));
    }
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
