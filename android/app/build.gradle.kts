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

    // Declared before `buildTypes` because that block reads it: a
    // `signingConfigs` block placed afterwards is not configured yet, and
    // `getByName("release")` then throws "SigningConfig with name 'release'
    // not found" on any build that has a keystore — which is to say, on
    // every real release build. Credentials come from environment variables,
    // never from a file in the repository — see
    // .github/workflows/release.yml.
    signingConfigs {
        create("release") {
            // `file()` resolves against this project's directory
            // (`android/app/`), not the module root, so the path the release
            // workflow writes to has to be spelled relative to here. Writing
            // the keystore to `android/keystore.jks` and expecting this to
            // find it silently fell through to the debug key instead, and
            // every release went out signed by a per-runner debug keystore —
            // a different one each time, which is why upgrades reported a
            // signature mismatch.
            storeFile = file("keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Real signing when a keystore is present, debug signing
            // otherwise. The fallback is what makes `flutter run --release`
            // work on a fresh clone with no keystore; a release that reaches
            // users must be built with the keystore configured.
            //
            // The check is `exists()`, not "can it be read": a keystore
            // with a wrong password or alias fails later, at signing time.
            // That is still the right trade — a hard failure beats falling
            // through to the debug key, which is what let three releases
            // install fine and then refuse to upgrade.
            signingConfig = if (file("keystore.jks").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
