# LevelUp Life ⚡ — Couple Edition v6.0 (Yusuf & Ceyda)

Hayatını bir RPG'ye çeviren Flutter uygulaması — **iki kişilik** sürüm. Günlük
görevlerini tamamla, XP kazan, seviye atla, 5 temel statını geliştir ve gün
serini koru. Partnerin de aynı ekranda kendi karakterini büyütür. Uygulama
**varsayılan olarak tamamen yerel** çalışır; istersen iki telefonu Supabase
üzerinden canlı senkronize edebilir, OneSignal ile uygulama kapalıyken bile
bildirim alabilirsin.

> **v6.0 üretim sertleştirmesi:** `for all using (true)` RLS politikaları
> kaldırıldı, oda üyeliği + anonim auth eklendi, `couple-media` kovası özel
> oldu ve imzalı URL'ye geçti. OneSignal REST anahtarı istemciden çıkarıldı;
> push artık Supabase Edge Function üzerinden gönderiliyor. PIN düz metin
> yerine tuzlanmış SHA-256 olarak saklanıyor; çevrimdışı kuyruk (Outbox) ve
> tombstone'lar diske yazılıyor.

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
  bas veya sağa kaydır), beğen/kopyala/sil, **emoji tepkileri**, **mesaj
  düzenleme** (`✏️ düzenlendi`), gün ayırıcıları (`Bugün`, `Dün`, `18 Kasım`),
  ✓/✓✓ okundu bilgisi ve başlıkta canlı arama. Anı albümü
  `Tümü / Fotoğraflar / Videolar / Plan Kanıtları` sekmeleriyle filtrelenir.
- **Canlı presence** — Supabase'e bağlıyken karşı partnerin **çevrimiçi** ve
  **yazıyor…** durumu sohbet başlığında görünür (Realtime Presence + broadcast).
- **Kalıcı sohbet geçmişi + tombstone** — son 200 mesaj bağlantıda otomatik
  yüklenir; **⬆️ Daha Eski Mesajları Yükle** ile sayfalanır. Silinen mesajlar
  `deletedMessageTombstones`, silinen özel notlar `deletedLoveNoteTombstones`
  ile işaretlenir; uzak geçmiş veya eski bir durum paketi onları **geri
  diriltemez**. Çevrimdışı gönderimler kalıcı Outbox'tan bağlantı gelince akar.
- **Gerçek profil fotoğrafları** — Yusuf ve Ceyda ayarlardan galeriden kendi
  fotoğrafını seçer; üst bar, sohbet ve "Şu Anda İkimiz" kartında görünür.
- **Üç katmanlı bildirim + tercihler** — (1) her platformda anında görünen iOS
  tarzı floating banner, (2) uygulama açık/arka plandayken yerel OS bildirimi,
  (3) uygulama tamamen kapalıyken OneSignal push (Supabase Edge Function ile).
  **Check-in saati** ve **sessiz saat (DND) aralığı** ayarlanabilir; sessiz
  saatte OS bildirimi/push gönderilmez, plan hatırlatıcısı planlanmaz. Her plan
  bloğundan **10 dk önce** haftalık hatırlatıcı. Bildirime dokunmak Sohbet
  sekmesini açar.
- **Dört gerçek özel gün** — Ceyda'nın doğum günü (27 Kasım), Yusuf'un doğum
  günü (20 Aralık), yıldönümü (31 Ocak) ve Sevgililer Günü (14 Şubat). Her biri
  için bir gün önce **20:00** ve gün içinde **09:00** yıllık bildirim; Bugün
  sekmesinde geri sayım ve doğum günü deneyimi.
- **Özel alan PIN kilidi + biyometri** — 4 haneli çift PIN'i (varsayılan
  **3101**), uygulama açılışında ve arka plandan dönüşte zarif bir numpad
  sorar. PIN **tuzlanmış SHA-256** olarak `flutter_secure_storage` içinde
  saklanır; Face ID / parmak izi (`local_auth`) ve **0–300 sn arka plan
  toleransı** (kamera/galeri dönüşü) desteklenir. 5 hatalı denemeden sonra
  artan bekleme uygulanır.
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
  debounce edilir, arka plana geçerken zorla diske yazılır. **`save()` gerçek
  disk yazımı bitince resolve olur**, bozuk kayıt `cache.game_state.corrupted`
  anahtarına taşınır ve `schema_version` ile sürümlenir. iPhone ProMotion için
  120 Hz ve sohbet balonlarında `RepaintBoundary` kullanılır.
- **Yedekleme / geri yükleme** — Ayarlar → Yedekleme: tüm veri tek JSON olarak
  paylaşılır (pano + paylaşım sayfası). İçe aktarmada `app`, `schema_version`,
  `couple` ve `partners` doğrulanır; bozuk yedek uygulama durumunu değiştirmez.
