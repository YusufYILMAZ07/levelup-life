# ─────────────────────────────────────────────────────────────────────────────
# CEYYUS · Android R8/ProGuard kuralları (v6.4)
#
# Flutter motoru ve Dart AOT kodu kendi consumer kurallarıyla korunur; burada
# yalnızca reflection / JNI / manifest köprüsü kullanan native eklentiler
# tutulur. `build.gradle.kts` → `buildTypes.release` bu dosyayı kullanır.
# ─────────────────────────────────────────────────────────────────────────────

-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn org.jetbrains.annotations.**

# Flutter embedding / plugin kaydı
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications → AlarmManager, boot receiver, JSON payload
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# onesignal_flutter → REST + JSON köprüsü, Play Services istemcisi
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# local_auth → androidx.biometric (Face ID / parmak izi)
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**

# supabase_flutter → Dart istemcisi; native köprü yüzeyi korunur
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Diğer üretim eklentileri (güvenli depo, medya, paylaşım, yol)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# Kotlin coroutines / metadata
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlinx.**
