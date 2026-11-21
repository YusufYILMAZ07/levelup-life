# LevelUp Life ⚡ — Couple Edition v5.0 (Yusuf & Ceyda)

Hayatını bir RPG'ye çeviren Flutter uygulaması — **iki kişilik** sürüm. Günlük
görevlerini tamamla, XP kazan, seviye atla, 5 temel statını geliştir ve gün
serini koru. Partnerin de aynı ekranda kendi karakterini büyütür. Uygulama
**varsayılan olarak tamamen yerel** çalışır; istersen iki telefonu Supabase
üzerinden canlı senkronize edebilir, OneSignal ile uygulama kapalıyken bile
bildirim alabilirsin.

## Özellikler

- **Çift modu & kilitli cihaz kimliği** — Yusuf 💻 ve Ceyda 🌸 profilleri ayrı
  tutulur. "📱 Bu Telefon Kimin?" seçimiyle her iPhone kendi sahibine kilitlenir;
  yanlış isimle mesaj veya rubrik puanı girilmesi engellenir. Tek cihaz test
  modu istendiğinde profil geçişi yeniden açılabilir.
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
  galeriden fotoğraf/video (en fazla **45 sn / 20 MB**), göndermeden önce not
  ekleme, sohbet içi video oynatıcı, iki parmakla yakınlaştırma, yanıtla (uzun
  bas veya sağa kaydır), beğen/kopyala/sil, gün ayırıcıları (`Bugün`, `Dün`,
  `18 Kasım`), ✓/✓✓ okundu bilgisi ve başlıkta canlı arama. Anı albümü
  `Tümü / Fotoğraflar / Videolar / Plan Kanıtları` sekmeleriyle filtrelenir.
- **Kalıcı sohbet geçmişi** — son 200 mesaj bağlantıda otomatik yüklenir;
  sohbetin üstündeki **⬆️ Daha Eski Mesajları Yükle** düğmesiyle buluttaki tüm
  geçmiş sayfalanır. Yerel ve uzak mesajlar id ile birleştirilir; hiçbir yerel
  mesaj ezilmez, çevrimdışı gönderimler bağlantı gelince kuyruktan yüklenir.
- **Gerçek profil fotoğrafları** — Yusuf ve Ceyda ayarlardan galeriden kendi
  fotoğrafını seçer; üst bar, sohbet ve "Şu Anda İkimiz" kartında görünür.
- **Üç katmanlı bildirim** — (1) her platformda anında görünen iOS tarzı
  floating banner, (2) uygulama açık/arka plandayken yerel OS bildirimi,
  (3) uygulama tamamen kapalıyken OneSignal push. Partnerden yeni
  mesaj/fotoğraf/video/dürtme geldiğinde bildirim; her plan bloğundan **10 dk
  önce** haftalık hatırlatıcı ve her akşam **21:30** gelişim puanı
  hatırlatıcısı. Bildirime dokunmak Sohbet sekmesini açar.
- **Dört gerçek özel gün** — Ceyda'nın doğum günü (27 Kasım), Yusuf'un doğum
  günü (20 Aralık), yıldönümü (31 Ocak) ve Sevgililer Günü (14 Şubat). Her biri
  için bir gün önce **20:00** ve gün içinde **09:00** yıllık bildirim; Bugün
  sekmesinde geri sayım ve doğum günü deneyimi.
