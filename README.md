# LevelUp Life ⚡ — Couple Edition v4.0 (Yusuf & Ceyda)

Hayatını bir RPG'ye çeviren Flutter uygulaması — **iki kişilik** sürüm. Günlük
görevlerini tamamla, XP kazan, seviye atla, 5 temel statını geliştir ve gün
serini koru. Partnerin de aynı ekranda kendi karakterini büyütür. Uygulama
**varsayılan olarak tamamen yerel** çalışır; istersen iki telefonu Supabase
üzerinden canlı senkronize edebilirsin.

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
- **Sohbet & anı albümü (WhatsApp + Locket kalitesi)** — gerçek kamera ve
  galeriden fotoğraf/video (en fazla 60 sn), göndermeden önce not ekleme,
  sohbet içi video oynatıcı, iki parmakla yakınlaştırma, yanıtla (uzun bas veya
  sağa kaydır), beğen/kopyala/sil, gün ayırıcıları (`Bugün`, `Dün`, `18 Kasım`),
  ✓/✓✓ okundu bilgisi ve başlıkta canlı arama. Anı albümü
  `Tümü / Fotoğraflar / Videolar / Plan Kanıtları` sekmeleriyle filtrelenir.
- **Gerçek profil fotoğrafları** — Yusuf ve Ceyda ayarlardan galeriden kendi
  fotoğrafını seçer; üst bar, sohbet ve "Şu Anda İkimiz" kartında görünür.
- **Gerçek OS bildirimleri** — partnerden yeni mesaj/fotoğraf/video/dürtme
  geldiğinde kilit ekranı bildirimi; her plan bloğundan **10 dk önce** haftalık
  hatırlatıcı ve her akşam **21:30** gelişim puanı hatırlatıcısı. Ayarlardan
  anahtarlar + "🔔 Test Bildirimi Gönder".
- **Özel alan PIN kilidi** — 4 haneli çift PIN'i (varsayılan Ceyda'nın doğum
  günü **1402**), uygulama açılışında ve arka plandan dönüşte zarif bir numpad
  sorar.
- **İki telefon canlı senkronizasyon (opsiyonel Supabase)** — aynı oda koduna
  bağlanan iki telefon mesaj, fotoğraf/video (Storage `couple-media`), rubrik,
  plan, kapsül ve bucket list değişimlerini Realtime ile paylaşır.
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
├── core/          # tema, sabitler, tarih/JSON yardımcıları, platform medya köprüsü (io/web)
├── domain/
│   ├── entities/  # UserProfile, Quest, PartnerData, CoupleState, ChatMessage (medya/yanıt/okundu)…
│   └── services/  # XpEngine, QuestGenerator, CoupleEfficiencyEngine, CoupleSeeder
├── data/          # GameStore sözleşmesi; LocalGameStore / MemoryGameStore (test)
├── services/      # AppSettings, MediaService, NotificationService, SupabaseSyncService, CloudSyncCoordinator
├── application/   # GameState, GameController, CoupleBootstrap, AppServices, PinLockController
└── presentation/  # onboarding, shell, dashboard, development, chat (+ medya/video), progress, birthday, PIN
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
- **Bildirim saatleri:** `NotificationService.scheduleDailyCheckin` (varsayılan
  21:30) ve plan hatırlatıcıları (`10 dk önce`).
- **Varsayılan PIN / oda kodu:** `AppSettings.defaultPin` (`1402`) ve
  `AppSettings.defaultRoomCode` (`YUSUF-CEYDA-2026`).

## Supabase kurulumu (opsiyonel, 30 saniye)

Bulut tamamen opsiyoneldir; **hiçbir şey yapılmazsa uygulama yerel çalışır.**

1. [supabase.com](https://supabase.com) → yeni proje → **SQL Editor**.
2. Ayarlar → ☁️ İki Telefon Canlı Senkronizasyon → **SQL şemasını kopyala**
   düğmesine bas (aynı SQL `SupabaseSyncService.schemaSql` içinde de durur) ve
   SQL Editor'a yapıştırıp çalıştır. Bu; `couple_rooms`, `chat_messages`,
   `couple-media` Storage kovası, RLS politikaları ve Realtime yayınını kurar.
3. Supabase → **Project Settings → API**'den **Project URL** ve **anon public**
   anahtarını al.
4. Uygulamada Ayarlar → aynı bölüme URL, anon key ve **Oda Kodu**
   (`YUSUF-CEYDA-2026`) gir. Yusuf'un telefonunda **Yusuf**, Ceyda'nınkinde
   **Ceyda** rolünü seç → **Bağlan ve Senkronize Et**.
5. İki telefon da aynı odaya bağlandığında mesajlar, fotoğraf/video, rubrik,
   plan ve kapsüller Realtime ile akar; partnerden gelen mesaj yerel bildirim
   üretir. İlk bağlantıda odadaki mevcut durum cihaza çekilir; sonrasında
   değişiklikler iki yönlü gider. Bağlantı koparsa uygulama sessizce yerel moda
   döner.

## İzinler

- **iOS** (`ios/Runner/Info.plist`): kamera, fotoğraf galerisi, mikrofon ve
  bildirim açıklamaları; `UIBackgroundModes → remote-notification`.
  `AppDelegate.swift` ön planda da bildirim göstermek için
  `UNUserNotificationCenter` delegesini atar.
- **Android** (`AndroidManifest.xml`): `CAMERA`, `RECORD_AUDIO`,
  `READ_MEDIA_IMAGES/VIDEO`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  zamanlanmış bildirim alıcıları. `flutter_local_notifications` için
  `build.gradle.kts` içinde core library desugaring açıktır.

## Kurulum

```bash
flutter pub get
flutter run -d chrome      # web (kamera/galeri data URL olarak çalışır)
flutter run -d ios         # iPhone (kamera + galeri + bildirimler)
flutter build web --release
flutter build ios --no-codesign
```

Depo boşsa veya eski tek oyunculu bir kayıt varsa `CoupleBootstrap.initialState()`
tohumu yazılır: iki profil, 6 günlük gerçekçi XP geçmişi, bugünün görevleri,
sohbet geçmişi ve bucket list hazır gelir. Testler boş store ile çalıştığı için
onboarding akışı bozulmaz.

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # 274 test
flutter build web --release
flutter build ios --no-codesign
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı,
verimlilik motoru (ağırlıklar, nötr skor, beraberlik, sinerji sınırı), çift
controller'ı (partner geçişi, rubrik XP'si, sinerji ödülü, sohbet/fotoğraf,
kalıcılık), dört sekmeli kabuk + çift ekranları, **ChatMessage medya/yanıt/okundu
serileştirmesi**, **bildirim metni ve plan zamanlaması yardımcıları**, **Supabase
`SyncConfig` doğrulaması + SQL şeması**, **PIN kilidi numpad'i** ve **yanıtla /
arama / video albüm filtresi** akışları.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır; Ceyda'ya hediye edilmiştir. 💖

