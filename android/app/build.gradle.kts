plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Must match the package of MainActivity.kt and the app registered in
    // the Play Console (`flutter create --org com.dingo` generates the same).
    namespace = "com.dingo.duel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dingo.duel"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release builds are signed with the private upload key when CI hands it
    // over (GitHub secrets ANDROID_KEYSTORE_BASE64 / ANDROID_KEYSTORE_PASSWORD,
    // decoded to DUEL_KEYSTORE by the workflow). Without it (local builds,
    // forks) they fall back to the public test key, which only installs over
    // other test-key builds.
    val uploadKeystore = System.getenv("DUEL_KEYSTORE")?.takeIf { it.isNotBlank() }
    signingConfigs {
        create("test") {
            storeFile = file("duel-test.jks")
            storePassword = "duel-test"
            keyAlias = "duel"
            keyPassword = "duel-test"
        }
        if (uploadKeystore != null) {
            create("upload") {
                storeFile = file(uploadKeystore)
                storePassword = System.getenv("DUEL_KEYSTORE_PASSWORD")
                keyAlias = "upload"
                keyPassword = System.getenv("DUEL_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (uploadKeystore != null) "upload" else "test")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
