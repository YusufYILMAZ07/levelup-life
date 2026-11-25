# CEYYUS v6.4.0+10 — Yayın ve Cihaz Kurulum Rehberi

Bu belge, **CEYYUS**'u gerçek Android ve iOS telefonlara kurup günlük
kullanıma almak için gereken adımları tek yerde toplar. Sürüm: `6.4.0+10`
(versionCode 10).

> **Kimlikler bilinçli olarak sabit:** Dart paketi `levelup_life`,
> `applicationId` / bundle id `dev.levelup.levelup_life`, yedek kimliği
> `levelup-life`, `SharedPreferences`/SecureStorage anahtarları, bildirim
> kanalı `levelup_couple_messages` ve Supabase tablo/oda/storage adları
> **değiştirilmedi**. Böylece mevcut kurulumlar veri kaybetmeden güncellenir.
> Değişen tek şey kullanıcıya görünen markadır: **CEYYUS**.

## 1. Ön koşullar

| Araç | Sürüm / not |
| --- | --- |
| Flutter | 3.41+ (Dart 3.11+) |
| Xcode | 16+ ve CocoaPods 1.16+ |
| JDK | 17 (Android Gradle Plugin ile uyumlu) |
| Android SDK | `compileSdk = flutter.compileSdkVersion`, `minSdk = 23` |
| Supabase CLI | `db push` ve `functions deploy` için |
| OneSignal | Uygulama + REST anahtarı **yalnız Edge Function secret'ında** |

## 2. Marka görsellerini (yeniden) üretmek

```bash
python3 tool/generate_ceyyus_icon.py     # 4 PNG: icon, foreground, monochrome, splash
dart run flutter_launcher_icons          # Android mipmap + adaptive + iOS + web ikonları
dart run flutter_native_splash:create    # Android 12 / iOS / web açılış ekranı
```

Üretilen kaynaklar `assets/icon/` altındadır; betik harici font kullanmaz ve
deterministiktir. Renk paleti uygulamanın temasıyla aynıdır: erik/indigo zemin
`#1B1033`, gül kalp `#FB7185 → #BE123C`, altın kıvılcım `#FDE68A`.

## 3. Android: imzalı APK/AAB ve telefona kurulum

### 3.1 İmza anahtarı (tek sefer)

```bash
keytool -genkey -v -keystore ~/ceyyus-release.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias ceyyus
cp android/key.properties.example android/key.properties
# key.properties içine gerçek storePassword / keyPassword / storeFile yaz.
```

`android/key.properties`, `*.jks` ve `*.keystore` `.gitignore` içindedir.
Dosya yoksa Gradle release'i debug anahtarıyla imzalar ve uyarı basar — mağaza
ve kalıcı cihaz kurulumu için **üretim anahtarı zorunludur**.

### 3.2 Build

```bash
flutter clean
flutter pub get
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # mağaza / Play Console için .aab
```

Release'te R8 küçültme + kaynak budama açıktır; eklenti keep kuralları
`android/app/proguard-rules.pro` içindedir (flutter_local_notifications,
onesignal_flutter, local_auth, supabase_flutter ve yan eklentiler).

### 3.3 Telefona kurma

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
# Etiket doğrulaması:
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | head -3
```

Beklenen: `application-label:'CEYYUS'`, paket adı `dev.levelup.levelup_life`.

## 4. iOS: Archive ve iPhone kurulumu

```bash
cd ios && pod install && cd ..
flutter build ios --release        # imza ayarları Xcode'dan gelir
open ios/Runner.xcworkspace        # Product → Archive → Distribute App
```

- Signing & Capabilities: **Push Notifications** + **Background Modes →
  Remote notifications / Background fetch**.
- Debug `Runner.entitlements` → `aps-environment: development`,
  Release/Profile `RunnerRelease.entitlements` → `production`.
- Info.plist: `CFBundleDisplayName = CEYYUS`, kamera/galeri/mikrofon/Face ID
  açıklamaları Türkçe, `ITSAppUsesNonExemptEncryption = false`.
- TestFlight veya `flutter run --release -d <iphone>` ile cihaza alınır.

## 5. Supabase (bulut senkronu ve push için)

Migration sırası **korunmalıdır**:

```bash
supabase db push        # 20261123000000_v6_security → v6_1 → v6_2 → v6_3_polish
supabase functions deploy send-couple-push
supabase secrets list   # ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY burada
```

Ardından bir üye cihazdan oda kurtarma kodunu üret ve güvenli sakla:

```sql
select public.issue_couple_recovery_secret('<ROOM-CODE>');
```

## 6. Cihazda smoke test (kurulumdan sonra)

1. Ana ekran adı **CEYYUS**, ikon kalp + CY, açılış ekranı markalı.
2. İlk açılışta onboarding 4 adım; isim/rol/hedef kaydedilir.
3. Dört sekme: Bugün · Gelişim · Sohbet · İlerleme — yazı boyutu 1.3× iken de
   taşma yok (otomatik test: `test/presentation/small_screen_overflow_test.dart`).
4. Bildirim izni + test bildirimi başlığı `CEYYUS · test 🌸`.
5. Face ID / parmak izi istemi `CEYYUS · özel alanı aç` metniyle açılır.
6. Sohbet: metin + kamera/galeri medyası, plan kanıtı, okundu bilgisi.
7. Plan ekleme: klavye açıkken form kaydırılabilir, kaydet çalışır.
8. Ayarlar → yedek paylaşımı `CEYYUS yedeği` konusuyla açılır; geri yükleme
   aynı dosyayı kabul eder (yedek kimliği `levelup-life`).
9. Oda kurtarma kodu üret → çıkış → **Rolümü Geri Al** ile geri dön.

## 7. Bu depoda doğrulanan / doğrulanamayanlar

Doğrulandı: `flutter analyze` (0 sorun), `flutter test` (396/396), web release
derlemesi, ikon/splash üretimi, XML/plist tutarlılığı.

Bu makinede **yapılamadı**: `flutter build apk` (Android SDK yok),
`flutter build ios --release` (fiziksel cihaz/provisioning yok; Xcode var),
`supabase db push` + `functions deploy` (Supabase CLI ve proje erişimi yok).
Bu adımlar yukarıdaki komutlarla, ilgili makinelerde tamamlanmalıdır.
