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

// Blank counts as absent: CI passes TESSERA_KEYSTORE_PATH="" on unsigned runs, and
// file("") resolves to the project directory, which exists — so a naive null check
// would enable release signing with a directory as the keystore.
fun signingValue(key: String, env: String): String? =
    (keystoreProperties.getProperty(key) ?: System.getenv(env))?.takeIf { it.isNotBlank() }

val storeFilePath = signingValue("storeFile", "TESSERA_KEYSTORE_PATH")
val hasReleaseSigning = storeFilePath != null && file(storeFilePath).exists()

android {
    namespace = "com.maxcavrilon.tessera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.maxcavrilon.tessera"
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
