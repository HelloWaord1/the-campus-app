plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("vkid.manifest.placeholders")
}

import java.util.Properties

val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        load(keystoreFile.inputStream())
    }
}

val hasReleaseKeystore: Boolean =
    keystoreProperties.getProperty("keyAlias") != null &&
        keystoreProperties.getProperty("keyPassword") != null &&
        keystoreProperties.getProperty("storeFile") != null &&
        keystoreProperties.getProperty("storePassword") != null

android {
    namespace = "rocket.padel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "rocket.padel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdkVersion(26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["YANDEX_CLIENT_ID"] = "68eaebf6f9f944809e301617b8519c69"
        // VK ID placeholders — продублированы здесь, чтобы Gradle корректно подставлял значения в манифест
        manifestPlaceholders["VKIDRedirectHost"] = "vk.com"
        manifestPlaceholders["VKIDRedirectScheme"] = "vk54063347"
        manifestPlaceholders["VKIDClientID"] = "54063347"
        manifestPlaceholders["VKIDClientSecret"] = "psZy9zAddNAsilR9euiI"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}
// VK ID placeholders конфигурируются в корневом build.gradle.kts

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.firebase:firebase-messaging:24.0.0")
    implementation("com.yandex.android:maps.mobile:4.6.1-lite")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
