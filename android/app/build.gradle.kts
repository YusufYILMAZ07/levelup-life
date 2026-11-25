import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Üretim imzası: android/key.properties (git'e eklenmez).
// Dosya yoksa release build canlıya çıkmaz; güvenli geri dönüş olarak debug
// anahtarı kullanılır ve Gradle çıktısında uyarı basılır.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val requiredSigningKeys = listOf(
    "storeFile", "storePassword", "keyAlias", "keyPassword"
)
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    requiredSigningKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }
if (!hasReleaseSigning) {
    logger.warn(
        "⚠️ android/key.properties eksik veya alanları boş. Release build " +
            "DEBUG anahtarıyla imzalanıyor; mağazaya yüklemeden önce üretim " +
            "keystore'unu tanımla."
    )
}

android {
    namespace = "dev.levelup.levelup_life"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications, Java 8+ zaman API'lerini kullanır.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.levelup.levelup_life"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Yerel `flutter run --release` çalışsın; mağaza dağıtımı için
                // key.properties zorunludur.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