- **Özel alan PIN kilidi** — 4 haneli çift PIN'i (varsayılan **3101**),
  uygulama açılışında ve arka plandan dönüşte zarif bir numpad sorar.
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
- **Kalıcılık ve performans** — `shared_preferences` üzerinden JSON; yazımlar
  debounce edilir, arka plana geçerken zorla diske yazılır. iPhone ProMotion
  için 120 Hz ve sohbet balonlarında `RepaintBoundary` kullanılır.

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
├── services/      # AppSettings, MediaService, NotificationService, PushService, SupabaseSyncService, CloudSyncCoordinator
├── application/   # GameState, GameController, CoupleBootstrap, AppServices, PinLockController
└── presentation/  # onboarding, shell, dashboard, development, chat (+ medya/video), progress, birthday, PIN, in-app bildirim banner'ı
```

- Durum yönetimi: **flutter_riverpod**.
- `GameState` iki modu destekler: **tek oyuncu** (legacy `setup/profile/quests`)
  ve **çift modu** (`partners` haritası + `activePartnerId`). Üst seviye alanlar
  her zaman aktif partnerin aynasıdır → eski ekranlar değişmeden çalışır.
- Disk erişimi controller'dan soyutlanmıştır → testler `MemoryGameStore` ile
  diske dokunmadan, zamanı sabitleyerek (`now` parametreleri) çalışır.

## Kişiselleştirme

- **Özel günler:** `lib/domain/entities/birthday.dart` içindeki
  `CoupleSpecialDates` listesi (dört tarih tek doğruluk kaynağıdır).
- **İsimler, emojiler, renkler:** `CouplePartner` + `CouplePalette`.
- **Sohbete hazır notlar:** `LoveNotes.all`; **hazır anı kartları:** `PhotoPreset.all`.
- **Bildirim saatleri:** `NotificationService.scheduleDailyCheckin` (varsayılan
  21:30), plan hatırlatıcıları (`10 dk önce`) ve `scheduleSpecialDates`
  (bir gün önce 20:00 / gün içinde 09:00).
- **Varsayılan PIN / oda kodu:** `AppSettings.defaultPin` (`3101`) ve
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

## OneSignal kurulumu (kapalıyken push)

Yerel bildirimler yalnızca uygulama açıkken/arka plandayken çalışır. Uygulama
tamamen kapalıyken partnerine ulaşmak için:

1. [onesignal.com](https://onesignal.com) → yeni uygulama → **App ID**'yi al.
2. OneSignal → **Settings → Keys & IDs** → **REST API Key** oluştur.
3. OneSignal → **Push → Apple iOS** → APNs anahtarını (`.p8`) ve Key ID'yi yükle;
   Bundle ID `dev.levelup.levelupLife` ile eşleştir.
4. Xcode'da Runner hedefinde **Push Notifications** ve **Background Modes →
   Remote notifications** açık olmalı. `ios/Runner/Runner.entitlements`
   `aps-environment` içerir; OneSignal 5.8 için minimum iOS sürümü **15.0**.
5. Uygulamada Ayarlar → **🔔 Kapalıyken de Bildirim** bölümüne App ID + REST API
   Key gir → kaydet → **🚀 OneSignal Push Testi Gönder**.

Cihaz sahibi OneSignal'a `external_id` olarak `yusuf` / `ceyda` ile giriş yapar;
gönderim partnerin external id'sine hedeflenir. REST API anahtarı yalnızca
cihazda saklanır ve Web'de push tamamen no-op çalışır.

## İzinler

- **iOS** (`ios/Runner/Info.plist`): kamera, fotoğraf galerisi, mikrofon ve
  bildirim açıklamaları; `UIBackgroundModes → remote-notification`,
  `CADisableMinimumFrameDurationOnPhone` (ProMotion). `AppDelegate.swift` ön
  planda da bildirim göstermek için `UNUserNotificationCenter` delegesini atar.
  `Runner.entitlements` push (`aps-environment`) hakkını taşır; deployment
  target **iOS 15.0**'dır.
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
flutter build ios --simulator --no-codesign   # iOS 15+ / OneSignal
```

Gerçek cihazda imzalı build için Apple Developer hesabında Push Notifications
hakkı ve geçerli bir provisioning profile gerekir.

Depo boşsa veya eski tek oyunculu bir kayıt varsa `CoupleBootstrap.initialState()`
tohumu yazılır: iki profil, 6 günlük gerçekçi XP geçmişi, bugünün görevleri,
sohbet geçmişi ve bucket list hazır gelir. Testler boş store ile çalıştığı için
onboarding akışı bozulmaz.

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # 310 test
flutter build web --release
flutter build ios --simulator --no-codesign
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı,
verimlilik motoru (ağırlıklar, nötr skor, beraberlik, sinerji sınırı), çift
controller'ı (partner geçişi, rubrik XP'si, sinerji ödülü, sohbet/fotoğraf,
kalıcılık, **tahribatsız uzak mesaj birleştirme**), dört sekmeli kabuk + çift
ekranları, **ChatMessage medya/yanıt/okundu serileştirmesi**, **dört özel gün ve
geri sayım**, **üç katmanlı bildirim metni/plan zamanlaması**, **OneSignal push
payload'ları**, **Supabase `SyncConfig` doğrulaması + SQL şeması**, **PIN kilidi
numpad'i**, **kilitli cihaz kimliği** ve **yanıtla / arama / video albüm
filtresi** akışları.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır; Ceyda'ya hediye edilmiştir. 💖

