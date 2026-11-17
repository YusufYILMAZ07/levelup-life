# LevelUp Life ⚡ — Couple Edition (Yusuf & Ceyda)

Hayatını bir RPG'ye çeviren Flutter uygulaması — **iki kişilik** sürüm. Günlük
görevlerini tamamla, XP kazan, seviye atla, 5 temel statını geliştir ve gün
serini koru. Partnerin de aynı ekranda kendi karakterini büyütür. Tüm veriler
cihazda saklanır — hesap, sunucu veya internet gerekmez.

## Özellikler

- **Çift modu & partner geçişi** — üst bardaki segmentle Yusuf 💻 ve Ceyda 🌸
  arasında geç; her partnerin profili, görevleri, statları ve serisi ayrı tutulur.
- **Canlı durum** — 7 seçenekli durum (kod/ders, spor, kahve, derin odak…) her
  iki partner için ayrı seçilir ve karşı tarafta görünür.
- **Günlük 1-2-3 gelişim rubriği** — 5 yaşam alanı (akademik, dil/okuma, spor,
  beslenme, uyku) her gün 1-3 puanlanır: 1 → 10 XP, 2 → 25 XP, 3 → 45 XP.
  Aynı gün ilk puanlama XP verir; düzeltmeler XP üretmez.
- **Çift sinerjisi** — iki taraf aynı gün aynı alanda 2+ puan alırsa **her
  ikisine +25 XP** ve çift skoruna +5 puan.
- **Hızlı bonus eylemler** — pomodoro, su, kitap, antrenman, temiz beslenme,
  İngilizce: tek dokunuşla anında XP.
- **Ortak bucket list** — 6 hazır ortak hedef; tamamlanınca iki tarafa da Co-Op XP.
- **Haftalık verimlilik düellosu** — son 7 güne bakar; %40 rubrik, %35
  tutarlılık, %15 bonus, %10 etkileşim ağırlığıyla 0-100 skor. Kazanan taçlanır,
  beraberlik ve tek taraflı veri adil biçimde raporlanır. Haftanın bahsi
  (kahve, masaj, film, akşam yemeği) seçilebilir.
- **Sohbet & anı albümü** — iki partner arasında mesajlar (gönderen rengiyle),
  dürtme, aşk notu, görev paylaşımı; fotoğraflar `preset:` anı kartları,
  `data:image/…` veya `https://` ile eklenir, galeride toplanır ve lightbox'ta
  kalple favorilenir.
- **Doğum günü deneyimi** — mektup, yılın özeti (XP, seri, mesaj, anı, sinerji)
  ve aşk notu üretici. Tarih geldiğinde Bugün sekmesindeki banner kutlama
  moduna geçer; sürpriz her gün elle de açılabilir.
- **Tanışma sihirbazı** (yedek akış) — sıfırlarsan isim, hayat evresi, hedefler
  ve tempo yeniden sorulur; görev havuzu bu cevaplara göre ağırlıklanır.
- **Enerji modu** — "Enerjim düşük" seçildiğinde ağır görevler mikro varyantlara
  çevrilir; amaç seriyi kaybetmemek.
- **Kalıcılık** — `shared_preferences` üzerinden JSON; çift durumu (partnerler,
  sohbet, rubrik, bucket list, bahis) tek doküman olarak saklanır.

## Ekranlar

| Sekme | İçerik |
| --- | --- |
| **Bugün** | Partner segmenti + canlı durum, doğum günü kartı, seviye kartı, görevler, partner özeti, stat ilerlemeleri |
| **Gelişim** | Günlük puan kartı, sinerji durumu, 5 alanlık 1-2-3 rubriği, hızlı eylemler, ortak bucket list, aşk notu üretici |
| **Sohbet** | Mesaj akışı, dürtme/aşk notu/anı kısayolları, anı albümü ve fotoğraf lightbox'ı |
| **İlerleme** | Haftalık verimlilik düellosu + bahis, karşılaştırmalı radar, seri kartı, 7/30 gün XP trendi, seri takvimi |

Alt sekme kabuğu `IndexedStack` kullanır: her sekmenin kaydırma konumu, 7/30 gün
seçimi ve sohbet taslağı korunur.

## Mimari

```
lib/
├── core/          # tema (renk, tipografi, gölge, motion, couple paleti), sabitler, tarih/JSON yardımcıları
├── domain/
│   ├── entities/  # UserProfile, Quest, PartnerData, CoupleState, ChatMessage, BirthdayConfig…
│   └── services/  # XpEngine, QuestGenerator, CoupleEfficiencyEngine, CoupleSeeder
├── data/          # GameStore sözleşmesi; LocalGameStore / MemoryGameStore (test)
├── application/   # GameState (iki partner + ortak durum), GameController, CoupleBootstrap
└── presentation/  # onboarding, shell, dashboard, development, chat, progress, birthday + ortak widget'lar
```

- Durum yönetimi: **flutter_riverpod**.
- `GameState` iki modu destekler: **tek oyuncu** (legacy `setup/profile/quests`)
  ve **çift modu** (`partners` haritası + `activePartnerId`). Üst seviye alanlar
  her zaman aktif partnerin aynasıdır → eski ekranlar değişmeden çalışır.
- Disk erişimi controller'dan soyutlanmıştır → testler `MemoryGameStore` ile
  diske dokunmadan, zamanı sabitleyerek (`now` parametreleri) çalışır.

## Kişiselleştirme

- **Doğum günü tarihi:** `lib/domain/entities/birthday.dart` içindeki
  `BirthdayConfig.ceyda` satırı (gün/ay) düzenlenir.
- **İsimler, emojiler, renkler:** `CouplePartner` + `CouplePalette`.
- **Sohbete hazır notlar:** `LoveNotes.all`; **hazır anı kartları:** `PhotoPreset.all`.

## Kurulum

```bash
flutter pub get
flutter run -d chrome      # web
flutter run -d macos       # macOS (veya ios/android)
```

Depo boşsa veya eski tek oyunculu bir kayıt varsa `CoupleBootstrap.initialState()`
tohumu yazılır: iki profil, 6 günlük gerçekçi XP geçmişi, bugünün görevleri,
sohbet geçmişi ve bucket list hazır gelir. Testler boş store ile çalıştığı için
onboarding akışı bozulmaz.

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # 185 test
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı,
verimlilik motoru (ağırlıklar, nötr skor, beraberlik, sinerji sınırı), çift
controller'ı (partner geçişi, rubrik XP'si, sinerji ödülü, sohbet/fotoğraf,
kalıcılık) ve dört sekmeli kabuk + çift ekranlarının widget testleri.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır; Ceyda'ya hediye edilmiştir. 💖

