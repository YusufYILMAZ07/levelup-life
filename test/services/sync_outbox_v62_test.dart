import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/application/couple_bootstrap.dart';
import 'package:levelup_life/application/game_state.dart';
import 'package:levelup_life/services/sync_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v6.2: outbox yazım/silme yarışları ve kimlik kırpma regresyonları.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final GameState state = CoupleBootstrap.initialState(
    now: DateTime(2026, 11, 23, 9),
  );

  Future<SharedPreferences> freshPreferences() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SharedPreferences.getInstance();
  }

  test('clear() sırada bekleyen saveDirtyState yazımlarını ezer', () async {
    final SharedPreferences prefs = await freshPreferences();
    final LocalSyncOutbox outbox = await LocalSyncOutbox.open();

    // Yazımlar await edilmeden kuyruğa alınır (kapanma anındaki gerçek yarış).
    final List<Future<void>> writes = <Future<void>>[
      for (int i = 0; i < 8; i++) outbox.saveDirtyState(state),
    ];
    final Future<void> cleared = outbox.clear();
    await Future.wait(<Future<void>>[...writes, cleared]);
    // Kuyruk tamamen boşaldıktan sonra tek bir yazım bile anahtarı
    // yeniden oluşturmamalı.
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString(LocalSyncOutbox.dirtyKey), isNull);
    expect(outbox.hasDirtyState, isFalse);

    final LocalSyncOutbox reopened = await LocalSyncOutbox.open();
    expect(reopened.hasDirtyState, isFalse);
  });

  test('clearDirtyState() bekleyen yazımı bekler ve taslağı siler', () async {
    final SharedPreferences prefs = await freshPreferences();
    final LocalSyncOutbox outbox = await LocalSyncOutbox.open();

    final Future<void> write = outbox.saveDirtyState(state);
    final Future<void> cleared = outbox.clearDirtyState();
    await cleared;
    // `clearDirtyState()` döndüğünde diskte kirli taslak kalmamış olmalı.
    expect(prefs.getString(LocalSyncOutbox.dirtyKey), isNull);
    await write;
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(LocalSyncOutbox.dirtyKey), isNull);
    expect(outbox.dirtyState, isNull);
  });

  test('dequeueDelete kimliği trim ederek eşleştirir', () async {
    final SharedPreferences prefs = await freshPreferences();
    final LocalSyncOutbox outbox = await LocalSyncOutbox.open();

    await outbox.enqueueDelete('  msg-1  ');
    expect(outbox.pendingDeletes, <String>{'msg-1'});

    await outbox.dequeueDelete(' msg-1 ');
    expect(outbox.pendingDeletes, isEmpty);
    expect(
      _decodedList(prefs.getString(LocalSyncOutbox.pendingDeletesKey)),
      isEmpty,
    );

    // Boş kimlik yazma/silme denemesi diske yeni bir öğe eklemez.
    await outbox.enqueueDelete('   ');
    expect(
      _decodedList(prefs.getString(LocalSyncOutbox.pendingDeletesKey)),
      isEmpty,
    );
    await outbox.dequeueDelete('   ');
    expect(outbox.pendingDeletes, isEmpty);
  });
}

List<String> _decodedList(String? raw) {
  if (raw == null || raw.isEmpty) return const <String>[];
  final Object? decoded = jsonDecode(raw);
  if (decoded is! List) return const <String>[];
  return <String>[
    for (final Object? item in decoded)
      if (item != null) item.toString(),
  ];
}
