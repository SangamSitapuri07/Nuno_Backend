plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nuno.nuno_app"
    // Pinned rather than taking flutter.compileSdkVersion. Modern androidx
    // artifacts pulled in by the plugins declare they must be compiled
    // against API 34+, and when the toolchain default is lower the build
    // fails in checkDebugAarMetadata with a list of dependency complaints
    // that never names the real cause.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nuno.nuno_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.

        // Pinned rather than taking flutter.minSdkVersion: flutter_webrtc
        // requires API 23, and the Flutter default has historically been
        // lower, which fails the manifest merge with a minSdkVersion error
        // instead of anything that points at voice chat.
        minSdk = 23

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
