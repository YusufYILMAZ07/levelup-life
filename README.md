# LevelUp Life ⚡ — Couple Edition v6.3 (Yusuf & Ceyda)

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
>
> **v6.1 Production Gold bildirim garantisi:** gönderenin sessiz saati /
> kapalı bildirim ayarı partnerin push'unu artık engellemiyor. Push, mesaj
> Supabase'e yazıldıktan sonra kalıcı `pendingPushMessageIds` kuyruğundan
> **tam bir kez** gönderiliyor; uygulama push'tan önce kapansa bile açılışta
> tamamlanıyor. OneSignal kimliği `<oda>__<rol>` ile izole edildi,
> ön planda Realtime + OneSignal çift bildirimi bastırılıyor, Edge Function
> `push_deliveries` atomik claim ile istemci/webhook çifte push'unu önlüyor.
> Ayarlar'a canlı **Bildirim & Senkron Sağlık Paneli** eklendi.
>
> **v6.2 Hardening & senkron düzeltmesi:** ilk durum push'undan sonra kilitli
> kalan `_statePushInFlight` yarışı giderildi (art arda gelen tüm yerel
> değişiklikler buluta ulaşır). Web istemcisi artık OneSignal SDK'sı olmadan da
> Edge Function üzerinden partnerine push gönderebilir. Oda kurtarma sırrı düz
> metin yerine **bcrypt özeti** olarak saklanır (`recovery_secret_hash`), oda
> kodu asla kurtarma sırrı yazılmaz ve `reclaim_couple_role` 5 hatalı denemede
> 15 dk kilitlenir. Silinen mesajın push idempotency kaydı artık cascade ile
> silinmez. Bildirim dokunuşları (`plan:`, `sync-rubric`, `checkin`,
> `special:`) doğru sekmeye yönlendirilir; plan günü/sessiz saat değişimi
> hatırlatıcıları yeniden zamanlar; outbox `clear()` yarışı ve gece yarısı
> sessiz saat hesabı düzeltildi.
>
> **v6.3 Polish & kurtarma UI'ı:** `pgcrypto` fonksiyonları (`crypt`,
> `gen_salt`, `gen_random_bytes`) Supabase'in `extensions` şemasından
> çözülecek şekilde dört RPC `set search_path = public, extensions` ile
> yeniden tanımlandı. `reclaim_couple_role` boş kurtarma kodunda bcrypt
> çalıştırmaz ve sayaç artırmaz; 15 dakikalık kilit dolduğunda sayaç sıfırlanır
> (yeni 5 deneme). Durum push'u sürerken gelen yerel değişiklik **trailing
> coalesce** ile kesin olarak gönderilir; outbox'ta `pending`/`synced`/
> `pushed`/`pushPending`/`pendingDeletes` yazımlarının tamamı tek seri kuyrukta
> (`clear()` dahil) çalışır. Ayarlar → Bulut bölümüne **Oda Kurtarma Kodu**
> kartı eklendi: tek tıkla kod üretme (tek seferlik diyalog + kopyala) ve
> `role taken` sonrası otomatik açılan **Rolümü Geri Al** diyaloğu. Sohbette
> bildirime dokununca mesaj en fazla 2 sayfa geriye yüklenir, `ensureVisible`
> ile tam hizalanır ve kısa bir vurgu animasyonu gösterilir; bulunamazsa
> "eski geçmişte veya silinmiş" bilgisi verilir.

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
3. **SQL Editor** → önce `supabase/migrations/20261123000000_v6_security.sql`,
   sonra `supabase/migrations/20261125000000_v6_1_production_gold.sql`, sonra
   `supabase/migrations/20261125120000_v6_2_hardening.sql`, en son
   `supabase/migrations/20261125180000_v6_3_polish.sql` dosyalarının
   tamamını çalıştır. Bu migrasyonlar:
   - `couple_rooms`, `room_members`, `chat_messages` tablolarını + indeksleri,
   - `is_room_member()` / `member_role()` ve `join_couple_room()` fonksiyonlarını,
   - **v6 RLS politikalarını** (oda üyeliği + gönderen rolü doğrulaması),
   - **özel** `couple-media` kovasını ve klasör bazlı Storage politikalarını,
   - Realtime yayınını (`insert/update/delete`) ve `replica identity full`'u,
   - v6.1'de `room_members.last_seen_at/push_enabled/sessiz saat`,
     `chat_messages.read_at/reactions`, güvenli `mark_messages_read` +
     `toggle_message_reaction` RPC'lerini ve `push_deliveries` idempotency
     tablosunu kurar,
   - v6.2'de kurtarma sırrını `recovery_secret_hash` (bcrypt) olarak saklar,
     `issue_couple_recovery_secret` / `set_couple_recovery_secret` RPC'lerini
     ekler, `reclaim_couple_role`'a kalıcı deneme kilidi getirir ve
     `push_deliveries.message_id` FK'sini kaldırır,
   - v6.3'te dört RPC'yi `set search_path = public, extensions` ile yeniden
     tanımlar (Supabase'de `pgcrypto` `extensions` şemasındadır), boş kurtarma
     kodunda sayaç artırmaz ve süresi dolmuş kilidi sıfırlar.
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
   Remote notifications** açık olmalı. Debug için
   `ios/Runner/Runner.entitlements` (`development`), Release/Profile için
   `ios/Runner/RunnerRelease.entitlements` (`production`) kullanılır. Minimum
   iOS sürümü **15.0**.
   - Zengin medya / görsel ekli push'lar için
     [OneSignal Notification Service Extension rehberi](docs/ONESIGNAL_IOS_NSE.md).
5. Uygulamada Ayarlar → **🔔 Kapalıyken de Bildirim** bölümüne **yalnızca App ID**
   gir → kaydet → **🩺 Bildirim Sağlık Paneli → Karşı Tarafa Test Bildirimi**.

Cihaz sahibi OneSignal'a **oda kapsamlı** `external_id` ile giriş yapar:

```text
<normalize-oda-kodu>__<rol>          # yusuf-ceyda-2026__ceyda
```

Böylece aynı OneSignal App ID'sini kullanan farklı çiftler/test cihazları
birbirine push alamaz. Push isteğini `send-couple-push` Edge Function'ı yapar;
fonksiyon çağıranın oturumunu, `room_members` üyeliğini ve mesaj sahibini
doğrular, alıcının `push_enabled` + sessiz saat ayarını uygular. İstemci ve
sunucu aynı mesaj için yarışsa bile `push_deliveries` atomik claim'i ikinci
push'u `duplicate:true` ile durdurur. REST anahtarı istemciye hiç inmez.

> **Sunucu tarafı ek garanti (opsiyonel):** İstemci kapanmış olsa bile her
> `chat_messages` INSERT'inde Edge Function'ı çağırmak için
> `supabase/migrations/20261123002000_v6_1_push_webhook.example.sql` dosyasındaki
> `pg_net` trigger rehberini uygula. İdempotency aynı olduğu için istemciyle
> birlikte açık kalması çifte bildirim üretmez.

## İzinler

- **iOS** (`ios/Runner/Info.plist`): kamera, fotoğraf galerisi, mikrofon,
  **Face ID (`NSFaceIDUsageDescription`)** ve bildirim açıklamaları;
  `UIBackgroundModes → remote-notification`,
  `CADisableMinimumFrameDurationOnPhone` (ProMotion). `AppDelegate.swift` ön
  planda da bildirim göstermek için `UNUserNotificationCenter` delegesini atar.
  `Runner.entitlements` Debug'da `aps-environment: development`,
  `RunnerRelease.entitlements` Release/Profile'da `production` taşır;
  deployment target **iOS 15.0**'dır.
- **Android** (`AndroidManifest.xml`): `CAMERA`, `RECORD_AUDIO`,
  `READ_MEDIA_IMAGES/VIDEO`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  `SCHEDULE_EXACT_ALARM`, zamanlanmış bildirim alıcıları. Exact alarm izni
  yoksa `NotificationService` otomatik olarak `inexactAllowWhileIdle`'a düşer.
  `local_auth` için `MainActivity` **`FlutterFragmentActivity`** türetir;
  `flutter_local_notifications` için `build.gradle.kts` içinde core library
  desugaring açıktır. Release imzası `android/key.properties`'ten okunur
  (dosya yoksa debug anahtarı + Gradle uyarısı; mağaza öncesi zorunlu).

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

## v6.1 kapsamı

Tamamlananlar:

- **Bildirim zinciri:** gönderen DND'si bağımsız push, kalıcı push kuyruğu,
  outbox sonrası tam 1 push, 401/403 otomatik oturum tazeleme + 1 retry.
- **Ön plan dedupe:** Realtime bağlıyken OneSignal ikinci bildirimi bastırılır;
  sohbet açıksa sistem bildirimi/banner yerine hafif titreşim.
- **Oda izolasyonu:** `<oda>__<rol>` external_id, Edge Function
  `include_aliases` + nudge `collapse_id` + yüksek öncelik.
- **Sunucu idempotency:** `push_deliveries` + `claim_push_delivery` /
  `complete_push_delivery`; istemci + webhook aynı anda çağırsa tek bildirim.
- **Sohbet RLS:** alıcı partner okundu/tepkiyi yalnızca `SECURITY DEFINER`
  RPC ile yazar; `room_members.last_seen_at/push_enabled/sessiz saat` eklendi.
- **Platform:** Android 14 exact-alarm fallback'i, üretim keystore yapısı,
  Debug/Release iOS entitlements ayrımı, NSE kurulum rehberi.
- **Tanı:** Ayarlar → Bildirim & Senkron Sağlık Paneli (izin, OneSignal
  identity, oda üyeliği, outbox, karşı tarafa test push).

## v6.3 kapsamı

Tamamlananlar:

- **`pgcrypto` şeması:** `join_couple_room`, `issue_couple_recovery_secret`,
  `set_couple_recovery_secret` ve `reclaim_couple_role` artık
  `set search_path = public, extensions` kullanır; canlıda `crypt` /
  `gen_salt` / `gen_random_bytes` "does not exist" hatası veremez. Migration
  başında fonksiyonların varlığını doğrulayan bir `do $$` guard var.
- **Kurtarma kilidi ergonomisi:** boş/whitespace kod `22023` ile reddedilir
  (bcrypt maliyeti ve sayaç artışı yok); 15 dakikalık kilit dolduğunda
  `recovery_failed_attempts` sıfırlanır → kullanıcı yeniden 5 deneme alır.
- **Trailing durum push'u:** `_pushStateNow` uçuştayken gelen yerel değişiklik
  `_statePushQueued` ile işaretlenir; ilk istek bitince bir kez daha push
  edilir. Uçuş sırasında yazılan dirty state artık **en güncel** durumdur.
- **Tam outbox serileştirmesi:** `pending`, `synced`, `pushed`, `pushPending`,
  `pendingDeletes` ve `dirty` yazımları/silmeleri tek `_writeChain`
  kuyruğundan geçer; `enqueue`/`dequeueDelete` ile `clear()` arasında yarış
  kalmaz. Değerler kuyruğa girmeden önce (çağrı anında) alınır.
- **Tam alarm izni:** `refreshExactAlarmPermission()` artık "izin değişti mi"
  döndürür; `resumed` anında değişim varsa `_planSignature` sıfırlanır ve
  planlar `exact` / `inexact` moduyla yeniden zamanlanır.
- **Sağlık paneli:** `_requestPermission` / `_sendTest` `try/finally` ile
  kilitlenmez, izin sonrası `_refresh()` çağrılır; web'de test bildiriminin
  **bu tarayıcıya değil partnerin telefonuna** gittiği açıkça yazar.
- **Kurtarma UI'ı:** Ayarlar → Bulut/Oda bölümünde **Oda Kurtarma Kodu** kartı
  (tek tıkla üret + tek seferlik kopyalanabilir diyalog) ve **Rolümü Geri Al**
  diyaloğu. `role taken` hatasından sonra diyalog kendiliğinden açılır;
  sonuç `ok | invalid | locked | notConfigured` olarak anlamlı mesaja çevrilir.
- **Sohbet odağı:** hedef mesaj bellekte yoksa en fazla 2 sayfa sessiz
  `_loadOlderSilently()` denenir, sonra oran tahmini + `Scrollable.ensureVisible`
  (alignment 0.35) ve `_FocusPulse` vurgusu uygulanır; bulunamazsa kısa
  snackbar gösterilir. Arama filtresi odağı engellemez (temizlenir).

## v6.2 kapsamı

Tamamlananlar:

- **Senkron kilidi:** `_pushStateNow` artık izlenen `Future`'ı (`tracked`)
  karşılaştırdığı için kilit ilk push'tan sonra açılır; art arda gelen yerel
  değişikliklerin tamamı buluta yazılır (birim testiyle doğrulandı).
- **Web → mobil push:** Web istemcisi OneSignal SDK'sını atlar ama
  `send-couple-push` Edge Function'ını çağırır; tarayıcıdan atılan mesaj
  partnerin telefonuna bildirim olarak gider.
- **Kurtarma güvenliği:** `recovery_secret` düz metni kaldırıldı; bcrypt
  `recovery_secret_hash` + `issue_couple_recovery_secret` /
  `set_couple_recovery_secret` RPC'leri ve 5 denemede 15 dk kilit.
- **Push idempotency:** `push_deliveries.message_id` FK'si kaldırıldı; mesaj
  silinse bile aynı kimlik ikinci push üretmez.
- **Bildirim yönlendirme:** `plan:`, `sync-plan`, `sync-rubric`, `checkin`,
  `special:` payload'ları doğru sekmeye gider.
- **Zamanlama doğruluğu:** imzaya `weekday` + sayısal sessiz saat sınırları
  eklendi; `00:00–00:09` blokları için 10 dk öncesi `23:50–23:59` hesaplanır.
- **Outbox dayanıklılığı:** `clear()` bekleyen `saveDirtyState` yazımını
  ezer; `clearDirtyState()` erken dönmez; silme kimlikleri kırpılır.
- **Exact alarm:** Android 14+ izni `resumed` anında yeniden okunur; kullanıcı
  sistem ayarlarından izin verdiğinde uygulamayı yeniden başlatmak gerekmez.
- **PIN:** PBKDF2 ham çağrısı katı 4 hane ister; biyometrik bekleme mesajı
  "0 sn" yazmaz.

Bilinçli olarak **v6.3'e bırakılanlar**:

- **Sesli not (voice note)** ve **ortak çift görevleri / haftalık seri
  dondurma UI'ı** (`Streak.freezeMissedDay` altyapısı hazır).
- **İmzalı medya URL otomatik yenileme** (7 günlük expiry yaklaşımı korunuyor).

## Kalite kontrolleri

```bash
flutter analyze            # No issues found!
flutter test               # tüm birim + widget testleri
flutter build web --release
flutter build ios --simulator --no-codesign

# Bulut tarafı (opsiyonel)
supabase db push
supabase functions deploy send-couple-push
```

Test kapsamı: XP motoru ve seviye eğrisi, seri kuralları (dondurma dahil),
görev üretimi, `GameState`/`UserProfile` JSON round-trip'i, onboarding akışı,
verimlilik motoru, çift controller'ı (partner geçişi, rubrik XP'si, sinerji,
sohbet/fotoğraf, kalıcılık, **tahribatsız uzak mesaj birleştirme**), dört
sekmeli kabuk + çift ekranları, medya/yanıt/okundu serileştirmesi, özel günler,
bildirim metni/plan zamanlaması, OneSignal Edge Function payload'ları, Supabase
`SyncConfig` + **v6/v6.1 SQL güvenlik şeması**, PIN numpad'i, kilitli cihaz
kimliği ve **v6 regresyon testleri**: `refreshQuests` özel görev koruması,
`toggleBucketGoal` tek seferlik XP, `addCustomBonus` sınırları, tombstone
birleştirmesi, uzak durumda cihaz kimliği koruması, **kalıcı Outbox flush**,
**PIN brute-force + grace period**, **tuzlu SHA-256 PIN**, DND hesapları ve
**v6.1 bildirim regresyonları**: gönderen DND'sinde push, alıcı DND'sinde
yerel bastırma, çevrimdışı outbox push'unun tam 1 kez gitmesi, oda kapsamlı
external_id, foreground çift bildirim filtresi, **v6.2 regresyonları**: ilk
push sonrası `_statePushInFlight` kilidinin açılması, `clear()` /
`saveDirtyState()` yarışı, Web'de Edge Function push'unun engellenmemesi, tüm
bildirim payload'larının doğru sekmeye gitmesi, plan günü/sessiz saat imzası,
gece yarısı sessiz saat hesabı ve katı PBKDF2 girdisi, **v6.3 regresyonları**:
uçuştaki push sırasında gelen değişikliğin trailing push ile gönderilmesi,
tam alarm izni değişiminde planların yeniden zamanlanması, `dequeueDelete`
yazımı sürerken `clear()` çağrıldığında `pendingDeletes` kalıntısı kalmaması
ve kurtarma sonuçlarının (`ok | invalid | locked`) doğru eşlenmesi.

## Lisans

Bu proje eğitim/portfolyo amaçlıdır; Ceyda'ya hediye edilmiştir. 💖

