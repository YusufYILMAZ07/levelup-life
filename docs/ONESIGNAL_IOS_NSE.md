# OneSignal iOS Notification Service Extension (v6.1)

Amaç: görsel / zengin medya içeren push'ları göstermek, teslim edilen
bildirimleri raporlamak ve badge sayaçlarını doğru yönetmek. Temel push'lar NSE
olmadan da çalışır; NSE yalnızca **rich media** ve extension-side raporlama
için gerekir.

## 1) OneSignal paneli

1. OneSignal → **Settings → Keys & IDs** → App ID'yi not al.
2. **Push → Apple iOS** → APNs `.p8` anahtarını, Key ID ve Team ID'yi yükle.
3. Bundle ID: `dev.levelup.levelupLife` (Runner ile aynı olmalı).

## 2) Xcode hedefi

1. `ios/Runner.xcworkspace` dosyasını Xcode'da aç.
2. **File → New → Target… → Notification Service Extension**.
3. Product name: `OneSignalNotificationServiceExtension`.
4. Bundle Identifier: `dev.levelup.levelupLife.OneSignalNotificationServiceExtension`.
5. Language: Swift, minimum deployment target: **iOS 15.0**.
6. Xcode "Activate" uyarısında extension şemasını etkinleştir.
7. Runner → Signing & Capabilities:
   - **Push Notifications** açık,
   - **Background Modes → Remote notifications** açık,
   - Debug'da `Runner/Runner.entitlements` (`aps-environment: development`),
   - Release/Profile'da `Runner/RunnerRelease.entitlements`
     (`aps-environment: production`) seçili.
8. NSE hedefi → Signing & Capabilities → aynı Team'i seç; extension'ın
   provisioning profile'ı Runner ile aynı App Group / Team altında olmalı.

## 3) Podfile

`ios/Podfile` içindeki `target 'Runner' do ... end` bloğunun **altına** NSE
hedefini ve OneSignal extension modülünü ekle. Sürümü `pubspec.lock` içindeki
`onesignal_flutter` sürümüyle uyumlu tut.

```ruby
target 'OneSignalNotificationServiceExtension' do
  use_frameworks!
  pod 'OneSignalXCFramework', '>= 5.0.0', '< 6.0.0'
  pod 'OneSignalXCFramework/OneSignalExtension', '>= 5.0.0', '< 6.0.0'
end
```

Sonra:

```bash
cd ios
pod install
```

## 4) `NotificationService.swift`

Xcode'un oluşturduğu dosyanın içeriğini aşağıdakiyle değiştir:

```swift
import UserNotifications
import OneSignalExtension

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var receivedRequest: UNNotificationRequest?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        OneSignalExtension.didReceiveNotificationExtensionRequest(
            request,
            with: bestAttemptContent,
            withContentHandler: contentHandler
        )
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler = contentHandler,
              let bestAttemptContent = bestAttemptContent,
              let request = receivedRequest else { return }

        OneSignalExtension.serviceExtensionTimeWillExpireRequest(
            request,
            with: bestAttemptContent
        )
        contentHandler(bestAttemptContent)
    }
}
```

> OneSignal SDK sürümünde `OneSignalExtension` adı değişirse OneSignal'ın
> [iOS NSE dokümanındaki](https://documentation.onesignal.com/docs/ios-notification-service-extension)
> güncel sınıf/metot adlarını kullan. `pod install` sonrası Xcode temiz build
> (`⇧⌘K`) yap.

## 5) Doğrulama

1. `flutter build ios --release` (imzalı, gerçek cihaz) veya Xcode → Run.
2. OneSignal → **Messages → New Push** → `include_aliases` yerine test için
   **Subscriptions** ekranından cihazın `<oda>__<rol>` external ID'sini
   seç.
3. Uygulama kapalıyken görsel URL'li bir push gönder.
4. Uygulama Ayarlar → **🩺 Bildirim & Senkron Sağlık Paneli**:
   - **OneSignal aboneliği** satırı `<oda>__<rol>` göstermeli,
   - **Karşı Tarafa Test Bildirimi** HTTP 200 + OneSignal durumunu göstermeli.
5. `push_deliveries` tablosunda `status = sent` ve `onesignal_id` dolu olmalı.

## Sık hatalar

| Belirti | Neden / çözüm |
|---|---|
| `aps-environment` uyarısı | Release/Profile'da yanlış entitlements seçili; `RunnerRelease.entitlements` kullan. |
| NSE'de `No such module 'OneSignalExtension'` | Podfile NSE hedefi eksik veya `pod install` çalıştırılmadı. |
| Push gitti ama görsel yok | NSE hedefi bundle ID'si yanlış veya extension imzalanmamış. |
| Aynı bildirim iki kez | `send-couple-push` v6.1 deploy edilmemiş; `push_deliveries` idempotency'si yok. |
| `external_id` eşleşmiyor | Oda kodu boş veya uygulama Ayarlar'da Supabase'e bağlanmamış; kimlik `<oda>__<rol>` olmalı. |
