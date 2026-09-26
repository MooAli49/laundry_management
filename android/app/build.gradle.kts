import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mooali.laundry_management"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            val keyStorePath = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("ANDROID_KEYSTORE_PATH")
            if (!keyStorePath.isNullOrBlank()) {
                val candidateInRoot = rootProject.file(keyStorePath)
                val candidateInApp = file(keyStorePath)
                val candidateInWorkspace = file("../../$keyStorePath")
                storeFile = when {
                    candidateInRoot.exists() -> candidateInRoot.absoluteFile
                    candidateInApp.exists() -> candidateInApp.absoluteFile
                    candidateInWorkspace.exists() -> candidateInWorkspace.absoluteFile
                    file(keyStorePath).isAbsolute -> file(keyStorePath).absoluteFile
                    else -> candidateInRoot.absoluteFile
                }
            }
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mooali.laundry_management"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
