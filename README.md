# LevelUp Life ⚡

Hayatını bir RPG'ye çeviren Flutter uygulaması. Günlük görevlerini tamamla,
XP kazan, seviye atla, 5 temel statını geliştir ve gün serini (streak) koru.
Tüm veriler cihazda saklanır — hesap, sunucu veya internet gerekmez.

## Özellikler

- **Tanışma sihirbazı** — isim, hayat evresi (öğrenci / çalışan / serbest…),
  hedefler ve karakter tipi (archetype). Seçimler görev havuzunun ağırlığını belirler.
- **Bugün sekmesi** — seviye/XP kartı, günlük görev listesi, görev ekleme,
  5 stat (INT / STR / VIT / …) ilerleme çubuğu, enerji modu ve ayarlar.
- **Enerji modu** — "Enerjim düşük" seçildiğinde ağır görevler mikro varyantlara
  çevrilir; amaç seriyi kaybetmemek.
- **Gün serisi (streak)** — aynı gün ikinci görev seriyi artırmaz, dün aktifsen +1,
  tek gün kaçırılırsa dondurma (freeze) hakkıyla kurtarılabilir.
- **İlerleme sekmesi** — seri kartı (rekor / aktif gün / dondurma), **7 gün ↔ 30 gün**
  geçişli XP bar grafiği ve günlük seri takvimi (ısı haritası, bugün vurgulu).
- **Kalıcılık** — `shared_preferences` üzerinden JSON; ayrıca profili sıfırlama.

## Ekranlar

| Sekme | İçerik |
| --- | --- |
| **Bugün** | Seviye kartı, görevler, stat ilerlemeleri, ayarlar & enerji modu |
| **İlerleme** | Günlük seri, 7/30 gün XP trendi, seri takvimi |

Alt sekme kabuğu `IndexedStack` kullanır: dashboard'ın kaydırma konumu ve
İlerleme sekmesinin 7/30 gün seçimi sekmeler arasında korunur.

## Mimari

```
lib/
├── core/          # tema (renk, tipografi, gölge, motion), sabitler, tarih/JSON yardımcıları
├── domain/        # entity'ler (UserProfile, Quest, Streak, DailyXpLog…) + servisler (XpEngine, QuestGenerator)
├── data/          # GameStore sözleşmesi; LocalGameStore (shared_preferences) / MemoryGameStore (test)
├── application/   # GameState + GameController (Riverpod notifier)
└── presentation/  # onboarding, shell, dashboard, progress + ortak widget'lar
```

- Durum yönetimi: **flutter_riverpod**
- Disk erişimi controller'dan soyutlanmıştır → testler `MemoryGameStore` ile
  diske dokunmadan, zamanı sabitleyerek (`now` parametreleri) çalışır.

## Kurulum

```bash
flutter pub get
flutter run -d chrome      # web
flutter run -d macos       # macOS (veya ios/android)
```

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # 161 test
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı
ve İlerleme sekmesi + alt sekme kabuğu widget testleri.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır.
