import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_services.dart';
import 'application/couple_bootstrap.dart';
import 'application/game_controller.dart';
import 'application/game_state.dart';
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
  // bulut yapılandırılmamışsa uygulama %100 yerel çalışır. PIN hash'i
  // `flutter_secure_storage` içinden okunur.
  final AppSettingsStore settingsStore = await LocalAppSettingsStore.open();
  final AppSettings settings = settingsStore.load();
  final String loadError = store is LocalGameStore
      ? (store.lastLoadError ?? '')
      : '';
  // Hediye modu: depo boşsa veya yalnızca yarım kalmış (onboarding
  // tamamlanmamış) bir kayıt varsa çift sürümü tohumu yazılır.
  final GameState? existing = store.load();
  // Bozuk veri durumunda sessiz sıfırlama YAPILMAZ; kullanıcıya kurtarma /
  // temiz başlatma seçeneği `_RecoveryGate` ile sunulur.
  if (loadError.isEmpty) {
    if (existing == null ||
        (!existing.isCoupleEdition && !existing.isOnboarded)) {
      // Kritik ilk kayıt: debounce beklemeden diske yazılır.
      await store.save(CoupleBootstrap.initialState(), flush: true);
    } else if (!existing.isCoupleEdition && existing.isOnboarded) {
      // v6: eski tek oyunculu kayıt **ezilmez**; cihaz sahibinin koltuğuna
      // taşınır (profil, XP, görevler ve sohbet korunur).
      await store.save(
        CoupleBootstrap.migrateFromLegacy(
          existing,
          deviceRole: settings.deviceRole,
        ),
        flush: true,
      );
    }
  }
  // Güvenli depo (Keychain/Keystore) açılamadıysa PIN kilidi sessizce
  // varsayılana dönmez; nedeni loglanır (ayarlar ekranı da gösterir).
  final String? settingsError = settingsStore.lastError;
  if (settingsError != null && settingsError.isNotEmpty) {
    debugPrint('[main] $settingsError');
  }
  runApp(
    ProviderScope(
      overrides: [
        gameStoreProvider.overrideWithValue(store),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
      ],
      child: LevelUpApp(loadError: loadError.isEmpty ? null : loadError),
    ),
  );
}

/// Uygulama kökü.
///
/// Router görevi `_RootGate` görür: onboarding tamamlanmadıysa sihirbaz,
/// tamamlandıysa alt sekmeli kabuk ([AppShell]). `GameState` değiştiğinde
/// geçiş animasyonlu olur.
class LevelUpApp extends StatelessWidget {
  const LevelUpApp({this.loadError, super.key});

  /// Açılışta `LocalGameStore.lastLoadError` varsa kurtarma seçeneği sunulur.
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const AppScrollBehavior(),
      builder: (BuildContext context, Widget? child) =>
          InAppNotificationHost(child: child ?? const SizedBox.shrink()),
      home: AppServices(
        child: _RecoveryGate(loadError: loadError, child: const _RootGate()),
      ),
    );
  }
}

/// Bozuk veri saptandığında sessiz sıfırlama yapmaz; kullanıcıya seçenek sunar.
class _RecoveryGate extends ConsumerStatefulWidget {
  const _RecoveryGate({required this.child, this.loadError});

  final Widget child;
  final String? loadError;

  @override
  ConsumerState<_RecoveryGate> createState() => _RecoveryGateState();
}

class _RecoveryGateState extends ConsumerState<_RecoveryGate> {
  @override
  void initState() {
    super.initState();
    if (widget.loadError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerRecovery());
    }
  }

  Future<void> _offerRecovery() async {
    if (!mounted) return;
    final bool reset =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Veri kurtarma gerekli'),
            content: Text(
              'Kayıt okunamadı. Orijinal veri güvenli yedeğe alındı.\n\n'
              '${widget.loadError}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Şimdilik devam'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Temiz başlat'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !reset) return;
    await ref.read(gameProvider.notifier).resetJourney();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
