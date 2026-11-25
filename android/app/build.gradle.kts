import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// toadLAUNCHER signing (SEC-01) — NO keystore lives in this repo.
// Release APKs are signed in CI from GitHub Actions secrets with an
// APK Signature Scheme v3 rotation lineage (android/toad-lineage.bin):
// the retired key still covers v2 (Android 8 keeps updating), the new
// 4096-bit key covers v3 for Android 9+ with rollback revoked for the
// old key. key.properties + a keystore next to it are honored for LOCAL
// convenience builds only (git-ignored); without them gradle falls back
// to the debug key and CI re-signs the artifact with apksigner anyway.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "family.toad.launcher"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "family.toad.launcher"
        // toadLAUNCHER design contract: minSdk 26, target API 37.
        minSdk = 26
        targetSdk = 37
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { fName ->
                // Accept paths relative to android/app/ OR android/ — first one
                // that exists wins (guards against the doubled app/app/ trap).
                val fromAppDir = file(fName)
                if (fromAppDir.exists()) fromAppDir else rootProject.file(fName)
            }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Local convenience signing only when key.properties exists;
            // CI signs the built artifact itself (rotation lineage), so
            // the debug fallback here never ships.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
