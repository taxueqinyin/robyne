plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.robyne.robyne"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.robyne.robyne"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Real signing when a keystore is present, debug signing
            // otherwise. The fallback is what makes `flutter run --release`
            // work on a fresh clone with no keystore; a release that reaches
            // users must be built with the keystore configured.
            signingConfig =
                if (file("keystore.jks").exists()) {
                    signingConfigs.getByName("upload")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    // Declared here rather than inside `buildTypes` so it exists regardless of
    // which build type is being configured. Credentials come from environment
    // variables, never from a file in the repository — see
    // .github/workflows/release.yml.
    signingConfigs {
        create("upload") {
            storeFile = file("keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    packaging {
        // `package:sqlite3` resolves the database library with
        // dlopen("libsqlite3.so") at runtime. With the default
        // useLegacyPackaging = false the .so files stay compressed inside the
        // APK and are invisible to dlopen, so extract them like legacy apps.
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}