- **Tek oyunculu kayıt migrasyonu** — v5'te olduğu gibi eski kayıt ezilmez;
  profil/görevler cihaz sahibinin koltuğuna taşınır, sohbet ve rubrik korunur.

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
├── core/          # tema, sabitler, tarih/JSON/stable-hash yardımcıları, platform medya köprüsü
├── domain/
│   ├── entities/  # UserProfile, Quest (isCustom), PartnerData, CoupleState (tombstone), ChatMessage (reaction/edit)…
│   └── services/  # XpEngine, QuestGenerator, CoupleEfficiencyEngine, CoupleSeeder
├── data/          # GameStore: schemaVersion + corrupted backup + Completer'lı save
├── services/      # AppSettings, MediaService, NotificationService, PushService,
│                  # SupabaseSyncService, CloudSyncCoordinator, SyncOutbox,
│                  # PinSecurity, SecureSecretsStore, BiometricService, BackupService
├── application/   # GameState, GameController (facade), GameMutation
│   └── controllers/  # QuestController · DevelopmentController · CoupleChatController
│                     # CoupleGoalsController · CoupleSyncController
└── presentation/  # onboarding, shell, dashboard, development, chat (+presence/tepki), progress,
                   # birthday, PIN (+biyometri), in-app bildirim banner'ı
