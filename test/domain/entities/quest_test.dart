import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/energy_mode.dart';
import 'package:levelup_life/domain/entities/quest.dart';
import 'package:levelup_life/domain/entities/stat_key.dart';
import 'package:levelup_life/domain/entities/verification.dart';

Quest buildQuest({
  EnergyMode energyMode = EnergyMode.balanced,
  MicroVariant? microVariant,
}) {
  return Quest(
    id: 'quest-1',
    title: 'Lineer cebir 3. bölüm',
    summary: 'Vektör uzayları konusunu bitir.',
    stat: StatKey.intelligence,
    category: QuestCategory.academic,
    difficulty: QuestDifficulty.moderate,
    baseXp: 65,
    estimatedMinutes: 45,
    verification: QuestVerification.timer(minutes: 45),
    createdAt: DateTime(2026, 11, 15, 9),
    energyMode: energyMode,
    microVariant: microVariant,
    tags: const <String>{'ders', 'odak'},
  );
}

const MicroVariant micro = MicroVariant(
  title: 'Tek konu özetini oku',
  minutes: 10,
  baseXp: 20,
  summary: 'Sadece özeti oku.',
);

void main() {
  group('enerji adaptasyonu', () {
    test('dengeli modda ham değerler kullanılır', () {
      final Quest quest = buildQuest(microVariant: micro);

      expect(quest.isEnergyAdapted, isFalse);
      expect(quest.isMicro, isFalse);
      expect(quest.effectiveTitle, quest.title);
      expect(quest.effectiveMinutes, 45);
      expect(quest.effectiveBaseXp, 65);
    });

    test('düşük enerjide mikro varyant devreye girer', () {
      final Quest quest = buildQuest(
        energyMode: EnergyMode.lowEnergy,
        microVariant: micro,
      );

      expect(quest.isEnergyAdapted, isTrue);
      expect(quest.isMicro, isTrue);
      expect(quest.effectiveTitle, micro.title);
      expect(quest.effectiveSummary, micro.summary);
      expect(quest.effectiveMinutes, 10);
      expect(quest.effectiveBaseXp, 20);
    });

    test('mikro varyant yoksa ham görev korunur', () {
      final Quest quest = buildQuest(energyMode: EnergyMode.overloaded);

      expect(quest.isEnergyAdapted, isTrue);
      expect(quest.isMicro, isFalse);
      expect(quest.effectiveBaseXp, 65);
      expect(quest.effectiveMinutes, 45);
    });

    test('applyEnergyMode yeni örnek üretir, orijinali bozmaz', () {
      final Quest quest = buildQuest(microVariant: micro);
      final Quest adapted = quest.applyEnergyMode(EnergyMode.lowEnergy);

      expect(identical(adapted, quest), isFalse);
      expect(adapted.energyMode, EnergyMode.lowEnergy);
      expect(adapted.effectiveBaseXp, 20);
      expect(quest.energyMode, EnergyMode.balanced);
      expect(quest.effectiveBaseXp, 65);
    });

    test('mikro varyantın doğrulaması varsa o kullanılır', () {
      const MicroVariant withVerification = MicroVariant(
        title: 'Mikro adım',
        minutes: 5,
        baseXp: 10,
        verification: ManualVerification(requiresNote: true),
      );
      final Quest quest = buildQuest(
        energyMode: EnergyMode.lowEnergy,
        microVariant: withVerification,
      );

      expect(quest.effectiveVerification.type, VerificationType.manual);
      expect(quest.requiresProof, isFalse);
    });
  });

  group('türetilmiş değerler', () {
    test('xpPerMinute etkin değerlerden hesaplanır', () {
      final Quest quest = buildQuest(
        energyMode: EnergyMode.lowEnergy,
        microVariant: micro,
      );

      expect(quest.xpPerMinute, closeTo(2.0, 0.001));
    });

    test('requiresProof doğrulama tipine bağlı', () {
      expect(buildQuest().requiresProof, isTrue);
      expect(
        buildQuest().copyWith(verification: QuestVerification.manual())
            .requiresProof,
        isFalse,
      );
    });

    test('isQuestline questlineId varlığına bağlı', () {
      expect(buildQuest().isQuestline, isFalse);
      expect(buildQuest().copyWith(questlineId: 'line-7').isQuestline, isTrue);
    });
  });

  group('durum geçişleri', () {
    test('start ve complete durumu günceller', () {
      final Quest started = buildQuest().start();
      expect(started.status, QuestStatus.inProgress);
      expect(started.isOpen, isTrue);

      final DateTime done = DateTime(2026, 11, 15, 11);
      final Quest completed = started.complete(at: done, reflection: 'İyi gitti');

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, done);
      expect(completed.reflection, 'İyi gitti');
      expect(completed.isOpen, isFalse);
    });

    test('expire durumu günceller', () {
      expect(buildQuest().expire().status, QuestStatus.expired);
    });
  });

  group('serileştirme', () {
    test('JSON round-trip eşitlik korur', () {
      final Quest quest = buildQuest(
        energyMode: EnergyMode.lowEnergy,
        microVariant: micro,
      ).copyWith(dueAt: DateTime(2026, 11, 16, 18), streakCritical: true);

      expect(Quest.fromJson(quest.toJson()), quest);
    });

    test('bilinmeyen enum değerleri güvenli varsayılana düşer', () {
      final Quest quest = Quest.fromJson(<String, dynamic>{
        'id': 'q-2',
        'title': 'Su iç',
        'summary': '2 litre',
        'stat': 'YOK',
        'category': 'health',
        'difficulty': 'imkansiz',
        'base_xp': 15,
        'estimated_minutes': 0,
        'verification': <String, dynamic>{'type': 'manual'},
        'created_at': '2026-11-15T09:00:00.000',
      });

      expect(quest.stat, StatKey.vitality); // kategorinin varsayılanı
      expect(quest.difficulty, QuestDifficulty.light);
      expect(quest.estimatedMinutes, 15);
      expect(quest.status, QuestStatus.active);
      expect(quest.energyMode, EnergyMode.balanced);
    });
  });
}
