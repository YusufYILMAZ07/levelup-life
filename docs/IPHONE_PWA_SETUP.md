# CEYYUS · iPhone PWA + OneSignal Web Push kurulumu (ücretsiz, ~5 dakika)

Bu rehber, CEYYUS'u **Apple Developer hesabı olmadan**, **7 günlük imza
sınırı olmadan** iPhone 13 ve iPhone 17 Pro'da ana ekran uygulaması (PWA)
olarak çalıştırır ve **uygulama kapalıyken bile kilit ekranına bildirim**
almanızı sağlar.

> Teknik sınır: iOS/iPadOS **16.4+** gerekir. Web push yalnızca site
> **Safari → Paylaş → Ana Ekrana Ekle** ile eklenip **ana ekran simgesinden**
> açıldığında ve izin **kullanıcı dokunuşuyla** verildiğinde çalışır.
> HTTPS zorunludur (Vercel bunu otomatik sağlar).

## Gereksinimler

- Flutter 3.41+ ve bu repo
- Python 3 + Pillow (`pip3 install pillow`)
- Ücretsiz [Vercel](https://vercel.com) hesabı
- Ücretsiz [OneSignal](https://onesignal.com) hesabı (Web platformu)
- Supabase projesi + Supabase CLI (`supabase`)
- iPhone 13 / iPhone 17 Pro (iOS 16.4+)

---

## 1. İkonları ve splash'i üret (30 sn)

```bash
python3 tool/generate_ceyyus_icon.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
python3 tools/generate_web_icons.py
```

Üretilenler:

| Dosya | Boyut | Kullanım |
| --- | --- | --- |
| `assets/icon/ceyyus_icon.png` | 1024² | Mağaza / kaynak ikon |
| `web/icons/apple-touch-icon.png` | 180² | iOS Ana Ekrana Ekle |
| `web/icons/Icon-192.png` / `Icon-512.png` | 192² / 512² | Manifest `any` |
| `web/icons/Icon-maskable-*.png` | 192² / 512² | Android maskable |
| `web/favicon.png` | 64² | Tarayıcı sekmesi |

Palet: gece mavisi `#0B1124`, şampanya altını `#E6C29F`.

## 2. Web derlemesi

```bash
flutter pub get
flutter build web --release
```

Çıktı: `build/web/` (index.html + manifest + ikonlar + OneSignal worker).

## 3. Supabase Edge Function

```bash
supabase login
supabase link --project-ref <PROJECT_REF>
supabase secrets set ONESIGNAL_APP_ID=<onesignal-app-id> \
  ONESIGNAL_REST_API_KEY=<onesignal-rest-api-key> \
  CEYYUS_WEB_URL=https://<vercel-domain>/
supabase functions deploy send-couple-push
```

`CEYYUS_WEB_URL` opsiyoneldir; tanımlıysa kilit ekranı bildirimine
dokunulduğunda iPhone doğrudan CEYYUS PWA'sını açar.

## 4. Vercel'e ücretsiz deploy

### Yol A · Git ile (önerilen)

1. Repoyu GitHub'a push edin.
2. Vercel → **Add New → Project** → repoyu içe aktarın.
3. Ayarlar `vercel.json`'dan gelir:
   - Build: `bash tools/vercel_build.sh` (Flutter 3.41.9'u indirir)
   - Output: `build/web`
4. **Deploy** → `https://<proje>.vercel.app` adresini not edin.

### Yol B · Hazır derlemeyi doğrudan yükleme

```bash
cd build/web
cp ../../vercel.json .
npx vercel deploy --prod
```

> Not: `vercel.json`, `/push/onesignal/OneSignalSDKWorker.js` için
> `Service-Worker-Allowed: /push/onesignal/` başlığını ve SPA rewrite'ı
> tanımlar. Worker dosyası statik olarak servis edilmelidir (404 olmamalı).

## 5. OneSignal Web Push ayarı

1. OneSignal → uygulamanız → **Settings → Platforms → Web → Add platform**.
2. **Site Name:** `CEYYUS`
3. **Site URL:** `https://<proje>.vercel.app`
4. **Auto Resubscribe:** açık.
5. **App ID**'yi kopyalayın → CEYYUS → **Ayarlar → OneSignal App ID**
   alanına yapıştırın (native iOS/Android ile aynı App ID kullanılabilir;
   kimlik `oda__rol` olarak kapsamlandırılır).
6. Doğrulama: OneSignal → **Settings → Web Push** → site "configured"
   görünmeli; tarayıcıda
   `https://<domain>/push/onesignal/OneSignalSDKWorker.js` 200 dönmeli.

## 6. iPhone 13 / iPhone 17 Pro'da etkinleştir

1. **Safari**'de `https://<proje>.vercel.app` adresini açın
   (Chrome/Instagram içi tarayıcı değil).
2. **Paylaş → Ana Ekrana Ekle → CEYYUS**.
3. Uygulamayı **ana ekrandaki CEYYUS simgesinden** açın (Safari sekmesinden
   değil). Çentik / Dynamic Island için `viewport-fit=cover` hazırdır.
4. **Ayarlar → 🩺 Bildirim & Senkron Sağlık Paneli**:
   - Safari sekmesindeyseniz "Safari → Paylaş → Ana Ekrana Ekle…" kartı çıkar.
   - Ana ekrandan açtıysanız **Kapalıyken Bildirimleri Etkinleştir** →
     **İzin Ver**.
5. Yeşil rozet görünmeli: *"Kilit ekranı bildirimleri açık · ana ekrandan
   açılış algılandı"*.
6. Partnerin cihazından **📨 Karşı Tarafa Test Bildirimi Gönder**'e basın,
   iPhone'u kilitleyin → bildirim kilit ekranına düşer; dokununca CEYYUS
   açılır.

## 7. Sorun giderme

| Belirti | Çözüm |
| --- | --- |
| "Ana Ekrana Ekle" kartı görünüyor | Site Safari sekmesinde açık. Ana ekran simgesinden açın. |
| "Web push desteklenmiyor" | iOS < 16.4 veya HTTP. HTTPS + iOS güncellemesi gerekir. |
| İzin verildi, yeşil rozet yok | OneSignal Site URL'si Vercel alan adıyla birebir aynı olmalı; worker 404 olmamalı. |
| Test push gelmiyor | Edge secret'ları (`ONESIGNAL_*`), alıcının `external_id` eşleşmesi ve `push_enabled` kontrol edin. Sessiz saatte test bastırılabilir. |
| Splash ekranda kalıyor | `build/web` güncel mi? `flutter_bootstrap.js` 200 dönüyor mu? |
| Güncelleme görünmüyor | Ana ekrandaki simgeyi silip Safari'den yeniden ekleyin (PWA cache). |

## 8. Sınırlar (dürüst notlar)

- Web push **iOS 16.4+** ve **ana ekrana eklenmiş** PWA gerektirir.
- Low Power Mode teslimatı geciktirebilir; bildirim rozet desteği sınırlıdır.
- Web'de kamera kanıtı, Face ID ve arka plan sync native uygulamadaki kadar
  geniş değildir; bu özellikler native iOS/Android derlemesinde tam çalışır.
- App Store/sideload olmadığı için **7 günlük imza yenileme sınırı yoktur**.

## 9. Hızlı doğrulama

```bash
python3 tools/generate_web_icons.py
dart run flutter_launcher_icons && dart run flutter_native_splash:create
flutter pub get && flutter analyze && flutter test
flutter build web --release
supabase functions deploy send-couple-push
```
