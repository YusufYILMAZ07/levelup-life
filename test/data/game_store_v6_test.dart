import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/core/constants/app_constants.dart';
import 'package:levelup_life/data/game_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalGameStore v6', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test(
      'save gerçek disk yazımı bitince resolve olur ve yeniden yüklenir',
      () async {
        final LocalGameStore store = await LocalGameStore.open();
        final GameState state = CoupleBootstrap.initialState();

        await store.save(state);
        // Debounce sonrası gerçek yazım tamamlandı.
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? raw = prefs.getString(AppConstants.cacheGameState);
        expect(raw, isNotNull);
        expect(raw, contains('schema_version'));
        expect(raw, contains('"state"'));

        final LocalGameStore reopened = await LocalGameStore.open();
        expect(reopened.load()?.isCoupleEdition, isTrue);
        expect(
          reopened.load()?.couple.messages.length,
          state.couple.messages.length,
        );
      },
    );

    test('bozuk JSON yedeğe taşınır, uygulama temiz açılır', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.cacheGameState: '{bozuk-json',
      });

      final LocalGameStore store = await LocalGameStore.open();

      expect(store.load(), isNull);
      expect(store.lastLoadError, contains('cache.game_state.corrupted'));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalGameStore.corruptedBackupKey), '{bozuk-json');
      expect(prefs.getString(AppConstants.cacheGameState), isNull);
    });

    test('clear bekleyen yazımı iptal eder ve anahtarı siler', () async {
      final LocalGameStore store = await LocalGameStore.open();
      await store.save(CoupleBootstrap.initialState());
      await store.clear();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.cacheGameState), isNull);
      expect(store.load(), isNull);
    });
  });
}
