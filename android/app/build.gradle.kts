import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material comes from android/key.properties locally, or from environment
// variables in CI, so the keystore itself never enters the repository. When neither is
// present the release build falls back to the debug key: `flutter run --release` and
// unsigned artifact builds keep working for anyone who just cloned the project.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingValue(key: String, env: String): String? =
    keystoreProperties.getProperty(key) ?: System.getenv(env)

val storeFilePath = signingValue("storeFile", "TESSERA_KEYSTORE_PATH")
val hasReleaseSigning = storeFilePath != null && file(storeFilePath).exists()

android {
    namespace = "com.vibebyteforge.tessera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vibebyteforge.tessera"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(storeFilePath!!)
                storePassword = signingValue("storePassword", "TESSERA_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "TESSERA_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "TESSERA_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.lifecycle(
                    "Tessera: no release keystore found, signing with the debug key. " +
                        "See docs/RELEASE.md before uploading to Play."
                )
                signingConfigs.getByName("debug")
            }
        }
    }

    // `flutter build apk --split-per-abi` drives the split itself; declaring the ABIs here
    // keeps the universal APK and the bundle building the same three, and nothing else.
    splits {
        abi {
            isUniversalApk = false
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    bundle {
        // One AAB carrying every ABI, language and density; Play does the splitting.
        abi { enableSplit = true }
        language { enableSplit = true }
        density { enableSplit = true }
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
