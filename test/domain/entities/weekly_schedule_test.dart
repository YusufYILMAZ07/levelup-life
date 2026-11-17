import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/domain/entities/entities.dart';

/// Haftalık planın saf zaman hesapları: aktif blok, ilerleme, ortak boşluklar
/// ve tohum planın tutarlılığı. Hiçbir test `DateTime.now()`'a bağlı değildir;
/// 15 Kasım 2026 Pazar günü sabit çapa olarak kullanılır.
void main() {
  /// 2026-11-15 Pazar. [weekday] 1 (Pzt) … 7 (Paz) için sabit tarih üretir.
  DateTime at(int weekday, int hour, [int minute = 0]) {
    final DateTime anchor = DateTime(2026, 11, 15);
    final int delta = weekday - anchor.weekday;
    return DateTime(anchor.year, anchor.month, anchor.day + delta, hour, minute);
  }

  ScheduleBlock block({
    String id = 'plan-test',
    String partnerId = CouplePartner.yusufId,
    int weekday = DateTime.tuesday,
    int startHour = 14,
    int endHour = 16,
    String title = 'Veri Yapıları',
    ScheduleCategory category = ScheduleCategory.school,
  }) => ScheduleBlock(
    id: id,
    partnerId: partnerId,
    weekday: weekday,
    startMinutes: startHour * 60,
    endMinutes: endHour * 60,
    title: title,
    category: category,
  );

  group('ScheduleBlock biçimlendirme', () {
    test('dakikayı HH:mm olarak yazar ve sınırları kırpar', () {
      expect(ScheduleBlock.clock(0), '00:00');
      expect(ScheduleBlock.clock(840), '14:00');
      expect(ScheduleBlock.clock(9 * 60 + 5), '09:05');
      expect(ScheduleBlock.clock(1439), '23:59');
      expect(ScheduleBlock.clock(-30), '00:00');
      expect(ScheduleBlock.clock(2000), '24:00');
    });

    test('etiketler saati, süreyi ve günü doğru üretir', () {
      final ScheduleBlock item = block(startHour: 14, endHour: 15);
      expect(item.startLabel, '14:00');
      expect(item.endLabel, '15:00');
      expect(item.timeRangeLabel, '14:00 - 15:00');
      expect(item.durationMinutes, 60);
      expect(item.durationLabel, '60 dk');
      expect(item.weekdayLabel, 'Salı');
      expect(item.weekdayShortLabel, 'Sal');
      expect(item.displayTitle, '🎓 Veri Yapıları');
    });

    test('kategori kodları geri okunur, bilinmeyen kod çalışmaya düşer', () {
      expect(ScheduleCategory.fromCode('workout'), ScheduleCategory.workout);
      expect(ScheduleCategory.fromCode('rest'), ScheduleCategory.rest);
      expect(ScheduleCategory.fromCode(null), ScheduleCategory.study);
      expect(
        ScheduleCategory.fromCode('yok-boyle-bir-sey'),
        ScheduleCategory.study,
      );
      expect(ScheduleCategory.school.presetSource, 'preset:campus');
      expect(ScheduleCategory.date.fullLabel, '💑 Birlikte / Randevu');
    });
  });

  group('aktiflik ve ilerleme', () {
    test('başlangıç dahil, bitiş hariç aktif sayılır', () {
      final ScheduleBlock item = block();
      expect(item.isActiveAt(at(2, 13, 59)), isFalse);
      expect(item.isActiveAt(at(2, 14)), isTrue);
      expect(item.isActiveAt(at(2, 15, 30)), isTrue);
      expect(item.isActiveAt(at(2, 16)), isFalse);
      expect(item.isActiveAt(at(3, 15)), isFalse);
    });

    test('progressAt aktifken geçen sürenin oranını verir', () {
      final ScheduleBlock item = block();
      expect(item.progressAt(at(2, 14)), 0);
      expect(item.progressAt(at(2, 14, 30)), closeTo(0.25, 1e-9));
      expect(item.progressAt(at(2, 15, 45)), closeTo(0.875, 1e-9));
      expect(item.progressAt(at(2, 16)), 0);
      expect(item.progressAt(at(5, 15)), 0);
    });

    test('kalan ve başlangıca kalan dakikalar negatife düşmez', () {
      final ScheduleBlock item = block();
      expect(item.remainingMinutesAt(at(2, 15)), 60);
      expect(item.remainingMinutesAt(at(2, 13)), 0);
      expect(item.minutesUntilStart(at(2, 13)), 60);
      expect(item.minutesUntilStart(at(2, 14, 30)), 0);
      expect(item.minutesUntilStart(at(3, 9)), 0);
    });

    test('tamamlandı işareti güne özeldir ve ikinci dokunuşta geri alınır', () {
      final ScheduleBlock item = block();
      final DateTime tuesday = at(2, 15);
      expect(item.isCompletedOn(tuesday), isFalse);

      final ScheduleBlock done = item.toggleCompleted(tuesday);
      expect(done.isCompletedOn(tuesday), isTrue);
      expect(done.isCompletedOn(at(3, 15)), isFalse);
      expect(done.isCompletedOn(at(2, 12)), isTrue);

      final ScheduleBlock undone = done.toggleCompleted(tuesday);
      expect(undone.isCompletedOn(tuesday), isFalse);
      expect(item.completedDateKeys, isEmpty);
    });
  });

  group('SchedulePlanner · gün sorguları', () {
    final List<ScheduleBlock> week = <ScheduleBlock>[
      block(id: 'y-late', startHour: 19, endHour: 20),
      block(id: 'y-early', startHour: 9, endHour: 11),
      block(
        id: 'c-mid',
        partnerId: CouplePartner.ceydaId,
        startHour: 10,
        endHour: 12,
        category: ScheduleCategory.workout,
      ),
      block(id: 'y-wed', weekday: DateTime.wednesday, startHour: 8, endHour: 9),
    ];

    test('blocksForDay partneri ve günü filtreler, başlangıca göre sıralar', () {
      final List<ScheduleBlock> yusuf = SchedulePlanner.blocksForDay(
        week,
        CouplePartner.yusufId,
        DateTime.tuesday,
      );
      expect(yusuf.map((ScheduleBlock b) => b.id), <String>[
        'y-early',
        'y-late',
      ]);
      expect(
        SchedulePlanner.blocksForDay(
          week,
          CouplePartner.ceydaId,
          DateTime.tuesday,
        ),
        hasLength(1),
      );
      expect(() => yusuf.add(block(id: 'x')), throwsUnsupportedError);
    });

    test('allBlocksForDay iki partneri birleştirir', () {
      final List<ScheduleBlock> tuesday = SchedulePlanner.allBlocksForDay(
        week,
        DateTime.tuesday,
      );
      expect(tuesday.map((ScheduleBlock b) => b.id), <String>[
        'y-early',
        'c-mid',
        'y-late',
      ]);
    });

    test('currentBlock aktif olanı, birden fazlaysa erken başlayanı seçer', () {
      final List<ScheduleBlock> overlapping = <ScheduleBlock>[
        block(id: 'a', startHour: 14, endHour: 16),
        block(
          id: 'b',
          partnerId: CouplePartner.ceydaId,
          startHour: 15,
          endHour: 17,
        ),
      ];
      expect(
        SchedulePlanner.currentBlock(
          overlapping,
          CouplePartner.yusufId,
          at(2, 15, 30),
        )?.id,
        'a',
      );
      expect(
        SchedulePlanner.currentBlock(
          overlapping,
          CouplePartner.ceydaId,
          at(2, 15, 30),
        )?.id,
        'b',
      );
      expect(
        SchedulePlanner.currentBlock(
          overlapping,
          CouplePartner.yusufId,
          at(2, 18),
        ),
        isNull,
      );
    });

    test('nextBlock bugünün kalanını, yoksa haftanın sonraki gününü verir', () {
      expect(
        SchedulePlanner.nextBlock(week, CouplePartner.yusufId, at(2, 8))?.id,
        'y-early',
      );
      expect(
        SchedulePlanner.nextBlock(week, CouplePartner.yusufId, at(2, 15))?.id,
        'y-late',
      );
      expect(
        SchedulePlanner.nextBlock(week, CouplePartner.yusufId, at(2, 21))?.id,
        'y-wed',
      );
      expect(
        SchedulePlanner.nextBlock(week, 'bilinmeyen-partner', at(2, 8)),
        isNull,
      );
    });

    test('blockById kimliğe göre bulur', () {
      expect(SchedulePlanner.blockById(week, 'c-mid')?.title, 'Veri Yapıları');
      expect(SchedulePlanner.blockById(week, 'yok'), isNull);
    });
  });


  group('SchedulePlanner · ortak boşluklar', () {
    test('hiç blok yoksa tüm gün tek penceredir', () {
      final List<FreeWindow> windows = SchedulePlanner.sharedFreeWindows(
        const <ScheduleBlock>[],
        DateTime.tuesday,
      );
      expect(windows, hasLength(1));
      expect(windows.single.label, '09:00 - 23:00');
      expect(windows.single.durationLabel, '840 dk');
    });

    test('iki partnerin blokları arasındaki boşluklar döner', () {
      final List<ScheduleBlock> blocks = <ScheduleBlock>[
        block(id: 'y-sabah', startHour: 9, endHour: 11),
        block(
          id: 'c-oglen',
          partnerId: CouplePartner.ceydaId,
          startHour: 15,
          endHour: 16,
        ),
      ];
      final List<FreeWindow> windows = SchedulePlanner.sharedFreeWindows(
        blocks,
        DateTime.tuesday,
      );
      expect(windows.map((FreeWindow w) => w.label), <String>[
        '11:00 - 15:00',
        '16:00 - 23:00',
      ]);
      expect(windows.map((FreeWindow w) => w.durationMinutes), <int>[240, 420]);
      expect(
        SchedulePlanner.sharedFreeWindows(
          blocks,
          DateTime.wednesday,
        ).single.label,
        '09:00 - 23:00',
      );
    });

    test('45 dakikadan kısa boşluklar atlanır', () {
      final List<FreeWindow> windows = SchedulePlanner.sharedFreeWindows(
        <ScheduleBlock>[
          block(id: 'a', startHour: 9, endHour: 11),
          block(id: 'b', startHour: 11, endHour: 13),
        ],
        DateTime.tuesday,
      );
      expect(windows.map((FreeWindow w) => w.label), <String>[
        '13:00 - 23:00',
      ]);
      expect(SchedulePlanner.minFreeWindowMinutes, 45);
    });

    test('üst üste binen bloklar birleşir, gün dışı kırpılır', () {
      final List<FreeWindow> merged = SchedulePlanner.sharedFreeWindows(
        <ScheduleBlock>[
          block(id: 'a', startHour: 9, endHour: 12),
          block(id: 'b', startHour: 11, endHour: 13),
        ],
        DateTime.tuesday,
      );
      expect(merged.single.label, '13:00 - 23:00');

      final List<FreeWindow> clipped = SchedulePlanner.sharedFreeWindows(
        <ScheduleBlock>[block(id: 'gece', startHour: 22, endHour: 23)],
        DateTime.tuesday,
      );
      expect(clipped.single.label, '09:00 - 22:00');
    });

    test('longestSharedFreeWindow en uzun pencereyi seçer', () {
      final List<ScheduleBlock> blocks = <ScheduleBlock>[
        block(
          id: 'a',
          startHour: 11,
          endHour: 13,
          partnerId: CouplePartner.ceydaId,
        ),
        block(
          id: 'b',
          startHour: 17,
          endHour: 19,
          partnerId: CouplePartner.ceydaId,
        ),
      ];
      final FreeWindow? best = SchedulePlanner.longestSharedFreeWindow(
        blocks,
        DateTime.tuesday,
      );
      expect(best?.label, '13:00 - 17:00');
      expect(best?.durationMinutes, 240);
      expect(
        SchedulePlanner.longestSharedFreeWindow(
          const <ScheduleBlock>[],
          DateTime.tuesday,
        )?.label,
        '09:00 - 23:00',
      );
    });
  });


  group('tohum plan', () {
    final List<ScheduleBlock> week = ScheduleSeed.week();

    test('iki partnerin de haftası dolu ve bloklar geçerli', () {
      expect(week, isNotEmpty);
      expect(
        week.where((ScheduleBlock b) => b.partnerId == CouplePartner.yusufId),
        isNotEmpty,
      );
      expect(
        week.where((ScheduleBlock b) => b.partnerId == CouplePartner.ceydaId),
        isNotEmpty,
      );
      expect(week.map((ScheduleBlock b) => b.id).toSet(), hasLength(week.length));
      for (final ScheduleBlock item in week) {
        expect(CouplePartner.ids, contains(item.partnerId));
        expect(item.weekday, inInclusiveRange(1, 7));
        expect(item.endMinutes, greaterThan(item.startMinutes));
        expect(item.title, isNotEmpty);
      }
      expect(SchedulePlanner.completionXp, 25);
    });

    test('Salı 14:30 senaryosu: biri okulda, diğeri sporda', () {
      final ScheduleBlock? yusuf = SchedulePlanner.currentBlock(
        week,
        CouplePartner.yusufId,
        at(2, 14, 30),
      );
      final ScheduleBlock? ceyda = SchedulePlanner.currentBlock(
        week,
        CouplePartner.ceydaId,
        at(2, 14, 30),
      );
      expect(yusuf?.category, ScheduleCategory.school);
      expect(ceyda?.category, ScheduleCategory.workout);
      expect(yusuf?.timeRangeLabel, '14:00 - 16:00');
      expect(ceyda?.timeRangeLabel, '14:00 - 16:00');
    });

    test('Salı üç ortak boşluk var, en uzunu 16:00 - 19:00', () {
      final List<FreeWindow> windows = SchedulePlanner.sharedFreeWindows(
        week,
        DateTime.tuesday,
      );
      expect(windows.map((FreeWindow w) => w.label), <String>[
        '11:30 - 14:00',
        '16:00 - 19:00',
        '20:30 - 23:00',
      ]);
      expect(
        SchedulePlanner.longestSharedFreeWindow(week, DateTime.tuesday)?.label,
        '16:00 - 19:00',
      );
    });
  });

  group('serileştirme', () {
    test('ScheduleBlock JSON gidiş-dönüşünde kayıpsız', () {
      final ScheduleBlock original = ScheduleBlock(
        id: 'plan-x',
        partnerId: CouplePartner.ceydaId,
        weekday: 4,
        startMinutes: 13 * 60 + 30,
        endMinutes: 15 * 60,
        title: 'Klinik Psikoloji',
        category: ScheduleCategory.school,
        locationOrNote: 'Fen-Edebiyat · A-101',
        completedDateKeys: const <String>{'2026-11-19'},
      );
      final ScheduleBlock restored = ScheduleBlock.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.partnerId, original.partnerId);
      expect(restored.weekday, original.weekday);
      expect(restored.startMinutes, original.startMinutes);
      expect(restored.endMinutes, original.endMinutes);
      expect(restored.title, original.title);
      expect(restored.category, original.category);
      expect(restored.locationOrNote, original.locationOrNote);
      expect(restored.completedDateKeys, original.completedDateKeys);
    });

    test('bozuk JSON varsayılanlara ve sınırlara çekilir', () {
      final ScheduleBlock restored = ScheduleBlock.fromJson(<String, dynamic>{
        'id': 'bozuk',
        'partner_id': 'ceyda',
        'weekday': 12,
        'start_minutes': 2000,
        'end_minutes': -5,
        'title': 'Bozuk blok',
        'category': 'bilinmeyen',
      });
      expect(restored.weekday, 7);
      expect(restored.startMinutes, 1439);
      expect(restored.endMinutes, 1);
      expect(restored.category, ScheduleCategory.study);
      expect(restored.completedDateKeys, isEmpty);
    });

    test('ScheduleBlock.create kimliği üretir ve değerleri kırpar', () {
      final ScheduleBlock created = ScheduleBlock.create(
        partnerId: CouplePartner.yusufId,
        weekday: 9,
        startMinutes: -10,
        endMinutes: 2000,
        title: '  Sabah koşusu  ',
        category: ScheduleCategory.workout,
        now: DateTime(2026, 11, 15, 8),
      );
      expect(created.weekday, 7);
      expect(created.startMinutes, 0);
      expect(created.endMinutes, 1440);
      expect(created.title, 'Sabah koşusu');
      expect(created.id, startsWith('plan-yusuf-7-0-1440-'));
    });
  });

}