supabase/
├── migrations/20261123000000_v6_security.sql   # RLS + room_members + özel kova
└── functions/send-couple-push/index.ts         # OneSignal REST anahtarı sunucuda
```

- Durum yönetimi: **flutter_riverpod 3** (Notifier + `select` tabanlı granular
  provider'lar: `dashboardSnapshotProvider`, `questsProvider`, `messagesProvider`…).
- `GameState` iki modu destekler: **tek oyuncu** (legacy `setup/profile/quests`)
  ve **çift modu** (`partners` haritası + `activePartnerId`). Üst seviye alanlar
  her zaman aktif partnerin aynasıdır → eski ekranlar değişmeden çalışır.
- `GameController` artık ince bir facade'dır; iş kuralları 5 modül controller'da
  toplanır. Her modül yalnızca `GameStateAccess` sözleşmesini bilir.
- **Deterministik senkron:** `MutationOrigin` (local/remote) + monoton
  `localRevision`. Uzak paketler revizyonu artırmaz → echo yok; sabit
  `Timer(700/900 ms)` yarış penceresi kaldırıldı.
- Disk erişimi controller'dan soyutlanmıştır → testler `MemoryGameStore`,
  `MemorySyncOutbox` ve fake `CloudSyncBackend` ile ağa/diske dokunmadan çalışır.

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

## Supabase kurulumu (opsiyonel)

Bulut tamamen opsiyoneldir; **hiçbir şey yapılmazsa uygulama yerel çalışır.**

1. [supabase.com](https://supabase.com) → yeni proje.
2. **Authentication → Providers → Anonymous → Enable.** (RLS, `auth.uid()`
   üzerinden çalışır; iki cihaz da anonim oturum açar.)
3. **SQL Editor** → `supabase/migrations/20261123000000_v6_security.sql`
   dosyasının tamamını çalıştır. Bu migrasyon:
   - `couple_rooms`, `room_members`, `chat_messages` tablolarını + indeksleri,
   - `is_room_member()` / `member_role()` ve `join_couple_room()` fonksiyonlarını,
   - **v6 RLS politikalarını** (oda üyeliği + gönderen rolü doğrulaması),
   - **özel** `couple-media` kovasını ve klasör bazlı Storage politikalarını,
   - Realtime yayınını (`insert/update/delete`) ve `replica identity full`'u kurar.
   Alternatif: `supabase db push` / `supabase migration up`.
4. Supabase → **Project Settings → API**'den **Project URL** ve **anon/publishable**
   anahtarını al.
5. Uygulamada Ayarlar → ☁️ İki Telefon Canlı Senkronizasyon → URL, anon key ve
   **Oda Kodu** (`YUSUF-CEYDA-2026`). Yusuf'un telefonunda **Yusuf**,
   Ceyda'nınkinde **Ceyda** rolü → **Bağlan ve Senkronize Et**.
6. İki telefon aynı odaya bağlandığında mesajlar (insert/update/**delete**),
   presence ("çevrimiçi/yazıyor…"), fotoğraf/video (imzalı URL), rubrik, plan ve
   kapsüller Realtime ile akar. URL/anahtar değiştirilirse istemci yeniden
   başlatmaya gerek kalmadan `dispose()` + yeniden `initialize` edilir.

> Oda kodu bir **davet sırrıdır**: bilen cihaz odaya katılabilir. Oda başına en
> fazla 2 üye ve rol başına 1 cihaz (`room_members` unique constraint) kabul edilir.

## OneSignal kurulumu (kapalıyken push)

Yerel bildirimler yalnızca uygulama açıkken/arka plandayken çalışır. Uygulama
tamamen kapalıyken partnerine ulaşmak için:

1. [onesignal.com](https://onesignal.com) → yeni uygulama → **App ID**'yi al.
2. OneSignal → **Settings → Keys & IDs** → **REST API Key** oluştur. Bu anahtar
   **cihaza girilmez**; yalnızca Supabase secret olarak saklanır:
   ```bash
   supabase secrets set \
     ONESIGNAL_APP_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
     ONESIGNAL_REST_API_KEY=os_v2_...
   supabase functions deploy send-couple-push
   ```
3. OneSignal → **Push → Apple iOS** → APNs anahtarını (`.p8`) ve Key ID'yi yükle;
   Bundle ID `dev.levelup.levelupLife` ile eşleştir.
4. Xcode'da Runner hedefinde **Push Notifications** ve **Background Modes →
   Remote notifications** açık olmalı. `ios/Runner/Runner.entitlements`
   `aps-environment` içerir; minimum iOS sürümü **15.0**.
5. Uygulamada Ayarlar → **🔔 Kapalıyken de Bildirim** bölümüne **yalnızca App ID**
   gir → kaydet → **🚀 OneSignal Push Testi Gönder**.

Cihaz sahibi OneSignal'a `external_id` olarak `yusuf` / `ceyda` ile giriş yapar.
Push isteğini `send-couple-push` Edge Function'ı yapar; fonksiyon çağıranın
oturumunu ve `room_members` üyeliğini doğrular, alıcının karşı partner olduğunu
kontrol eder. Böylece REST anahtarı istemciye hiç inmez.

## İzinler

- **iOS** (`ios/Runner/Info.plist`): kamera, fotoğraf galerisi, mikrofon,
  **Face ID (`NSFaceIDUsageDescription`)** ve bildirim açıklamaları;
  `UIBackgroundModes → remote-notification`,
  `CADisableMinimumFrameDurationOnPhone` (ProMotion). `AppDelegate.swift` ön
  planda da bildirim göstermek için `UNUserNotificationCenter` delegesini atar.
  `Runner.entitlements` push (`aps-environment`) hakkını taşır; deployment
  target **iOS 15.0**'dır.
- **Android** (`AndroidManifest.xml`): `CAMERA`, `RECORD_AUDIO`,
  `READ_MEDIA_IMAGES/VIDEO`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  zamanlanmış bildirim alıcıları. `local_auth` için `MainActivity`
  **`FlutterFragmentActivity`** türetir; `flutter_local_notifications` için
  `build.gradle.kts` içinde core library desugaring açıktır.

## Kurulum

```bash
flutter pub get
flutter run -d chrome      # web (güvenli inline sınır: 250 KB; büyük medya Supabase Storage)
flutter run -d ios         # iPhone (kamera + galeri + bildirimler + Face ID)
flutter build web --release
flutter build ios --simulator --no-codesign   # iOS 15+ / OneSignal
```

Gerçek cihazda imzalı build için Apple Developer hesabında Push Notifications
hakkı ve geçerli bir provisioning profile gerekir.

Depo boşsa veya eski tek oyunculu bir kayıt varsa:
- depo tamamen boşsa `CoupleBootstrap.initialState()` tohumu yazılır,
- **eski tek oyunculu kayıt varsa ezilmez**: `CoupleBootstrap.migrateFromLegacy`
  profili/görevleri cihaz sahibinin koltuğuna taşır, sohbet ve rubrik korunur.

## v6.0 kapsamı

Tamamlanan sertleştirme ve özellikler bu README'de listelenmiştir. Bilinçli
olarak **bu sürüme alınmayan** iki başlık (v6.1 yol haritası):

- **Sesli not (voice note):** `record` + ses oynatma paketi ve Android/iOS
  mikrofon izin akışı gerektirir; `RECORD_AUDIO` izni şimdilik yalnızca video
  kaydı için kullanılıyor.
- **Ortak çift görevleri (co-op quests) ve haftada 1 seri dondurma UI'ı:**
  `Streak.freezeMissedDay` / `AppConstants.startingFreezeTokens` altyapısı hazır;
  kullanıcıya görünen kart/akış bir sonraki sürümde eklenecek.

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # 338 test
flutter build web --release
flutter build ios --simulator --no-codesign
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı,
verimlilik motoru, çift controller'ı (partner geçişi, rubrik XP'si, sinerji,
sohbet/fotoğraf, kalıcılık, **tahribatsız uzak mesaj birleştirme**), dört
sekmeli kabuk + çift ekranları, medya/yanıt/okundu serileştirmesi, özel günler,
bildirim metni/plan zamanlaması, OneSignal Edge Function payload'ları, Supabase
`SyncConfig` + **v6 SQL güvenlik şeması**, PIN numpad'i, kilitli cihaz kimliği
ve **v6 regresyon testleri**: `refreshQuests` özel görev koruması,
`toggleBucketGoal` tek seferlik XP, `addCustomBonus` sınırları, tombstone
birleştirmesi, uzak durumda cihaz kimliği koruması, **kalıcı Outbox flush**,
**PIN brute-force + grace period**, **tuzlu SHA-256 PIN**, DND hesapları.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır; Ceyda'ya hediye edilmiştir. 💖

